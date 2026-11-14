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

/// Desktop window setup: title and a sensible minimum size.
abstract final class DesktopWindow {
  /// Initialises window_manager; no-op elsewhere. [minimized] is used when
  /// launched at login, so the app waits quietly in the background.
  static Future<void> init({required String title, bool minimized = false}) async {
    if (kIsWeb || !(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitle(title);
      await windowManager.setMinimumSize(const Size(380, 560));
      if (minimized) await windowManager.minimize();
    } catch (e) {
      debugPrint('window_manager unavailable: $e');
    }
  }
}
