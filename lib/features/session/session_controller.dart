import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/media/media_session.dart';
import '../../core/media/media_stats.dart';
import '../../core/media/quality.dart';
import '../../core/media/signalling.dart';
import '../../core/node/node_service.dart';

/// Drives the media plane of one established session.
///
/// Created on `SessionEstablished`, fed every `Signal` for its session and
/// disposed on `SessionClosed` (or any local close path). The host is the
/// WebRTC offerer.
class SessionController extends ChangeNotifier {
  /// Creates a controller; call [start] next.
  SessionController({
    required this.sessionId,
    required this.peer,
    required this.role,
    required this.mode,
    required this._quality,
    required this._media,
    required this._node,
    required this.onMediaFailure,
  });

  final String sessionId;
  final DeviceInfo peer;
  final SessionRole role;
  final ShareMode mode;

  /// Called once if the media plane gives up.
  final void Function(MediaFailure failure) onMediaFailure;

  final MediaSession _media;
  final NodeService _node;
  final DateTime startedAt = DateTime.now();
  StreamSubscription<MediaStats>? _statsSub;
  QualityPreset _quality;
  MediaStats? _stats;
  bool _closed = false;

  /// True on the device that sends its screen.
  bool get isHost => role == SessionRole.host;

  /// The preset in use (on the display: as reported by the host).
  QualityPreset get quality => _quality;

  /// Latest stats sample.
  MediaStats? get stats => _stats;

  /// Media phase.
  MediaPhase get phase => _media.phase.value;

  /// Starts capture (host) or waits for the offer (display).
  Future<void> start() async {
    _media.onSignal = _send;
    _media.phase.addListener(_onPhase);
    _statsSub = _media.stats.listen((s) {
      _stats = s;
      _notify();
    });
    if (isHost) {
      await _media.startHost(_quality);
    } else {
      await _media.startDisplay();
    }
  }

  void _send(SignalMessage message) {
    unawaited(
      _node
          .sendSignal(sessionId, message.encode())
          .catchError((Object e) => debugPrint('sendSignal failed: $e')),
    );
  }

  void _onPhase() {
    if (_media.phase.value == MediaPhase.failed) {
      onMediaFailure(_media.failure ?? MediaFailure.connection);
    }
    _notify();
  }

  /// Handles a signalling payload from the peer.
  Future<void> handleSignal(String payload) async {
    final SignalMessage message;
    try {
      message = SignalMessage.decode(payload);
    } on FormatException catch (e) {
      debugPrint('bad signal: $e');
      return;
    }
    if (message case ControlSignal(action: ControlSignal.quality, :final value)) {
      _quality = QualityPreset.parse(value);
      _notify();
      return;
    }
    await _media.receive(message);
  }

  /// Host: switches the quality preset live and tells the display.
  Future<void> setQuality(QualityPreset quality) async {
    if (!isHost || quality == _quality) return;
    _quality = quality;
    _notify();
    await _media.applyQuality(quality);
    _send(ControlSignal(action: ControlSignal.quality, value: quality.name));
  }

  /// Display: the remote picture.
  Widget buildView({required bool fill}) => _media.buildView(fill: fill);

  void _notify() {
    if (!_closed) notifyListeners();
  }

  /// Tears down the media plane. Safe to call more than once.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _media.phase.removeListener(_onPhase);
    // Start the media teardown before awaiting anything else so it is not
    // delayed behind unrelated futures.
    final media = _media.close();
    unawaited(_statsSub?.cancel());
    await media;
  }
}
