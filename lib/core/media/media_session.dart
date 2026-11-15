import 'package:flutter/widgets.dart';

import 'captured_screen.dart';
import 'media_stats.dart';
import 'quality.dart';
import 'signalling.dart';

/// Lifecycle of the media plane of one session.
enum MediaPhase {
  /// Nothing started yet.
  idle,

  /// Host: opening the capture, which may wait for the user to pick a
  /// screen (system portal / picker).
  capturing,

  /// Offer/answer and ICE in progress.
  connecting,

  /// Frames are flowing.
  live,

  /// Gave up; see [MediaSession.failure].
  failed,
}

/// Why the media plane failed.
enum MediaFailure {
  /// Screen capture was refused, cancelled or is unsupported.
  capture,

  /// ICE / DTLS failed or the connection dropped.
  connection,
}

/// One WebRTC peer connection, as used by a session controller.
///
/// The host is the offerer and sends a single video track; the display is
/// receive-only and renders it. Signalling leaves through [onSignal].
abstract class MediaSession {
  /// Called with every message that must reach the peer.
  set onSignal(void Function(SignalMessage message) send);

  /// Current phase; listen for changes.
  ValueNotifier<MediaPhase> get phase;

  /// Set when [phase] becomes [MediaPhase.failed].
  MediaFailure? get failure;

  /// About one sample per second while live.
  Stream<MediaStats> get stats;

  /// Host: capture the screen, add it send-only and send the offer.
  ///
  /// With [source] that capture is sent instead of asking for one; its
  /// owner closes it.
  Future<void> startHost(QualityPreset quality, {CapturedScreen? source});

  /// Display: wait for the offer and answer it.
  Future<void> startDisplay();

  /// Feeds an offer / answer / candidate from the peer.
  Future<void> receive(SignalMessage message);

  /// Host: sends at most [framesPerSecond], on top of the preset's own
  /// ceiling. The display asks for this when it cannot keep up.
  Future<void> limitFramerate(int framesPerSecond);

  /// Host: applies a new preset to the running encoder.
  Future<void> applyQuality(QualityPreset quality);

  /// Display: the remote picture. [fill] crops to cover instead of fitting.
  Widget buildView({required bool fill});

  /// Stops tracks, closes the connection and releases renderers.
  Future<void> close();
}

/// Creates [MediaSession]s; swapped for a fake in tests and demo mode.
abstract class MediaEngine {
  /// Creates an idle session.
  MediaSession create();
}
