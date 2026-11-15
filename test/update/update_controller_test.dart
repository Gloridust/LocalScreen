import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/core/node/local_node.dart';
import 'package:localscreen/core/prefs/preferences.dart';
import 'package:localscreen/core/update/release.dart';
import 'package:localscreen/core/update/update_controller.dart';
import 'package:localscreen/core/update/update_installer.dart';
import 'package:localscreen/core/update/update_source.dart';
import 'package:localscreen/core/update/version.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppRelease _release(String version, {bool withPackage = true}) => AppRelease(
  version: AppVersion.tryParse(version)!,
  page: Uri.parse('https://example.invalid/$version'),
  assets: [
    if (withPackage)
      ReleaseAsset(
        name: 'localscreen_${version}_amd64.deb',
        url: Uri.parse('https://example.invalid/pkg.deb'),
        size: 1000,
      ),
  ],
);

void main() {
  const first = Duration(seconds: 8);
  const hour = Duration(hours: 1);

  /// Runs [body] with a container whose update source serves [source].
  void run(
    FakeUpdateSource source,
    void Function(FakeAsync async, ProviderContainer container, FakeUpdateInstaller installer)
    body, {
    Map<String, Object> prefs = const {},
    FakeUpdateInstaller? installer,
  }) {
    fakeAsync((async) {
      SharedPreferences.setMockInitialValues(prefs);
      late SharedPreferences sp;
      SharedPreferences.getInstance().then((v) => sp = v);
      async.flushMicrotasks();
      final fakeInstaller = installer ?? FakeUpdateInstaller();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          nodeServiceProvider.overrideWithValue(FakeNodeService()),
          appVersionProvider.overrideWithValue(const AppVersion(0, 1, 3)),
          updateSourceProvider.overrideWithValue(source),
          updateInstallerProvider.overrideWithValue(fakeInstaller),
        ],
      );
      container.listen(updateControllerProvider, (_, _) {});
      body(async, container, fakeInstaller);
      container.dispose();
      async.flushTimers();
    });
  }

  test('checks shortly after launch and then every hour', () {
    final source = FakeUpdateSource(_release('0.1.3'));
    run(source, (async, c, _) {
      async.elapse(first - const Duration(seconds: 1));
      expect(source.checks, 0, reason: 'start-up is left alone');
      async.elapse(const Duration(seconds: 2));
      expect(source.checks, 1);
      expect(c.read(updateControllerProvider), isA<UpdateUpToDate>());

      async.elapse(hour);
      expect(source.checks, 2);
      async.elapse(hour * 5);
      expect(source.checks, 7);
    });
  });

  test('switched off, nothing is asked; switching on starts the schedule', () {
    final source = FakeUpdateSource(_release('0.2.0'));
    run(source, prefs: {'ls.autoCheckUpdates': false}, (async, c, _) {
      async.elapse(hour * 3);
      expect(source.checks, 0);
      expect(c.read(updateControllerProvider), isA<UpdateIdle>());

      c.read(preferencesProvider.notifier).update((p) => p.copyWith(autoCheckUpdates: true));
      async.elapse(first + const Duration(seconds: 1));
      expect(source.checks, 1);
      expect(c.read(updateControllerProvider), isA<UpdateAvailable>());

      c.read(preferencesProvider.notifier).update((p) => p.copyWith(autoCheckUpdates: false));
      async.elapse(hour * 3);
      expect(source.checks, 1, reason: 'switching off stops the timers');
    });
  });

  test('a manual check works with automatic checks off', () {
    final source = FakeUpdateSource(_release('0.2.0'));
    run(source, prefs: {'ls.autoCheckUpdates': false}, (async, c, _) {
      c.read(updateControllerProvider.notifier).check(manual: true);
      expect(c.read(updateControllerProvider), isA<UpdateChecking>());
      async.elapse(const Duration(seconds: 1));
      expect(c.read(updateControllerProvider).release!.version, const AppVersion(0, 2, 0));
    });
  });

  test('only a newer, final release counts as an update', () {
    for (final (version, isUpdate) in [
      ('0.1.2', false),
      ('0.1.3', false),
      ('0.1.4', true),
      ('1.0.0', true),
      ('0.2.0-beta.1', false),
    ]) {
      run(FakeUpdateSource(_release(version)), (async, c, _) {
        async.elapse(first + const Duration(seconds: 1));
        expect(c.read(updateControllerProvider) is UpdateAvailable, isUpdate, reason: version);
      });
    }
  });

  test('a failed automatic check stays quiet; a manual one says so', () {
    final source = FakeUpdateSource(_release('0.2.0'), failCheck: true);
    run(source, (async, c, _) {
      async.elapse(first + const Duration(seconds: 1));
      expect(c.read(updateControllerProvider), isA<UpdateIdle>());

      c.read(updateControllerProvider.notifier).check(manual: true);
      async.elapse(const Duration(seconds: 1));
      final state = c.read(updateControllerProvider);
      expect(state, isA<UpdateFailed>());
      expect((state as UpdateFailed).failure, UpdateFailure.network);

      // Back online: the next check finds the release, and a later failure
      // does not forget it.
      source.failCheck = false;
      async.elapse(hour);
      expect(c.read(updateControllerProvider), isA<UpdateAvailable>());
      source.failCheck = true;
      c.read(updateControllerProvider.notifier).check(manual: true);
      async.elapse(const Duration(seconds: 1));
      expect(c.read(updateControllerProvider), isA<UpdateAvailable>());
    });
  });

  test('the banner follows the release until it is skipped', () {
    final source = FakeUpdateSource(_release('0.2.0'));
    run(source, (async, c, _) {
      c.listen(updateBannerProvider, (_, _) {});
      expect(c.read(updateBannerProvider), isNull);
      async.elapse(first + const Duration(seconds: 1));
      expect(c.read(updateBannerProvider), isA<UpdateAvailable>());

      c.read(updateControllerProvider.notifier).skip();
      async.flushMicrotasks();
      expect(c.read(updateBannerProvider), isNull);
      expect(c.read(preferencesProvider).skippedUpdate, '0.2.0');

      // A newer release is announced again.
      source.release = _release('0.3.0');
      async.elapse(hour);
      expect(c.read(updateBannerProvider)!.release!.version, const AppVersion(0, 3, 0));
    });
  });

  test('installing downloads, installs and restarts into the new version', () {
    final source = FakeUpdateSource(_release('0.2.0'));
    run(source, (async, c, installer) {
      final seen = <Type>[];
      c.listen(updateControllerProvider, (_, s) => seen.add(s.runtimeType));
      async.elapse(first + const Duration(seconds: 1));
      c.read(updateControllerProvider.notifier).install();
      async.elapse(const Duration(seconds: 2));

      expect(seen, containsAllInOrder([UpdateAvailable, UpdateDownloading, UpdateInstalled]));
      expect(installer.installed.single.path, endsWith('localscreen_0.2.0_amd64.deb'));
      expect(c.read(updateControllerProvider), isA<UpdateInstalled>());

      // The hourly check must not disturb an update waiting for a restart.
      async.elapse(hour);
      expect(c.read(updateControllerProvider), isA<UpdateInstalled>());

      c.read(updateControllerProvider.notifier).restart();
      async.elapse(const Duration(seconds: 1));
      expect(installer.relaunches, 1);
    });
  });

  test('each installer outcome leads to the matching state', () {
    for (final (outcome, expected) in [
      (InstallOutcome.opened, UpdateOpened),
      (InstallOutcome.cancelled, UpdateAvailable),
    ]) {
      run(FakeUpdateSource(_release('0.2.0')), installer: FakeUpdateInstaller(outcome: outcome), (
        async,
        c,
        installer,
      ) {
        async.elapse(first + const Duration(seconds: 1));
        c.read(updateControllerProvider.notifier).install();
        async.elapse(const Duration(seconds: 2));
        expect(c.read(updateControllerProvider).runtimeType, expected, reason: '$outcome');
      });
    }
    // A separate installer takes over: this instance quits.
    run(
      FakeUpdateSource(_release('0.2.0')),
      installer: FakeUpdateInstaller(outcome: InstallOutcome.handedOff),
      (async, c, installer) {
        async.elapse(first + const Duration(seconds: 1));
        c.read(updateControllerProvider.notifier).install();
        async.elapse(const Duration(seconds: 2));
        expect(installer.quits, 1);
      },
    );
  });

  test('failures keep the release so the user can retry or open the page', () {
    final cases = <(FakeUpdateSource, FakeUpdateInstaller, UpdateFailure)>[
      (
        FakeUpdateSource(_release('0.2.0'), failDownload: UpdateFailure.checksum),
        FakeUpdateInstaller(),
        UpdateFailure.checksum,
      ),
      (
        FakeUpdateSource(_release('0.2.0', withPackage: false)),
        FakeUpdateInstaller(),
        UpdateFailure.noPackage,
      ),
      (
        FakeUpdateSource(_release('0.2.0')),
        FakeUpdateInstaller(canInstallHere: false),
        UpdateFailure.noPackage,
      ),
    ];
    for (final (source, installer, failure) in cases) {
      run(source, installer: installer, (async, c, _) {
        async.elapse(first + const Duration(seconds: 1));
        c.read(updateControllerProvider.notifier).install();
        async.elapse(const Duration(seconds: 2));
        final state = c.read(updateControllerProvider);
        expect(state, isA<UpdateFailed>(), reason: '$failure');
        expect((state as UpdateFailed).failure, failure);
        expect(state.release, isNotNull);
        expect(installer.installed, isEmpty);
      });
    }
  });
}
