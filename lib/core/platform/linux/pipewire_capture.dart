import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
// The native side creates the stream; this is the class flutter_webrtc itself
// wraps such a stream in, and it is not part of the package's public exports.
// ignore: implementation_imports
import 'package:flutter_webrtc/src/native/media_stream_impl.dart';

import '../../media/captured_screen.dart';
import '../virtual_display.dart';

/// Turns a PipeWire video node into a WebRTC video track, through the
/// app's own `localscreen/pipewire_capture` channel (see
/// `linux/runner/pipewire_capture.cc`).
abstract final class PipeWireCapture {
  static const _channel = MethodChannel('localscreen/pipewire_capture');
  static final _running = <String, Completer<void>>{};
  static bool _listening = false;

  /// Whether this build can capture PipeWire nodes: the native channel
  /// exists and the GStreamer elements it uses are installed.
  static Future<bool> supported() async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('pipewire capture: probing failed: $e');
      return false;
    }
  }

  /// Starts reading [node] at up to [frameRate] frames per second and
  /// returns once the first frame has arrived.
  ///
  /// [size] asks the node for that exact size, which is what gives a new
  /// virtual monitor its resolution. [onClose] runs when the capture is
  /// closed, after the pipeline stopped.
  ///
  /// Throws a [PlatformException] if no frame arrives.
  static Future<CapturedScreen> start({
    required int node,
    required int frameRate,
    ScreenSize? size,
    Future<void> Function()? onClose,
  }) async {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler(_onCall);
    }
    // The native side borrows flutter_webrtc's peer connection factory.
    await WebRTC.initialize();
    final reply = await _channel.invokeMapMethod<String, Object?>('start', {
      'node': node,
      'fps': frameRate,
      if (size != null) ...{'width': size.width, 'height': size.height},
    });
    final streamId = reply!['streamId']! as String;
    final trackId = reply['trackId']! as String;
    final stream = MediaStreamNative(streamId, 'local')
      ..setMediaTracks(const [], [
        {'id': trackId, 'label': trackId, 'kind': 'video', 'enabled': true},
      ]);
    final ended = _running[streamId] = Completer<void>();
    return CapturedScreen(
      stream,
      ended: ended.future,
      size: switch ((reply['width'], reply['height'])) {
        (final int width, final int height) when width > 0 && height > 0 => (width, height),
        _ => null,
      },
      onClose: () async {
        _running.remove(streamId);
        await _channel.invokeMethod<void>('stop', {'streamId': streamId});
        await onClose?.call();
      },
    );
  }

  static Future<void> _onCall(MethodCall call) async {
    if (call.method != 'ended') return;
    final arguments = call.arguments as Map<Object?, Object?>;
    final ended = _running.remove(arguments['streamId']);
    if (ended != null && !ended.isCompleted) ended.complete();
  }
}
