import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

/// Immersive presentation for the display side of a session: screen kept
/// awake, system UI hidden on mobile, window fullscreen on desktop.
abstract final class Immersive {
  static bool get _desktop =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
  static bool get _mobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Enters immersive mode. Each step fails soft.
  static Future<void> enter() async {
    await _try('wakelock', WakelockPlus.enable);
    if (_mobile) {
      await _try(
        'system ui',
        () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    }
    if (_desktop) await _try('fullscreen', () => windowManager.setFullScreen(true));
  }

  /// Restores everything [enter] changed.
  static Future<void> exit() async {
    await _try('wakelock', WakelockPlus.disable);
    if (_mobile) {
      await _try('system ui', () => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    if (_desktop) await _try('fullscreen', () => windowManager.setFullScreen(false));
  }

  static Future<void> _try(String what, Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('immersive $what unavailable: $e');
    }
  }
}

/// Who draws the strip at the top of the window.
enum TitleBarKind {
  /// The system does (mobile, other Linux desktops, or setup failed).
  native,

  /// The app does, with Windows-style buttons on the right.
  windows,

  /// The app does, with GNOME-style round buttons on the right.
  gnome,

  /// The app does, leaving room for the system's traffic lights on the left.
  macos,
}

/// Desktop window setup: title, minimum size and the app-drawn title bar.
abstract final class DesktopWindow {
  /// Command-line flag the Linux runner adds when it hid its header bar.
  static const customTitleBarFlag = '--custom-title-bar';

  /// Initialises window_manager; no-op elsewhere. [minimized] is used when
  /// launched at login, so the app waits quietly in the background.
  ///
  /// Returns who draws the title bar. The system one is hidden where the
  /// app can draw its own in its own colours: on Windows and macOS through
  /// window_manager, on GNOME by the runner itself (see `my_application.cc`),
  /// which reports it through [args].
  static Future<TitleBarKind> init({
    required String title,
    required List<String> args,
    bool minimized = false,
  }) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return TitleBarKind.native;
    }
    var kind = TitleBarKind.native;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitle(title);
      await windowManager.setMinimumSize(const Size(380, 560));
      if (Platform.isWindows) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        kind = TitleBarKind.windows;
      } else if (Platform.isMacOS) {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
        kind = TitleBarKind.macos;
      } else if (args.contains(customTitleBarFlag)) {
        kind = TitleBarKind.gnome;
      }
      if (minimized) await windowManager.minimize();
    } catch (e) {
      debugPrint('window_manager unavailable: $e');
    }
    return kind;
  }
}
