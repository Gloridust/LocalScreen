import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:win32_registry/win32_registry.dart';

import '../prefs/preferences.dart';

/// Command-line flag passed by the autostart entry, so the app can start
/// quietly (minimized) and wait for connections.
const autostartFlag = '--autostart';

/// Registers / unregisters the app to launch at login.
abstract class AutostartService {
  /// Whether this platform supports launching at login.
  bool get supported;

  /// Whether an autostart entry for this app exists.
  Future<bool> isEnabled();

  /// Creates (or refreshes) or removes the autostart entry.
  Future<void> setEnabled(bool enabled);
}

/// Mobile platforms: not applicable.
class UnsupportedAutostartService implements AutostartService {
  /// Creates the no-op service.
  const UnsupportedAutostartService();

  @override
  bool get supported => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {}
}

/// Keeps the state in memory; used by tests and the `LS_FAKE` demo mode so
/// nothing touches the real OS.
class InMemoryAutostartService implements AutostartService {
  /// Creates the service, optionally already [enabled].
  InMemoryAutostartService({this.enabled = false, this.supported = true});

  /// Current state.
  bool enabled;

  @override
  final bool supported;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

/// Desktop implementation without plugins:
///
/// * **Linux** — XDG autostart: `$XDG_CONFIG_HOME/autostart/localscreen.desktop`.
/// * **Windows** — `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
/// * **macOS** — a LaunchAgent plist in `~/Library/LaunchAgents` (only
///   effective for non-sandboxed builds).
class DesktopAutostartService implements AutostartService {
  /// Creates the service for the executable at [executable].
  DesktopAutostartService({
    this.appName = 'LocalScreen',
    this.bundleId = 'dev.localscreen.localscreen',
    String? executable,
    Map<String, String>? environment,
  }) : executable = executable ?? _launcherPath(environment ?? Platform.environment),
       _env = environment ?? Platform.environment;

  final String appName;
  final String bundleId;

  /// What the entry launches.
  final String executable;
  final Map<String, String> _env;

  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';

  /// AppImages run from a temporary mount; launch the image itself.
  static String _launcherPath(Map<String, String> env) =>
      env['APPIMAGE'] ?? Platform.resolvedExecutable;

  @override
  bool get supported => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// The XDG autostart file (Linux).
  File get linuxEntry {
    final configured = _env['XDG_CONFIG_HOME'];
    final base = configured != null && configured.isNotEmpty
        ? configured
        : '${_env['HOME']}/.config';
    return File('$base/autostart/localscreen.desktop');
  }

  File get _macAgent => File('${_env['HOME']}/Library/LaunchAgents/$bundleId.plist');

  @override
  Future<bool> isEnabled() async {
    if (Platform.isLinux) return linuxEntry.existsSync();
    if (Platform.isMacOS) return _macAgent.existsSync();
    if (Platform.isWindows) {
      final key = CURRENT_USER.create(_runKey);
      try {
        return key.getString(appName) != null;
      } finally {
        key.close();
      }
    }
    return false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (Platform.isLinux) {
      final file = linuxEntry;
      if (enabled) {
        await file.parent.create(recursive: true);
        await file.writeAsString(linuxDesktopEntry());
      } else if (file.existsSync()) {
        await file.delete();
      }
    } else if (Platform.isMacOS) {
      final file = _macAgent;
      if (enabled) {
        await file.parent.create(recursive: true);
        await file.writeAsString(_macPlist());
      } else if (file.existsSync()) {
        await file.delete();
      }
    } else if (Platform.isWindows) {
      final key = CURRENT_USER.create(_runKey);
      try {
        if (enabled) {
          key.setValue(appName, RegistryValue.string('"$executable" $autostartFlag'));
        } else if (key.getString(appName) != null) {
          key.removeValue(appName);
        }
      } finally {
        key.close();
      }
    }
  }

  /// Contents of the XDG autostart entry.
  @visibleForTesting
  String linuxDesktopEntry() {
    final exec = executable.contains(' ') ? '"$executable"' : executable;
    return [
      '[Desktop Entry]',
      'Type=Application',
      'Name=$appName',
      'Comment=Wait for screen-sharing requests on the local network',
      'Exec=$exec $autostartFlag',
      'Terminal=false',
      'X-GNOME-Autostart-enabled=true',
      '',
    ].join('\n');
  }

  String _macPlist() =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$bundleId</string>
  <key>ProgramArguments</key>
  <array><string>$executable</string><string>$autostartFlag</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
''';
}

/// The autostart backend; overridden at startup and in tests.
final autostartServiceProvider = Provider<AutostartService>(
  (ref) => const UnsupportedAutostartService(),
);

/// Makes the stored preference match the OS at launch.
///
/// The OS entry is the source of truth (the user may have removed it with
/// system tools). An existing entry is rewritten so it points at the current
/// executable after an update or move.
Future<void> reconcileAutostart(AutostartService service, PreferencesStore store) async {
  if (!service.supported) return;
  try {
    final actual = await service.isEnabled();
    if (actual) await service.setEnabled(true);
    final prefs = store.load();
    if (prefs.launchAtStartup != actual) {
      await store.save(prefs.copyWith(launchAtStartup: actual));
    }
  } catch (e) {
    debugPrint('autostart reconcile failed: $e');
  }
}

/// Settings action: toggles autostart and persists the result.
final autostartControllerProvider = Provider<AutostartController>(AutostartController.new);

/// Applies the "launch at startup" switch to the OS and preferences.
class AutostartController {
  /// Creates the controller.
  AutostartController(this._ref);

  final Ref _ref;

  /// Whether the switch should be shown at all.
  bool get supported => _ref.read(autostartServiceProvider).supported;

  /// Turns autostart on or off; reverts the preference if the OS refuses.
  Future<bool> setEnabled(bool enabled) async {
    final prefs = _ref.read(preferencesProvider.notifier);
    await prefs.update((p) => p.copyWith(launchAtStartup: enabled));
    try {
      await _ref.read(autostartServiceProvider).setEnabled(enabled);
      return true;
    } catch (e) {
      debugPrint('autostart toggle failed: $e');
      await prefs.update((p) => p.copyWith(launchAtStartup: !enabled));
      return false;
    }
  }
}
