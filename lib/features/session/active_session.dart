import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_providers.dart';
import '../../core/media/media_session.dart';
import '../../core/media/quality.dart';
import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';
import '../../core/notices.dart';
import '../../core/prefs/preferences.dart';
import '../pairing/outgoing_request.dart';
import 'session_controller.dart';

/// The running session, if any. M1 runs one session at a time.
final activeSessionProvider = NotifierProvider<ActiveSessionNotifier, SessionController?>(
  ActiveSessionNotifier.new,
);

/// Creates, feeds and tears down [SessionController]s from node events.
class ActiveSessionNotifier extends Notifier<SessionController?> {
  /// How long to wait for `SessionClosed` after asking the node to close.
  static const closeGrace = Duration(seconds: 2);

  /// Why we are closing a session ourselves; wins over the event's reason.
  /// A null value means "close without a notice".
  final _localClose = <String, CloseReason?>{};

  @override
  SessionController? build() {
    final service = ref.watch(nodeServiceProvider);
    final sub = service.events.listen(_onEvent);
    ref.onDispose(() {
      sub.cancel();
      unawaited(_current?.close());
      _current = null;
    });
    return null;
  }

  /// Mirror of [state] that stays readable inside `onDispose`.
  SessionController? _current;

  void _set(SessionController? controller) {
    _current = controller;
    state = controller;
  }

  NodeService get _service => ref.read(nodeServiceProvider);

  void _onEvent(NodeEvent event) {
    switch (event) {
      case NodeEvent_SessionEstablished(:final sessionId, :final peer, :final role, :final mode):
        _establish(sessionId, peer, role, mode);
      case NodeEvent_Signal(:final sessionId, :final payload):
        if (state?.sessionId == sessionId) unawaited(state!.handleSignal(payload));
      case NodeEvent_SessionClosed(:final sessionId, :final reason):
        if (state?.sessionId == sessionId) unawaited(_teardown(reason));
      default:
        break;
    }
  }

  void _establish(String id, DeviceInfo peer, SessionRole role, ShareMode mode) {
    if (state != null) {
      // Busy: refuse the second session rather than juggling two.
      unawaited(_service.closeSession(id).catchError((Object e) => debugPrint('$e')));
      return;
    }
    final outgoing = ref.read(outgoingRequestProvider);
    final QualityPreset quality = outgoing?.sessionId == id
        ? outgoing!.quality
        : ref.read(preferencesProvider).defaultQuality;
    if (outgoing?.sessionId == id) ref.read(outgoingRequestProvider.notifier).handOff();
    late final SessionController controller;
    controller = SessionController(
      sessionId: id,
      peer: peer,
      role: role,
      mode: mode,
      quality: quality,
      media: ref.read(mediaEngineProvider).create(),
      node: _service,
      onMediaFailure: (failure) {
        if (state != controller) return;
        if (failure == MediaFailure.capture) {
          ref.read(noticeProvider.notifier).post(const CaptureFailedNotice());
          unawaited(_close(silent: true));
        } else {
          unawaited(_close(reason: CloseReason.networkError));
        }
      },
    );
    _set(controller);
    unawaited(controller.start());
  }

  /// Ends the running session from this side.
  Future<void> stop() => _close();

  Future<void> _close({CloseReason reason = CloseReason.localHangup, bool silent = false}) async {
    final controller = state;
    if (controller == null) return;
    _localClose[controller.sessionId] = silent ? null : reason;
    try {
      await _service.closeSession(controller.sessionId).timeout(closeGrace);
    } catch (e) {
      debugPrint('closeSession failed: $e');
    }
    // The node normally answers with SessionClosed; don't depend on it.
    if (state == controller) await _teardown(reason, silent: silent);
  }

  Future<void> _teardown(CloseReason reason, {bool silent = false}) async {
    final controller = state;
    if (controller == null) return;
    final id = controller.sessionId;
    if (_localClose.containsKey(id)) {
      final local = _localClose.remove(id);
      silent = silent || local == null;
      reason = local ?? reason;
    }
    _set(null);
    await controller.close();
    if (!silent && ref.mounted) {
      ref
          .read(noticeProvider.notifier)
          .post(SessionEndedNotice(peerName: controller.peer.name, reason: reason));
    }
  }
}
