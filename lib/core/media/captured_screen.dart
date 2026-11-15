import 'package:flutter_webrtc/flutter_webrtc.dart';

/// A running capture of one screen.
class CapturedScreen {
  /// Wraps [stream]. [onClose] releases whatever feeds it; [ended] completes
  /// if the capture stops on its own (the source went away).
  CapturedScreen(this.stream, {this._onClose, this.ended, this.size});

  /// The stream whose single video track carries the screen.
  final MediaStream stream;

  /// Completes if the capture stops by itself; null when that is reported
  /// through the track's `onEnded` instead.
  final Future<void>? ended;

  /// Width and height of the frames, when the capture knows them up front.
  final (int, int)? size;

  final Future<void> Function()? _onClose;
  bool _closed = false;

  /// Stops the capture and releases its source. Safe to call twice.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _onClose?.call();
  }
}

/// A screen the user can pick to share.
class ScreenOption {
  /// Creates an option.
  const ScreenOption({required this.id, this.title, this.detail, this.thumbnail});

  /// Identifier meaningful to whoever listed the option.
  final String id;

  /// Name of the screen; null when the platform has none.
  final String? title;

  /// Secondary line, e.g. the resolution.
  final String? detail;

  /// Encoded preview image, if the platform provides one.
  final List<int>? thumbnail;
}

/// Asks the user which of [screens] to share; returns null to cancel.
typedef ScreenChooser = Future<ScreenOption?> Function(List<ScreenOption> screens);

/// Captures a screen without the platform's generic capture path, where a
/// desktop offers something better. Returns null if the user cancelled and
/// throws [UnsupportedError] when it does not apply to this desktop.
abstract interface class DirectScreenCapture {
  /// Opens a capture at [frameRate].
  Future<CapturedScreen?> open({required int frameRate, required ScreenChooser chooser});
}
