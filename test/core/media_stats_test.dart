import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/media/media_stats.dart';
import 'package:localscreen/core/media/quality.dart';

void main() {
  group('StatsSampler', () {
    StatsEntry inbound(double t, int bytes) => StatsEntry('inbound-rtp', t, {
      'kind': 'video',
      'bytesReceived': bytes,
      'frameWidth': 1920,
      'frameHeight': 1080,
      'framesPerSecond': 59.0,
      'jitter': 0.002,
    });
    const pair = StatsEntry('candidate-pair', 0, {
      'state': 'succeeded',
      'nominated': true,
      'currentRoundTripTime': 0.004,
    });

    test('reads resolution, fps, jitter and RTT; bitrate needs two samples', () {
      final sampler = StatsSampler();
      final first = sampler.sample([inbound(1000, 0), pair], inbound: true);
      expect(first.width, 1920);
      expect(first.height, 1080);
      expect(first.framesPerSecond, 59);
      expect(first.bitrateKbps, isNull);
      expect(first.roundTripMs, closeTo(4, 1e-9));
      expect(first.jitterMs, closeTo(2, 1e-9));

      // 1 MB in one second = 8000 kbps.
      final second = sampler.sample([inbound(2000, 1000000), pair], inbound: true);
      expect(second.bitrateKbps, closeTo(8000, 1e-6));
      expect(second.latencyMs, closeTo(4, 1e-9));
    });

    test('falls back to remote-inbound RTT on the host', () {
      final s = StatsSampler().sample([
        const StatsEntry('outbound-rtp', 0, {'kind': 'video', 'bytesSent': 10}),
        const StatsEntry('remote-inbound-rtp', 0, {'roundTripTime': 0.012}),
      ], inbound: false);
      expect(s.roundTripMs, closeTo(12, 1e-9));
    });

    test('empty snapshot yields empty stats', () {
      final s = StatsSampler().sample(const [], inbound: true);
      expect(s.width, isNull);
      expect(s.latencyMs, isNull);
    });
  });

  group('QualityPreset', () {
    test('scales down to the target short edge, never up', () {
      expect(QualityPreset.smooth.scaleFor(2560, 1440), closeTo(2, 1e-9));
      expect(QualityPreset.balanced.scaleFor(2560, 1440), closeTo(1440 / 1080, 1e-9));
      expect(QualityPreset.balanced.scaleFor(1280, 720), 1);
      expect(QualityPreset.clear.scaleFor(3840, 2160), 1);
    });

    test('parse falls back to balanced', () {
      expect(QualityPreset.parse('clear'), QualityPreset.clear);
      expect(QualityPreset.parse(null), QualityPreset.balanced);
      expect(QualityPreset.parse('nope'), QualityPreset.balanced);
    });
  });
}
