import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';
import '../../core/notices.dart';
import '../../core/prefs/preferences.dart';
import '../session/active_session.dart';

/// A host asking to use this device as a display.
@immutable
class IncomingRequest {
  /// Creates a request snapshot.
  const IncomingRequest({
    required this.sessionId,
    required this.peer,
    required this.mode,
    required this.expiresAt,
    this.pin,
    this.responding = false,
  });

  /// How long a PIN stays valid (PLAN.md › M1).
  static const pinLifetime = Duration(seconds: 60);

  final String sessionId;
  final DeviceInfo peer;
  final ShareMode mode;

  /// Shown to the user when the host is not trusted yet.
  final String? pin;
  final DateTime expiresAt;

  /// An answer is on its way.
  final bool responding;

  /// Copies with [responding] set.
  IncomingRequest asResponding() => IncomingRequest(
    sessionId: sessionId,
    peer: peer,
    mode: mode,
    expiresAt: expiresAt,
    pin: pin,
    responding: true,
  );
}

/// The pending incoming request, if any (display side).
final incomingRequestProvider = NotifierProvider<IncomingRequestNotifier, IncomingRequest?>(
  IncomingRequestNotifier.new,
);

/// See [incomingRequestProvider].
class IncomingRequestNotifier extends Notifier<IncomingRequest?> {
  @override
  IncomingRequest? build() {
    final service = ref.watch(nodeServiceProvider);
    final sub = service.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    return null;
  }

  NodeService get _service => ref.read(nodeServiceProvider);

  void _onEvent(NodeEvent event) {
    switch (event) {
      case NodeEvent_IncomingRequest(:final sessionId, :final peer, :final mode, :final pin):
        _onRequest(sessionId, peer, mode, pin);
      case NodeEvent_SessionEstablished(:final sessionId):
        if (state?.sessionId == sessionId) state = null;
      case NodeEvent_SessionClosed(:final sessionId, :final reason):
        final s = state;
        if (s?.sessionId != sessionId) return;
        state = null;
        if (reason == CloseReason.timeout || reason == CloseReason.pinFailed) {
          ref.read(noticeProvider.notifier).post(RequestExpiredNotice(s!.peer.name));
        }
      default:
        break;
    }
  }

  void _onRequest(String id, DeviceInfo peer, ShareMode mode, String? pin) {
    final notices = ref.read(noticeProvider.notifier);
    if (ref.read(activeSessionProvider) != null || state != null) {
      unawaited(_decline(id, pin));
      notices.post(BusyNotice(peer.name));
      return;
    }
    if (pin == null && ref.read(preferencesProvider).autoAcceptTrusted) {
      unawaited(
        _service.respondToRequest(id, accept: true).catchError((Object e) => debugPrint('$e')),
      );
      notices.post(AutoAcceptedNotice(peer.name));
      return;
    }
    state = IncomingRequest(
      sessionId: id,
      peer: peer,
      mode: mode,
      pin: pin,
      expiresAt: DateTime.now().add(IncomingRequest.pinLifetime),
    );
  }

  Future<void> _decline(String id, String? pin) async {
    try {
      if (pin == null) {
        await _service.respondToRequest(id, accept: false);
      } else {
        await _service.closeSession(id);
      }
    } catch (e) {
      debugPrint('decline failed: $e');
    }
  }

  /// Accepts a request from a trusted host.
  Future<void> accept() async {
    final s = state;
    if (s == null || s.responding) return;
    state = s.asResponding();
    try {
      await _service.respondToRequest(s.sessionId, accept: true);
    } catch (e) {
      debugPrint('accept failed: $e');
      if (ref.mounted) state = null;
    }
  }

  /// Declines (trusted) or cancels the pairing (PIN).
  Future<void> decline() async {
    final s = state;
    if (s == null) return;
    state = null;
    await _decline(s.sessionId, s.pin);
  }
}
