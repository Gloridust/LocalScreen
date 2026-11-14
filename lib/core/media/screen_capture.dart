import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Picks a desktop source when the platform has no system picker.
///
/// Receives the available screens (with thumbnails) and returns the chosen
/// one, or null to cancel.
typedef ScreenSourceChooser = Future<DesktopCapturerSource?> Function(
  List<DesktopCapturerSource> screens,
);

/// Captures the local screen as a [MediaStream], per platform:
///
/// * **Linux** — flutter_webrtc's PipeWire capturer. On Wayland the
///   xdg-desktop-portal shows its own picker; passing no `deviceId` makes the
///   plugin use the first (portal-selected) screen source.
/// * **Windows / macOS** — enumerate screens with `desktopCapturer` and pass
///   the chosen id; [chooser] is asked only when there is more than one.
/// * **Android** — MediaProjection needs a running foreground service of type
///   `mediaProjection` (declared in AndroidManifest.xml), started through
///   `flutter_background` before `getDisplayMedia`.
/// * **iOS** — needs a Broadcast Upload Extension (M3); not supported.
class ScreenCapture {
  /// Creates a capturer.
  const ScreenCapture({required this.chooser, required this.notificationText});

  final ScreenSourceChooser chooser;

  /// Localized text of the Android "sharing your screen" notification.
  final String Function() notificationText;

  /// Returns the capture stream, or null if the user cancelled.
  Future<MediaStream?> open({required int frameRate}) async {
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
    final source = screens.length == 1 ? screens.first : await chooser(screens);
    if (source == null) return null;
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
