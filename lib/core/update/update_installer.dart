import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'release.dart';
import 'update_source.dart';

/// What happened after a package was handed to the platform.
enum InstallOutcome {
  /// Installed in place; restart LocalScreen to run it (Linux).
  installed,

  /// A separate installer is replacing LocalScreen and reopens it when
  /// done; this instance must quit now (Windows).
  handedOff,

  /// The system installer is open and the user finishes there (macOS).
  opened,

  /// The user dismissed the system prompt.
  cancelled,
}

/// Installs a downloaded package on this platform.
abstract class UpdateInstaller {
  const UpdateInstaller();

  /// Picks the installer for [platform] (`DeviceProfile.platform`).
  factory UpdateInstaller.forPlatform(String platform) {
    final x64 = const {Abi.linuxX64, Abi.windowsX64}.contains(Abi.current());
    return switch (UpdatePackage.forPlatform(platform, x64: x64)) {
      UpdatePackage.deb => LinuxDebInstaller(),
      UpdatePackage.windowsSetup => const WindowsSetupInstaller(),
      UpdatePackage.dmg => const MacDmgInstaller(),
      // Each Android build is signed with a throwaway key so far, and the
      // system refuses to install one build over another; until releases
      // share a key, updates there are announced and fetched by hand.
      UpdatePackage.apk || null => const ManualInstaller(),
    };
  }

  /// The package format this platform installs; null when there is none.
  UpdatePackage? get package;

  /// Whether a package can be installed from inside the app. When false,
  /// the update sheet sends the user to the release page instead.
  bool get canInstall => package != null;

  /// Hands [file] to the platform installer. Throws [UpdateException].
  Future<InstallOutcome> install(File file);

  /// Starts the newly installed app and ends this process.
  Future<void> relaunch() async => exit(0);

  /// Ends this process so an installer can replace it.
  Future<void> quit() async => exit(0);

  /// Opens [url] in the default browser.
  Future<void> openPage(Uri url) async {
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object catch (e) {
      debugPrint('update: could not open $url: $e');
    }
  }
}

/// Debian package, installed through `pkexec apt-get` so its dependencies
/// resolve. Only for copies that were themselves installed from the
/// package; a build run from elsewhere would not be replaced.
class LinuxDebInstaller extends UpdateInstaller {
  /// Creates the installer for the running [executable].
  LinuxDebInstaller({String? executable}) : executable = executable ?? Platform.resolvedExecutable;

  final String executable;

  static const installDir = '/opt/localscreen';
  static const _pkexec = '/usr/bin/pkexec';
  static const _apt = '/usr/bin/apt-get';

  @override
  UpdatePackage get package => UpdatePackage.deb;

  @override
  bool get canInstall =>
      executable.startsWith('$installDir/') &&
      File(_pkexec).existsSync() &&
      File(_apt).existsSync();

  @override
  Future<InstallOutcome> install(File file) async {
    final result = await Process.run(_pkexec, [_apt, 'install', '-y', file.absolute.path]);
    return switch (result.exitCode) {
      0 => InstallOutcome.installed,
      // pkexec: the password dialog was dismissed or authentication failed.
      126 || 127 => InstallOutcome.cancelled,
      _ => throw UpdateException(UpdateFailure.install, result.stderr),
    };
  }

  @override
  Future<void> relaunch() async {
    await Process.start('$installDir/localscreen', const [], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// Inno Setup installer, run silently. It closes LocalScreen if needed and
/// starts it again when done (see `packaging/windows/installer.iss`).
class WindowsSetupInstaller extends UpdateInstaller {
  /// Creates the installer.
  const WindowsSetupInstaller();

  @override
  UpdatePackage get package => UpdatePackage.windowsSetup;

  @override
  Future<InstallOutcome> install(File file) async {
    try {
      await Process.start(file.path, const [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
    } on ProcessException catch (e) {
      throw UpdateException(UpdateFailure.install, e);
    }
    return InstallOutcome.handedOff;
  }
}

/// Disk image, opened in Finder; the user drags the app over the old one.
class MacDmgInstaller extends UpdateInstaller {
  /// Creates the installer.
  const MacDmgInstaller();

  @override
  UpdatePackage get package => UpdatePackage.dmg;

  @override
  Future<InstallOutcome> install(File file) async {
    final result = await Process.run('open', [file.path]);
    if (result.exitCode != 0) throw UpdateException(UpdateFailure.install, result.stderr);
    return InstallOutcome.opened;
  }
}

/// Where a package cannot be installed from inside the app (Android for
/// now, Linux on ARM): updates are announced and the user downloads them
/// from the release page.
class ManualInstaller extends UpdateInstaller {
  /// Creates the installer.
  const ManualInstaller();

  @override
  UpdatePackage? get package => null;

  @override
  Future<InstallOutcome> install(File file) => throw const UpdateException(UpdateFailure.noPackage);
}

/// Records calls instead of touching the system; for tests and the demo.
class FakeUpdateInstaller extends UpdateInstaller {
  /// Answers every install with [outcome].
  FakeUpdateInstaller({
    this.package = UpdatePackage.deb,
    this.canInstallHere = true,
    this.outcome = InstallOutcome.installed,
  });

  @override
  final UpdatePackage? package;
  final bool canInstallHere;
  InstallOutcome outcome;

  final installed = <File>[];
  final opened = <Uri>[];
  int relaunches = 0;
  int quits = 0;

  @override
  bool get canInstall => canInstallHere && package != null;

  @override
  Future<InstallOutcome> install(File file) async {
    installed.add(file);
    return outcome;
  }

  @override
  Future<void> relaunch() async => relaunches++;

  @override
  Future<void> quit() async => quits++;

  @override
  Future<void> openPage(Uri url) async => opened.add(url);
}
