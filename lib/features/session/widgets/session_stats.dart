import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/l10n.dart';
import '../../../app/theme/lumen.dart';
import '../../../core/media/media_stats.dart';

/// Formatting for the live statistics.
abstract final class StatFormat {
  static const _dash = '—';

  /// `1920×1080`.
  static String resolution(MediaStats? s) {
    final w = s?.width, h = s?.height;
    return w == null || h == null || w == 0 ? _dash : '$w×$h';
  }

  /// `60 fps`.
  static String fps(MediaStats? s) {
    final f = s?.framesPerSecond;
    return f == null ? '$_dash fps' : '${f.round()} fps';
  }

  /// `8.2 Mbps` / `820 kbps`.
  static String bitrate(MediaStats? s) {
    final k = s?.bitrateKbps;
    if (k == null) return '$_dash Mbps';
    return k >= 1000 ? '${(k / 1000).toStringAsFixed(1)} Mbps' : '${k.round()} kbps';
  }

  /// `4 ms`.
  static String latency(MediaStats? s) {
    final ms = s?.latencyMs;
    return ms == null ? '$_dash ms' : '${ms.round()} ms';
  }

  /// `mm:ss`, or `h:mm:ss` past an hour.
  static String elapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// The four stat pills: resolution, frame rate, bitrate, latency.
class SessionStatPills extends StatelessWidget {
  /// Creates the pills; [onMedia] for the translucent video toolbar.
  const SessionStatPills({
    super.key,
    required this.stats,
    this.onMedia = false,
    this.dense = false,
  });

  final MediaStats? stats;
  final bool onMedia;

  /// Only latency, for narrow toolbars.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ls = context.ls;
    final l10n = context.l10n;
    final pills = [
      if (!dense) LsStatPill(value: StatFormat.resolution(stats), onMedia: onMedia),
      if (!dense) LsStatPill(value: StatFormat.fps(stats), onMedia: onMedia),
      if (!dense) LsStatPill(value: StatFormat.bitrate(stats), onMedia: onMedia),
      LsStatPill(label: l10n.statLatency, value: StatFormat.latency(stats), onMedia: onMedia),
    ];
    return Wrap(spacing: ls.space.sm, runSpacing: ls.space.sm, children: pills);
  }
}

/// Text that counts up from [since] once per second.
class ElapsedText extends StatefulWidget {
  /// Creates the counter.
  const ElapsedText({super.key, required this.since, required this.style});

  final DateTime since;
  final TextStyle style;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    return Text(StatFormat.elapsed(elapsed), style: widget.style);
  }
}
