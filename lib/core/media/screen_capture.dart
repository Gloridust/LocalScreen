import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'captured_screen.dart';

/// Captures the local screen, per platform:
///
/// * **Linux** — [direct] first (GNOME: the monitor is recorded through
///   Mutter and picked in the app). Elsewhere flutter_webrtc's PipeWire
///   capturer, for which the xdg-desktop-portal shows its own picker;
///   passing no `deviceId` makes the plugin use the portal-selected source.
/// * **Windows / macOS** — enumerate screens with `desktopCapturer` and pass
///   the chosen id; [chooser] is asked only when there is more than one.
/// * **Android** — MediaProjection needs a running foreground service of type
///   `mediaProjection` (declared in AndroidManifest.xml), started through
///   `flutter_background` before `getDisplayMedia`.
/// * **iOS** — needs a Broadcast Upload Extension (M3); not supported.
class ScreenCapture {
  /// Creates a capturer.
  const ScreenCapture({required this.chooser, required this.notificationText, this.direct});

  /// Asks which screen to share where the app has to offer the choice.
  final ScreenChooser chooser;

  /// A desktop-specific capture that is tried before the generic one.
  final DirectScreenCapture? direct;

  /// Localized text of the Android "sharing your screen" notification.
  final String Function() notificationText;

  /// Returns the capture, or null if the user cancelled.
  Future<CapturedScreen?> open({required int frameRate}) async {
    final direct = this.direct;
    if (direct != null) {
      try {
        return await direct.open(frameRate: frameRate, chooser: chooser);
      } catch (e) {
        debugPrint('direct screen capture unavailable, using the system picker: $e');
      }
    }
    final stream = await _openStream(frameRate: frameRate);
    return stream == null ? null : CapturedScreen(stream, onClose: release);
  }

  Future<MediaStream?> _openStream({required int frameRate}) async {
    if (kIsWeb) {
      return navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
    }
    if (Platform.isIOS) {
      throw UnsupportedError('Screen capture on iOS needs a broadcast extension');
    }
    final mandatory = {'frameRate': frameRate.toDouble()};
    if (Platform.isAndroid) {
      await _startAndroidForegroundService();
      return navigator.mediaDevices.getDisplayMedia({
        'video': {'mandatory': mandatory},
        'audio': false,
      });
    }
    if (Platform.isLinux) {
      return navigator.mediaDevices.getDisplayMedia({
        'video': {'mandatory': mandatory, 'cursor': 'always'},
        'audio': false,
      });
    }
    // Windows / macOS.
    final screens = await desktopCapturer.getSources(
      types: [SourceType.Screen],
      thumbnailSize: ThumbnailSize(320, 180),
    );
    if (screens.isEmpty) throw StateError('no screen to capture');
    final choice = screens.length == 1
        ? null
        : await chooser([for (final s in screens) ScreenOption(id: s.id, thumbnail: s.thumbnail)]);
    if (screens.length > 1 && choice == null) return null;
    final source = choice == null ? screens.first : screens.firstWhere((s) => s.id == choice.id);
    return navigator.mediaDevices.getDisplayMedia({
      'video': {
        'deviceId': {'exact': source.id},
        'mandatory': mandatory,
        'cursor': 'always',
      },
      'audio': false,
    });
  }

  /// Stops the Android foreground service again.
  Future<void> release() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      debugPrint('flutter_background release failed: $e');
    }
  }

  Future<void> _startAndroidForegroundService() async {
    final config = FlutterBackgroundAndroidConfig(
      notificationTitle: 'LocalScreen',
      notificationText: notificationText(),
      notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
    );
    final ok = await FlutterBackground.initialize(androidConfig: config);
    if (ok && !FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.enableBackgroundExecution();
    }
  }
}
