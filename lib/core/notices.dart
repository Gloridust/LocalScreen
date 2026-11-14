import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'node/node_service.dart';

/// Something worth a toast. Mapped to localized text by the app shell.
sealed class AppNotice {
  const AppNotice();
}

/// A session ended.
final class SessionEndedNotice extends AppNotice {
  /// Creates the notice.
  const SessionEndedNotice({required this.peerName, required this.reason});

  final String peerName;
  final CloseReason reason;
}

/// The host could not capture its screen.
final class CaptureFailedNotice extends AppNotice {
  /// Creates the notice.
  const CaptureFailedNotice();
}

/// Extend was requested but no virtual monitor could be created; the session
/// mirrors instead.
final class ExtendFallbackNotice extends AppNotice {
  /// Creates the notice.
  const ExtendFallbackNotice();
}

/// A trusted host was accepted without asking.
final class AutoAcceptedNotice extends AppNotice {
  /// Creates the notice.
  const AutoAcceptedNotice(this.peerName);

  final String peerName;
}

/// An incoming request timed out before it was answered.
final class RequestExpiredNotice extends AppNotice {
  /// Creates the notice.
  const RequestExpiredNotice(this.peerName);

  final String peerName;
}

/// A request was declined because a session is already running.
final class BusyNotice extends AppNotice {
  /// Creates the notice.
  const BusyNotice(this.peerName);

  final String peerName;
}

/// A trusted device was forgotten.
final class ForgotNotice extends AppNotice {
  /// Creates the notice.
  const ForgotNotice(this.peerName);

  final String peerName;
}

/// The latest notice; every post is a new object so listeners always fire.
final noticeProvider = NotifierProvider<NoticeNotifier, AppNotice?>(NoticeNotifier.new);

/// See [noticeProvider].
class NoticeNotifier extends Notifier<AppNotice?> {
  @override
  AppNotice? build() => null;

  /// Publishes [notice].
  void post(AppNotice notice) => state = notice;
}
