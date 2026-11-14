import 'package:flutter/foundation.dart';

/// Live numbers shown in the stat pills, sampled about once per second.
@immutable
class MediaStats {
  /// Creates a sample.
  const MediaStats({
    this.width,
    this.height,
    this.framesPerSecond,
    this.bitrateKbps,
    this.roundTripMs,
    this.jitterMs,
  });

  final int? width;
  final int? height;
  final double? framesPerSecond;
  final double? bitrateKbps;
  final double? roundTripMs;
  final double? jitterMs;

  /// Latency to show: RTT when known, else jitter.
  double? get latencyMs => roundTripMs ?? jitterMs;
}

/// Turns consecutive `getStats()` snapshots into [MediaStats].
///
/// Works on plain maps (`type` → `values`) so it can be tested without a
/// peer connection. Bitrate needs two snapshots; the first sample has none.
class StatsSampler {
  int? _lastBytes;
  double? _lastTimestampMs;

  /// Reduces one snapshot. [reports] are `(type, timestampMs, values)`.
  MediaStats sample(List<StatsEntry> reports, {required bool inbound}) {
    final rtpType = inbound ? 'inbound-rtp' : 'outbound-rtp';
    StatsEntry? rtp;
    for (final r in reports) {
      if (r.type == rtpType && r.values['kind'] != 'audio') {
        rtp = r;
        break;
      }
    }
    double? rtt;
    for (final r in reports) {
      if (r.type == 'candidate-pair' &&
          (r.values['nominated'] == true || r.values['state'] == 'succeeded')) {
        final v = _num(r.values['currentRoundTripTime']);
        if (v != null) {
          rtt = v * 1000;
          break;
        }
      }
    }
    if (rtt == null) {
      for (final r in reports) {
        if (r.type == 'remote-inbound-rtp') {
          final v = _num(r.values['roundTripTime']);
          if (v != null) rtt = v * 1000;
        }
      }
    }
    if (rtp == null) return MediaStats(roundTripMs: rtt);

    final values = rtp.values;
    final bytes = _num(values[inbound ? 'bytesReceived' : 'bytesSent'])?.toInt();
    double? kbps;
    if (bytes != null && _lastBytes != null && _lastTimestampMs != null) {
      final dt = rtp.timestampMs - _lastTimestampMs!;
      if (dt > 0) kbps = (bytes - _lastBytes!) * 8 / dt;
    }
    if (bytes != null) {
      _lastBytes = bytes;
      _lastTimestampMs = rtp.timestampMs;
    }
    final jitter = _num(values['jitter']);
    return MediaStats(
      width: _num(values['frameWidth'])?.toInt(),
      height: _num(values['frameHeight'])?.toInt(),
      framesPerSecond: _num(values['framesPerSecond']),
      bitrateKbps: kbps != null && kbps >= 0 ? kbps : null,
      roundTripMs: rtt,
      jitterMs: jitter == null ? null : jitter * 1000,
    );
  }

  static double? _num(Object? v) => switch (v) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };
}

/// One report of a stats snapshot.
@immutable
class StatsEntry {
  /// Creates an entry.
  const StatsEntry(this.type, this.timestampMs, this.values);

  final String type;

  /// Report timestamp in milliseconds.
  final double timestampMs;
  final Map<Object?, Object?> values;
}
