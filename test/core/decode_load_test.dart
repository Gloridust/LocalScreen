import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/media/decode_load.dart';

/// Feeds [seconds] one-second samples at [decoded] and [dropped] frames per
/// second out of [received] (default: all of them); returns every new limit.
List<int> _run(
  DecodeLoadMonitor monitor, {
  required int seconds,
  required int decoded,
  int dropped = 0,
  int? received,
  _Totals? totals,
}) {
  final t = totals ?? _Totals();
  final limits = <int>[];
  for (var i = 0; i < seconds; i++) {
    t.decoded += decoded;
    t.dropped += dropped;
    t.received += received ?? decoded + dropped;
    final limit = monitor.add(
      DecodeSample(framesReceived: t.received, framesDecoded: t.decoded, framesDropped: t.dropped),
    );
    if (limit != null) limits.add(limit);
  }
  return limits;
}

class _Totals {
  int decoded = 0;
  int dropped = 0;
  int received = 0;
}

void main() {
  test('modest hardware starts at 30 frames per second', () {
    expect(DecodeLoadMonitor.startingLimit(cores: 2, memoryMb: 8192), 30);
    expect(DecodeLoadMonitor.startingLimit(cores: 4, memoryMb: 2048), 30);
    expect(DecodeLoadMonitor.startingLimit(cores: 8, memoryMb: 16384), isNull);
    expect(DecodeLoadMonitor.startingLimit(cores: 8), isNull);
  });

  test('a device that keeps up is left alone', () {
    final monitor = DecodeLoadMonitor();
    expect(_run(monitor, seconds: 120, decoded: 60), isEmpty);
    expect(monitor.limit, isNull);
  });

  test('dropped frames lower the pace to what is actually shown', () {
    final monitor = DecodeLoadMonitor();
    // 60 arrive, only 24 make it to the screen.
    expect(_run(monitor, seconds: 10, decoded: 24, dropped: 36), [20]);
    expect(monitor.limit, 20);
  });

  test('a backlog building in front of the decoder lowers the pace', () {
    final monitor = DecodeLoadMonitor();
    // 60 arrive, 30 come out, nothing is dropped yet: they are piling up.
    expect(_run(monitor, seconds: 10, decoded: 30, received: 60), [30]);
  });

  test('waits for a step to take effect, then steps again if needed', () {
    final monitor = DecodeLoadMonitor(limit: 30);
    final totals = _Totals();
    final limits = _run(monitor, seconds: 40, decoded: 12, dropped: 18, totals: totals);
    // One step per settle period plus window, never all at once.
    expect(limits, [10]);
    expect(_run(monitor, seconds: 60, decoded: 5, dropped: 5, totals: totals), isEmpty);
    expect(monitor.limit, 10, reason: 'there is no step below the last one');
  });

  test('never goes back up within a session', () {
    final monitor = DecodeLoadMonitor();
    final totals = _Totals();
    _run(monitor, seconds: 10, decoded: 24, dropped: 36, totals: totals);
    expect(_run(monitor, seconds: 120, decoded: 20, totals: totals), isEmpty);
    expect(monitor.limit, 20);
  });
}
