import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/media/media_session.dart';
import '../../core/media/media_stats.dart';
import '../../core/media/quality.dart';
import '../../core/media/signalling.dart';
import '../../core/node/node_service.dart';
import '../../core/platform/virtual_display.dart';

/// Drives the media plane of one established session.
///
/// Created on `SessionEstablished`, fed every `Signal` for its session and
/// disposed on `SessionClosed` (or any local close path). The host is the
/// WebRTC offerer.
///
/// In extend mode the host first adds a virtual monitor sized like the
/// display's screen (which the display reports right after the session is
/// established), then captures it like any other monitor.
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
    required this._virtualDisplays,
    required this.onMediaFailure,
    required this.onExtendFallback,
    this.localScreen,
  });

  /// How long the host waits for the display to report its screen size.
  static const screenReportTimeout = Duration(milliseconds: 1500);

  final String sessionId;
  final DeviceInfo peer;
  final SessionRole role;
  final ShareMode mode;

  /// Called once if the media plane gives up.
  final void Function(MediaFailure failure) onMediaFailure;

  /// Host: extend was asked for but no virtual monitor could be created, so
  /// the session mirrors instead.
  final void Function() onExtendFallback;

  /// Display: this device's screen size in physical pixels, sent to the host.
  final ScreenSize? localScreen;

  final VirtualDisplayProvider _virtualDisplays;
  final _peerScreen = Completer<ScreenSize>();
  VirtualDisplay? _virtualDisplay;
  bool _preparingDisplay = false;

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

  /// Host, extend mode: the virtual monitor is being created.
  bool get preparingDisplay => _preparingDisplay;

  /// Host, extend mode: desktop name of the virtual monitor, once it exists.
  String? get virtualDisplayLabel => _virtualDisplay?.label;

  /// Starts capture (host) or waits for the offer (display).
  Future<void> start() async {
    _media.onSignal = _send;
    _media.phase.addListener(_onPhase);
    _statsSub = _media.stats.listen((s) {
      _stats = s;
      _notify();
    });
    if (isHost) {
      if (mode == ShareMode.extend) await _addVirtualDisplay();
      if (_closed) return;
      await _media.startHost(_quality);
    } else {
      await _media.startDisplay();
      final screen = localScreen;
      if (screen != null) {
        _send(ControlSignal(action: ControlSignal.screen, value: screen.encode()));
      }
    }
  }

  Future<void> _addVirtualDisplay() async {
    _preparingDisplay = true;
    _notify();
    try {
      final reported = await _peerScreen.future.timeout(
        screenReportTimeout,
        onTimeout: () => ScreenSize.fallback,
      );
      final display = await _virtualDisplays.create(
        size: reported.normalized(),
        refreshRate: _quality.maxFramerate,
      );
      if (_closed) {
        await display.dispose();
      } else {
        _virtualDisplay = display;
      }
    } catch (e) {
      debugPrint('virtual display failed: $e');
      if (!_closed) onExtendFallback();
    } finally {
      _preparingDisplay = false;
      _notify();
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
    if (message case ControlSignal(action: ControlSignal.screen, :final value)) {
      final size = ScreenSize.tryParse(value);
      if (size != null && !_peerScreen.isCompleted) _peerScreen.complete(size);
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
    final display = _virtualDisplay;
    _virtualDisplay = null;
    await media;
    // After the capture stopped, so the picture never shows a vanishing monitor.
    await display?.dispose();
  }
}
