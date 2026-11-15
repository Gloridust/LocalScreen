import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/quality.dart';
import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';
import '../../core/platform/virtual_display.dart';
import '../../core/prefs/preferences.dart';

/// Where the host-side connect flow is.
enum OutgoingPhase {
  /// Choosing mode and quality.
  configuring,

  /// Request sent; waiting for the display.
  requesting,

  /// The display shows a PIN; type it here.
  awaitingPin,

  /// PIN submitted; waiting for the verdict.
  verifying,

  /// The secure channel is up; the session takes over.
  established,

  /// The attempt ended; see [OutgoingRequest.failure].
  failed,
}

/// Why an outgoing attempt failed.
enum OutgoingFailure { declined, timeout, pinFailed, network, request }

/// Host-side connect flow state for one target device.
@immutable
class OutgoingRequest {
  /// Creates a state snapshot.
  const OutgoingRequest({
    required this.peer,
    required this.mode,
    required this.quality,
    this.phase = OutgoingPhase.configuring,
    this.sessionId,
    this.attemptsLeft,
    this.rejections = 0,
    this.failure,
  });

  final DeviceInfo peer;

  /// What the user picked. Extend is requested only where the host can
  /// create a virtual monitor; elsewhere the session mirrors.
  final ShareMode mode;
  final QualityPreset quality;
  final OutgoingPhase phase;
  final String? sessionId;
  final int? attemptsLeft;

  /// Number of wrong PINs so far; drives the shake.
  final int rejections;
  final OutgoingFailure? failure;

  /// Copies with changes.
  OutgoingRequest copyWith({
    ShareMode? mode,
    QualityPreset? quality,
    OutgoingPhase? phase,
    String? sessionId,
    int? attemptsLeft,
    int? rejections,
    OutgoingFailure? failure,
  }) {
    return OutgoingRequest(
      peer: peer,
      mode: mode ?? this.mode,
      quality: quality ?? this.quality,
      phase: phase ?? this.phase,
      sessionId: sessionId ?? this.sessionId,
      attemptsLeft: attemptsLeft ?? this.attemptsLeft,
      rejections: rejections ?? this.rejections,
      failure: failure,
    );
  }
}

/// The host-side connect flow (connect sheet).
final outgoingRequestProvider = NotifierProvider<OutgoingRequestNotifier, OutgoingRequest?>(
  OutgoingRequestNotifier.new,
);

/// See [outgoingRequestProvider].
class OutgoingRequestNotifier extends Notifier<OutgoingRequest?> {
  /// Events that arrived before `requestSession` returned the id.
  final _early = <NodeEvent>[];

  @override
  OutgoingRequest? build() {
    final service = ref.watch(nodeServiceProvider);
    final sub = service.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    return null;
  }

  NodeService get _service => ref.read(nodeServiceProvider);

  /// Opens the flow for [peer] with the default mode and quality.
  void open(DeviceInfo peer) {
    final prefs = ref.read(preferencesProvider);
    state = OutgoingRequest(peer: peer, mode: prefs.defaultMode, quality: prefs.defaultQuality);
  }

  /// Picks the share mode.
  void setMode(ShareMode mode) => state = state?.copyWith(mode: mode);

  /// Picks the quality preset.
  void setQuality(QualityPreset quality) => state = state?.copyWith(quality: quality);

  /// Sends the request to the peer.
  Future<void> start() async {
    final s = state;
    if (s == null) return;
    _early.clear();
    state = OutgoingRequest(
      peer: s.peer,
      mode: s.mode,
      quality: s.quality,
      phase: OutgoingPhase.requesting,
    );
    try {
      final canExtend = await ref.read(extendSupportedProvider.future);
      final mode = canExtend ? s.mode : ShareMode.mirror;
      final id = await _service.requestSession(s.peer.id, mode);
      if (!ref.mounted || state?.phase != OutgoingPhase.requesting) {
        await _service.closeSession(id);
        return;
      }
      state = state!.copyWith(sessionId: id);
      final early = List.of(_early);
      _early.clear();
      early.forEach(_onEvent);
    } catch (e) {
      debugPrint('requestSession failed: $e');
      if (ref.mounted && state != null) {
        state = state!.copyWith(phase: OutgoingPhase.failed, failure: OutgoingFailure.request);
      }
    }
  }

  /// Submits the PIN typed by the user.
  Future<void> submitPin(String pin) async {
    final s = state;
    final id = s?.sessionId;
    if (s == null || id == null || s.phase != OutgoingPhase.awaitingPin) return;
    state = s.copyWith(phase: OutgoingPhase.verifying);
    try {
      await _service.submitPin(id, pin);
    } catch (e) {
      debugPrint('submitPin failed: $e');
      if (ref.mounted) {
        state = state?.copyWith(phase: OutgoingPhase.failed, failure: OutgoingFailure.network);
      }
    }
  }

  /// Clears the flow once the session has taken over, without cancelling.
  void handOff() => state = null;

  /// Closes the flow, cancelling a pending request.
  Future<void> dismiss() async {
    final s = state;
    state = null;
    final id = s?.sessionId;
    if (id != null && s!.phase != OutgoingPhase.established && s.phase != OutgoingPhase.failed) {
      await _service.closeSession(id).catchError((Object e) => debugPrint('$e'));
    }
  }

  void _onEvent(NodeEvent event) {
    final s = state;
    if (s == null) return;
    final id = sessionIdOf(event);
    if (id == null) return;
    if (s.sessionId == null) {
      if (s.phase == OutgoingPhase.requesting) _early.add(event);
      return;
    }
    if (id != s.sessionId) return;
    switch (event) {
      case NodeEvent_PinRequired():
        state = s.copyWith(phase: OutgoingPhase.awaitingPin);
      case NodeEvent_PinRejected(:final attemptsLeft):
        state = s.copyWith(
          phase: OutgoingPhase.awaitingPin,
          attemptsLeft: attemptsLeft,
          rejections: s.rejections + 1,
        );
      case NodeEvent_SessionEstablished():
        state = s.copyWith(phase: OutgoingPhase.established);
      case NodeEvent_SessionClosed(:final reason):
        if (s.phase == OutgoingPhase.established) return;
        state = s.copyWith(phase: OutgoingPhase.failed, failure: _failureOf(reason));
      default:
        break;
    }
  }

  static OutgoingFailure _failureOf(CloseReason reason) => switch (reason) {
    CloseReason.declined => OutgoingFailure.declined,
    CloseReason.timeout => OutgoingFailure.timeout,
    CloseReason.pinFailed => OutgoingFailure.pinFailed,
    CloseReason.localHangup ||
    CloseReason.remoteHangup ||
    CloseReason.networkError => OutgoingFailure.network,
  };
}
