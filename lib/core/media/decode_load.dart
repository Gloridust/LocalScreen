/// Cumulative receive counters of one stats snapshot.
class DecodeSample {
  /// Creates a sample.
  const DecodeSample({
    required this.framesReceived,
    required this.framesDecoded,
    required this.framesDropped,
  });

  /// Complete frames that arrived over the network.
  final int framesReceived;
  final int framesDecoded;

  /// Frames thrown away because decoding or showing them came too late.
  final int framesDropped;
}

/// Decides, on the display, how many frames per second this device can
/// take, and lowers the figure when the picture arrives faster than it can
/// be decoded and shown.
///
/// A sender only reacts to the network. A slow receiver on a fast LAN is
/// invisible to it: frames pile up, memory grows and the picture falls
/// behind. So the display watches its own decoder and asks for less.
///
/// The limit only ever goes down within a session; a level that proved too
/// much is not tried again.
class DecodeLoadMonitor {
  /// Starts at [limit] frames per second (null: whatever the host sends).
  DecodeLoadMonitor({this.limit});

  /// Frame rates to fall back through.
  static const steps = [60, 30, 20, 15, 10];

  /// Samples (about one per second) judged together.
  static const window = 5;

  /// Share of frames dropped that counts as overload.
  static const dropShare = 0.12;

  /// Share of the received frames that must come out of the decoder; less
  /// means a backlog is building.
  static const keepUpShare = 0.75;

  /// Samples to wait after a step before judging again, so the new rate
  /// has taken effect.
  static const settle = 8;

  /// The current ceiling in frames per second; null while unlimited.
  int? limit;

  final _recent = <DecodeSample>[];
  int _ignore = 0;

  /// The starting limit for a device with [cores] logical CPUs and
  /// [memoryMb] of RAM (null if unknown): modest hardware starts at 30.
  static int? startingLimit({required int cores, int? memoryMb}) =>
      cores <= 2 || (memoryMb != null && memoryMb <= 3072) ? 30 : null;

  /// Feeds one snapshot; returns the new limit when it just went down.
  int? add(DecodeSample sample) {
    if (_ignore > 0) {
      _ignore--;
      _recent
        ..clear()
        ..add(sample);
      return null;
    }
    _recent.add(sample);
    if (_recent.length <= window) return null;
    _recent.removeAt(0);
    final first = _recent.first;
    final decoded = sample.framesDecoded - first.framesDecoded;
    final dropped = sample.framesDropped - first.framesDropped;
    final received = sample.framesReceived - first.framesReceived;
    final total = decoded + dropped;
    if (total <= 0) return null;
    final overloaded = dropped / total > dropShare || decoded < received * keepUpShare;
    if (!overloaded) return null;

    // Step below what is actually being shown, not just below the ceiling.
    final shown = decoded / (window - 1);
    final ceiling = limit ?? steps.first + 1;
    final next =
        steps.where((s) => s < ceiling && s <= shown * 1.1 + 1).firstOrNull ??
        steps.where((s) => s < ceiling).firstOrNull;
    if (next == null) return null;
    limit = next;
    _ignore = settle;
    _recent.clear();
    return next;
  }
}
