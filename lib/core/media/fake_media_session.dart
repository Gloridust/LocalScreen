import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/theme/context_ext.dart';
import 'captured_screen.dart';
import 'media_session.dart';
import 'media_stats.dart';
import 'quality.dart';
import 'signalling.dart';

/// [MediaEngine] that fakes the media plane for tests and demo mode.
class FakeMediaEngine implements MediaEngine {
  /// Creates the engine. [connectDelay] is how long "negotiation" takes.
  const FakeMediaEngine({this.connectDelay = const Duration(milliseconds: 900)});

  final Duration connectDelay;

  @override
  MediaSession create() => FakeMediaSession(connectDelay: connectDelay);
}

/// Goes live after [connectDelay] and emits plausible statistics; renders a
/// stylised desktop instead of video.
class FakeMediaSession implements MediaSession {
  /// Creates a fake session.
  FakeMediaSession({required this.connectDelay});

  final Duration connectDelay;
  final _stats = StreamController<MediaStats>.broadcast();
  final _random = math.Random(7);
  Timer? _connect;
  Timer? _ticker;
  QualityPreset _quality = QualityPreset.balanced;

  /// Messages "sent" to the peer, for assertions.
  final List<SignalMessage> sent = [];

  @override
  final phase = ValueNotifier(MediaPhase.idle);

  @override
  MediaFailure? failure;

  @override
  set onSignal(void Function(SignalMessage message) send) {}

  @override
  Stream<MediaStats> get stats => _stats.stream;

  void _goLive() {
    phase.value = MediaPhase.connecting;
    _connect = Timer(connectDelay, () {
      phase.value = MediaPhase.live;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _tick();
    });
  }

  void _tick() {
    if (_stats.isClosed) return;
    final edge = _quality.targetShortEdge ?? 1600;
    _stats.add(
      MediaStats(
        width: (edge * 16 / 10).round(),
        height: edge,
        framesPerSecond: _quality.maxFramerate - _random.nextInt(3).toDouble(),
        bitrateKbps: _quality.maxBitrate / 1000 * (0.55 + _random.nextDouble() * 0.2),
        roundTripMs: 3 + _random.nextDouble() * 4,
        jitterMs: 1 + _random.nextDouble(),
      ),
    );
  }

  @override
  Future<void> startHost(QualityPreset quality, {CapturedScreen? source}) async {
    _quality = quality;
    _goLive();
  }

  @override
  Future<void> startDisplay() async => _goLive();

  @override
  Future<void> receive(SignalMessage message) async {}

  @override
  Future<void> applyQuality(QualityPreset quality) async => _quality = quality;

  @override
  Widget buildView({required bool fill}) => const _FakeDesktop();

  @override
  Future<void> close() async {
    _connect?.cancel();
    _ticker?.cancel();
    await _stats.close();
  }
}

/// A calm, abstract "remote screen" made from theme tokens.
class _FakeDesktop extends StatelessWidget {
  const _FakeDesktop();

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final c = ls.colors;
    return Center(
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(c.accent.withValues(alpha: 0.22), c.surface),
                c.bg,
                Color.alphaBlend(c.accentAlt.withValues(alpha: 0.14), c.surface),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final u = box.maxWidth / 100;
              Widget window(double l, double t, double w, double h, int lines) => Positioned(
                left: l * u,
                top: t * u,
                width: w * u,
                height: h * u,
                child: Container(
                  padding: EdgeInsets.all(u * 1.6),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(u),
                    border: Border.all(color: c.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < lines; i++)
                        Container(
                          margin: EdgeInsets.only(bottom: u * 1.1),
                          height: u * 0.9,
                          width: w * u * (0.3 + ((i * 37) % 55) / 100),
                          decoration: BoxDecoration(
                            color: (i % 4 == 0 ? c.accent : c.textTertiary).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(u),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              return Stack(
                children: [
                  window(6, 6, 54, 46, 14),
                  window(64, 10, 30, 22, 6),
                  window(64, 36, 30, 20, 5),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
