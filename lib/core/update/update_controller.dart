import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../node/local_node.dart';
import '../prefs/preferences.dart';
import 'release.dart';
import 'update_installer.dart';
import 'update_source.dart';
import 'version.dart';

/// The running app's version; overridden at startup.
final appVersionProvider = Provider<AppVersion>((ref) => AppVersion.unknown);

/// Where releases come from; null turns updates off (tests, demo builds).
final updateSourceProvider = Provider<UpdateSource?>((ref) => null);

/// Installs downloaded packages on this platform.
final updateInstallerProvider = Provider<UpdateInstaller>((ref) => const ManualInstaller());

/// Where packages are downloaded to; overridden at startup.
final updateDirectoryProvider = Provider<Directory>(
  (ref) => Directory('${Directory.systemTemp.path}${Platform.pathSeparator}localscreen-updates'),
);

/// When automatic checks run.
final updateScheduleProvider = Provider<UpdateSchedule>((ref) => const UpdateSchedule());

/// Timing of automatic checks.
@immutable
class UpdateSchedule {
  /// Creates a schedule.
  const UpdateSchedule({
    this.firstCheck = const Duration(seconds: 8),
    this.interval = const Duration(hours: 1),
  });

  /// Delay after launch (or after switching checks on), so start-up and
  /// discovery are not slowed down.
  final Duration firstCheck;
  final Duration interval;
}

/// Where the update flow is.
sealed class UpdateState {
  const UpdateState();

  /// The release this state is about, if any.
  AppRelease? get release => null;
}

/// Not checked yet.
final class UpdateIdle extends UpdateState {
  /// Creates the state.
  const UpdateIdle();
}

/// Asking for the latest release.
final class UpdateChecking extends UpdateState {
  /// Creates the state.
  const UpdateChecking();
}

/// The running version is the newest.
final class UpdateUpToDate extends UpdateState {
  /// Creates the state.
  const UpdateUpToDate(this.checkedAt);

  final DateTime checkedAt;
}

/// A newer release exists.
final class UpdateAvailable extends UpdateState {
  /// Creates the state.
  const UpdateAvailable(this.release, this.checkedAt);

  @override
  final AppRelease release;
  final DateTime checkedAt;
}

/// Downloading the package.
final class UpdateDownloading extends UpdateState {
  /// Creates the state.
  const UpdateDownloading(this.release, {this.received = 0, this.total = 0});

  @override
  final AppRelease release;
  final int received;

  /// Bytes expected; 0 when unknown.
  final int total;

  /// Progress from 0 to 1; null while the size is unknown.
  double? get fraction => total > 0 ? (received / total).clamp(0, 1) : null;
}

/// The platform installer is running.
final class UpdateInstalling extends UpdateState {
  /// Creates the state.
  const UpdateInstalling(this.release);

  @override
  final AppRelease release;
}

/// Installed; a restart switches to the new version.
final class UpdateInstalled extends UpdateState {
  /// Creates the state.
  const UpdateInstalled(this.release);

  @override
  final AppRelease release;
}

/// The system installer is open; the user finishes there.
final class UpdateOpened extends UpdateState {
  /// Creates the state.
  const UpdateOpened(this.release);

  @override
  final AppRelease release;
}

/// A step failed.
final class UpdateFailed extends UpdateState {
  /// Creates the state.
  const UpdateFailed(this.failure, {this.release});

  final UpdateFailure failure;

  @override
  final AppRelease? release;
}

/// Checks for, downloads and installs new releases.
final updateControllerProvider = NotifierProvider<UpdateController, UpdateState>(
  UpdateController.new,
);

/// The update the home screen announces, or null for none: a skipped
/// version stays quiet until a newer one appears, except while it is being
/// installed or waits for a restart.
final updateBannerProvider = Provider<UpdateState?>((ref) {
  final state = ref.watch(updateControllerProvider);
  final skipped = ref.watch(preferencesProvider.select((p) => p.skippedUpdate));
  final release = state.release;
  if (release == null) return null;
  final inProgress =
      state is UpdateDownloading || state is UpdateInstalling || state is UpdateInstalled;
  return !inProgress && '${release.version}' == skipped ? null : state;
});

/// See [updateControllerProvider].
class UpdateController extends Notifier<UpdateState> {
  Timer? _first;
  Timer? _periodic;

  UpdateSource? get _source => ref.read(updateSourceProvider);
  UpdateInstaller get _installer => ref.read(updateInstallerProvider);

  /// Whether this build can update itself at all.
  bool get available => _source != null;

  @override
  UpdateState build() {
    ref.onDispose(_cancelTimers);
    if (ref.watch(updateSourceProvider) == null) return const UpdateIdle();
    ref.listen<bool>(
      preferencesProvider.select((p) => p.autoCheckUpdates),
      (_, enabled) => _schedule(enabled),
      fireImmediately: true,
    );
    return const UpdateIdle();
  }

  void _schedule(bool enabled) {
    _cancelTimers();
    if (!enabled) return;
    final schedule = ref.read(updateScheduleProvider);
    _first = Timer(schedule.firstCheck, check);
    _periodic = Timer.periodic(schedule.interval, (_) => check());
  }

  void _cancelTimers() {
    _first?.cancel();
    _periodic?.cancel();
    _first = _periodic = null;
  }

  /// Asks for the latest release. An automatic check that fails keeps the
  /// previous state; a [manual] one reports the failure.
  Future<void> check({bool manual = false}) async {
    final source = _source;
    if (source == null) return;
    final before = state;
    // Never interrupt a download or an install in progress.
    if (before is! UpdateIdle &&
        before is! UpdateUpToDate &&
        before is! UpdateAvailable &&
        before is! UpdateFailed) {
      return;
    }
    if (manual) state = const UpdateChecking();
    final AppRelease? latest;
    try {
      latest = await source.latest();
    } on UpdateException catch (e) {
      if (!ref.mounted) return;
      // A release found earlier is still there; only a first check that
      // was asked for has something to report.
      state = manual && before.release == null ? UpdateFailed(e.failure) : before;
      return;
    }
    if (!ref.mounted) return;
    final now = DateTime.now();
    final current = ref.read(appVersionProvider);
    state = latest != null && latest.version > current && !latest.version.isPreRelease
        ? UpdateAvailable(latest, now)
        : UpdateUpToDate(now);
  }

  /// Downloads the announced release and hands it to the installer.
  Future<void> install() async {
    final source = _source;
    final release = state.release;
    if (source == null || release == null) return;
    if (state is UpdateDownloading || state is UpdateInstalling) return;
    final installer = _installer;
    final package = installer.package;
    final asset = package == null ? null : release.assetFor(package);
    if (asset == null || !installer.canInstall) {
      state = UpdateFailed(UpdateFailure.noPackage, release: release);
      return;
    }

    state = UpdateDownloading(release, total: asset.size);
    var lastPercent = -1;
    final File file;
    try {
      file = await source.download(
        release,
        asset,
        ref.read(updateDirectoryProvider),
        onProgress: (received, total) {
          final percent = total > 0 ? received * 100 ~/ total : 0;
          if (percent == lastPercent || !ref.mounted) return;
          lastPercent = percent;
          state = UpdateDownloading(release, received: received, total: total);
        },
      );
      if (!ref.mounted) return;
      state = UpdateInstalling(release);
      final outcome = await installer.install(file);
      if (!ref.mounted) return;
      switch (outcome) {
        case InstallOutcome.installed:
          state = UpdateInstalled(release);
        case InstallOutcome.handedOff:
          await _stopNode();
          await installer.quit();
        case InstallOutcome.opened:
          state = UpdateOpened(release);
        case InstallOutcome.cancelled:
          state = UpdateAvailable(release, DateTime.now());
      }
    } on UpdateException catch (e) {
      if (ref.mounted) state = UpdateFailed(e.failure, release: release);
    }
  }

  /// Restarts into the installed version.
  Future<void> restart() async {
    if (state is! UpdateInstalled) return;
    await _stopNode();
    await _installer.relaunch();
  }

  /// Stops announcing the current release on the home screen.
  Future<void> skip() async {
    final release = state.release;
    if (release == null) return;
    await ref
        .read(preferencesProvider.notifier)
        .update((p) => p.copyWith(skippedUpdate: release.version.toString()));
  }

  /// Opens the release page (or the list of releases).
  Future<void> openPage() => _installer.openPage(
    state.release?.page ?? Uri.parse('https://github.com/Gloridust/LocalScreen/releases/latest'),
  );

  /// Releases the port before another instance takes over.
  Future<void> _stopNode() async {
    try {
      await ref.read(nodeServiceProvider).stop();
    } on Object catch (e) {
      debugPrint('update: stopping the node failed: $e');
    }
  }
}
