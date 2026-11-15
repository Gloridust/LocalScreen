import 'dart:math' as math;

/// How the host trades resolution, frame rate and bitrate.
enum QualityPreset {
  /// 流畅 — 720p short edge, 60 fps, keeps motion fluid on weak Wi-Fi.
  smooth(targetShortEdge: 720, maxFramerate: 60, minBitrate: 500000, maxBitrate: 4000000),

  /// 均衡 — 1080p short edge, 60 fps. The default.
  balanced(targetShortEdge: 1080, maxFramerate: 60, minBitrate: 1500000, maxBitrate: 10000000),

  /// 清晰 — native resolution at 30 fps; text stays crisp.
  clear(targetShortEdge: null, maxFramerate: 30, minBitrate: 3000000, maxBitrate: 20000000);

  const QualityPreset({
    required this.targetShortEdge,
    required this.maxFramerate,
    required this.minBitrate,
    required this.maxBitrate,
  });

  /// Upper bound for the encoded short edge in pixels; null keeps native.
  final int? targetShortEdge;
  final int maxFramerate;

  /// Floor in bits per second. The bandwidth estimator starts from here, so
  /// the picture is sharp from the first frames instead of ramping up from
  /// libwebrtc's conservative 300 kbps default; any LAN sustains it.
  final int minBitrate;

  /// Upper bound in bits per second.
  final int maxBitrate;

  /// What the encoder should give up first under pressure.
  QualityDegradation get degradation => switch (this) {
    smooth => QualityDegradation.maintainFramerate,
    balanced => QualityDegradation.balanced,
    clear => QualityDegradation.maintainResolution,
  };

  /// `scaleResolutionDownBy` for a source of [width] × [height].
  double scaleFor(int width, int height) {
    final target = targetShortEdge;
    final shortEdge = math.min(width, height);
    if (target == null || shortEdge <= 0) return 1.0;
    return math.max(1.0, shortEdge / target);
  }

  /// Parses [name], falling back to [balanced].
  static QualityPreset parse(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => balanced);
}

/// WebRTC `degradationPreference` values used by the presets.
enum QualityDegradation { maintainFramerate, maintainResolution, balanced }
