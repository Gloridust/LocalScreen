import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/node/local_node.dart';
import '../core/node/node_service.dart';
import '../core/notices.dart';
import '../core/update/update_controller.dart';
import '../features/pairing/incoming_request.dart';
import '../features/pairing/incoming_request_overlay.dart';
import '../features/session/active_session.dart';
import '../features/session/display_session_screen.dart';
import '../features/session/host_session_screen.dart';
import '../features/session/session_controller.dart';
import '../features/settings/trusted_devices_controller.dart';
import 'l10n.dart';
import 'router.dart';
import 'theme/lumen.dart';

/// Turns session-level state into navigation: the incoming-request card,
/// the session screens, and toasts for notices.
///
/// Lives just above the home screen so it can use the app's navigator,
/// theme and localizations.
class SessionCoordinator extends ConsumerStatefulWidget {
  /// Wraps the home screen.
  const SessionCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionCoordinator> createState() => _SessionCoordinatorState();
}

class _SessionCoordinatorState extends ConsumerState<SessionCoordinator> {
  Route<void>? _incomingRoute;
  Route<void>? _sessionRoute;

  NavigatorState get _nav => appNavigatorKey.currentState!;

  void _onIncoming(IncomingRequest? previous, IncomingRequest? next) {
    if (next != null && _incomingRoute == null) {
      final route = IncomingRequestRoute(tokens: context.ls, reduceMotion: context.reduceMotion);
      _incomingRoute = route;
      _nav.push(route).whenComplete(() {
        if (_incomingRoute == route) _incomingRoute = null;
      });
    } else if (next == null && _incomingRoute != null) {
      final route = _incomingRoute!;
      _incomingRoute = null;
      if (route.isActive) _nav.removeRoute(route);
    }
  }

  void _onSession(SessionController? previous, SessionController? session) {
    if (session != null && _sessionRoute == null) {
      _nav.popUntil((r) => r.isFirst);
      final route = LsPageRoute.of<void>(
        context,
        (_) => session.role == SessionRole.display
            ? DisplaySessionScreen(controller: session)
            : HostSessionScreen(controller: session),
      );
      _sessionRoute = route;
      _nav.push(route);
    } else if (session == null && _sessionRoute != null) {
      final route = _sessionRoute!;
      _sessionRoute = null;
      if (route.isActive) _nav.removeRoute(route);
    }
  }

  void _onNotice(AppNotice? previous, AppNotice? next) {
    if (next == null) return;
    final l10n = context.l10n;
    final (message, tone) = switch (next) {
      SessionEndedNotice(:final peerName, :final reason) => switch (reason) {
        CloseReason.remoteHangup => (l10n.noticeEndedRemote(peerName), LsStatus.idle),
        CloseReason.networkError => (l10n.failNetwork, LsStatus.error),
        CloseReason.timeout => (l10n.failTimeout(peerName), LsStatus.warning),
        CloseReason.declined => (l10n.failDeclined(peerName), LsStatus.warning),
        CloseReason.pinFailed => (l10n.failPin, LsStatus.warning),
        CloseReason.localHangup => (l10n.noticeEndedLocal, LsStatus.idle),
      },
      CaptureFailedNotice() => (l10n.noticeCaptureFailed, LsStatus.error),
      ExtendFallbackNotice() => (l10n.noticeExtendFallback, LsStatus.warning),
      AutoAcceptedNotice(:final peerName) => (
        l10n.noticeAutoAccepted(peerName),
        LsStatus.connected,
      ),
      RequestExpiredNotice(:final peerName) => (
        l10n.noticeRequestExpired(peerName),
        LsStatus.warning,
      ),
      BusyNotice(:final peerName) => (l10n.noticeBusy(peerName), LsStatus.warning),
      ForgotNotice(:final peerName) => (l10n.noticeForgot(peerName), LsStatus.idle),
    };
    final overlay = _nav.overlay;
    if (overlay != null) LsToast.show(overlay, message, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the event-driven providers alive from the first frame.
    ref.watch(localNodeProvider);
    ref.watch(trustedDevicesProvider);
    ref.watch(updateControllerProvider);
    ref.listen<IncomingRequest?>(incomingRequestProvider, _onIncoming);
    ref.listen<SessionController?>(activeSessionProvider, _onSession);
    ref.listen<AppNotice?>(noticeProvider, _onNotice);
    return widget.child;
  }
}
