import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One connected monitor and the mode it currently runs.
@immutable
class MonitorState {
  /// Creates a monitor.
  const MonitorState({
    required this.connector,
    required this.vendor,
    required this.product,
    required this.serial,
    required this.displayName,
    required this.modeId,
    required this.width,
    required this.height,
    required this.supportedScales,
  });

  /// Port name such as `DP-1`, or `Meta-0` for a virtual monitor.
  final String connector;
  final String vendor;
  final String product;
  final String serial;

  /// Human-readable name the desktop shows.
  final String displayName;

  /// Id of the current mode; null when the monitor is off.
  final String? modeId;

  /// Size of the current mode in physical pixels.
  final int width;
  final int height;

  /// Scales the compositor accepts for the current mode.
  final List<double> supportedScales;

  /// Whether this is a Mutter virtual monitor rather than real hardware.
  bool get isVirtual => vendor == 'MetaVendor';
}

/// A rectangle of the desktop shown by one monitor (or several mirrored ones).
@immutable
class LogicalMonitor {
  /// Creates a logical monitor.
  const LogicalMonitor({
    required this.x,
    required this.y,
    required this.scale,
    required this.transform,
    required this.primary,
    required this.connectors,
  });

  final int x;
  final int y;
  final double scale;

  /// Mutter's transform: 0 normal, 1–3 rotated by 90° steps, 4–7 the same
  /// flipped.
  final int transform;
  final bool primary;
  final List<String> connectors;

  /// Whether [transform] swaps width and height.
  bool get rotated => transform.isOdd;

  /// The same monitor moved to ([x], [y]).
  LogicalMonitor movedTo(int x, int y) => LogicalMonitor(
    x: x,
    y: y,
    scale: scale,
    transform: transform,
    primary: primary,
    connectors: connectors,
  );

  @override
  bool operator ==(Object other) =>
      other is LogicalMonitor &&
      other.x == x &&
      other.y == y &&
      (other.scale - scale).abs() < 0.01 &&
      other.transform == transform &&
      other.primary == primary &&
      listEquals(other.connectors, connectors);

  @override
  int get hashCode => Object.hash(x, y, transform, primary, Object.hashAll(connectors));

  @override
  String toString() =>
      '${connectors.join('+')}@$x,$y x$scale t$transform${primary ? ' primary' : ''}';
}

/// The desktop's monitors and how they are arranged.
@immutable
class MonitorLayout {
  /// Creates a layout.
  const MonitorLayout({
    required this.serial,
    required this.monitors,
    required this.logical,
    required this.logicalLayout,
  });

  /// Changes with every reconfiguration; needed to apply a new one.
  final int serial;
  final List<MonitorState> monitors;
  final List<LogicalMonitor> logical;

  /// True when positions are in scaled ("logical") pixels, false when they
  /// are in physical pixels.
  final bool logicalLayout;

  /// The monitor on [connector], if connected.
  MonitorState? monitor(String connector) {
    for (final m in monitors) {
      if (m.connector == connector) return m;
    }
    return null;
  }

  /// The logical monitor showing [connector], if it is on.
  LogicalMonitor? logicalFor(String connector) {
    for (final l in logical) {
      if (l.connectors.contains(connector)) return l;
    }
    return null;
  }

  /// Desktop rectangle covered by [l].
  math.Rectangle<int> rectOf(LogicalMonitor l) {
    final m = monitor(l.connectors.first);
    var w = m?.width ?? 0;
    var h = m?.height ?? 0;
    if (l.rotated) (w, h) = (h, w);
    if (logicalLayout) {
      w = (w / l.scale).round();
      h = (h / l.scale).round();
    }
    return math.Rectangle(l.x, l.y, w, h);
  }
}

/// Where a virtual monitor sits, relative to the primary monitor's corner.
@immutable
class VirtualPlacement {
  /// Creates a placement.
  const VirtualPlacement({required this.dx, required this.dy, required this.scale});

  final int dx;
  final int dy;
  final double scale;

  /// Parses [encode]'s output; null for anything else.
  static VirtualPlacement? tryParse(String? text) {
    final parts = text?.split(',');
    if (parts == null || parts.length != 3) return null;
    final dx = int.tryParse(parts[0]);
    final dy = int.tryParse(parts[1]);
    final scale = double.tryParse(parts[2]);
    if (dx == null || dy == null || scale == null || scale <= 0) return null;
    return VirtualPlacement(dx: dx, dy: dy, scale: scale);
  }

  /// `dx,dy,scale`.
  String encode() => '$dx,$dy,$scale';

  @override
  bool operator ==(Object other) =>
      other is VirtualPlacement &&
      other.dx == dx &&
      other.dy == dy &&
      (other.scale - scale).abs() < 0.01;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => encode();
}

bool _overlaps(math.Rectangle<int> a, math.Rectangle<int> b) =>
    a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;

/// Whether [a] and [b] share part of an edge, which is what the compositor
/// requires of every monitor with at least one other.
bool _adjacent(math.Rectangle<int> a, math.Rectangle<int> b) {
  final sideBySide = a.right == b.left || b.right == a.left;
  final stacked = a.bottom == b.top || b.bottom == a.top;
  return (sideBySide && a.top < b.bottom && b.top < a.bottom) ||
      (stacked && a.left < b.right && b.left < a.right);
}

/// Moves [monitors] so the top-left corner of their bounding box is (0, 0),
/// as the compositor requires.
List<LogicalMonitor> normalized(List<LogicalMonitor> monitors) {
  if (monitors.isEmpty) return monitors;
  final minX = monitors.map((m) => m.x).reduce(math.min);
  final minY = monitors.map((m) => m.y).reduce(math.min);
  if (minX == 0 && minY == 0) return monitors;
  return [for (final m in monitors) m.movedTo(m.x - minX, m.y - minY)];
}

/// The arrangement to apply once a virtual monitor has appeared: every
/// monitor of [before] exactly where it was, and the virtual monitor on
/// [virtualConnector] at [placement], or to the right of everything when
/// there is none or it no longer fits.
///
/// Returns null when [now] cannot be reconciled with [before] (a monitor was
/// unplugged in between), in which case the compositor's own arrangement is
/// left alone.
List<LogicalMonitor>? planWithVirtual({
  required MonitorLayout before,
  required MonitorLayout now,
  required String virtualConnector,
  VirtualPlacement? placement,
}) {
  final virtual = now.monitor(virtualConnector);
  if (virtual == null || before.logical.isEmpty) return null;
  for (final l in before.logical) {
    if (l.connectors.any((c) => now.monitor(c) == null)) return null;
  }

  final scales = virtual.supportedScales;
  double pickScale(double wanted) => scales.isEmpty
      ? wanted
      : scales.reduce((a, b) => (a - wanted).abs() <= (b - wanted).abs() ? a : b);
  final scale = pickScale(placement?.scale ?? 1);
  final divisor = now.logicalLayout ? scale : 1.0;
  final width = (virtual.width / divisor).round();
  final height = (virtual.height / divisor).round();

  final rects = [for (final l in before.logical) before.rectOf(l)];
  bool fits(math.Rectangle<int> r) =>
      rects.every((p) => !_overlaps(p, r)) && rects.any((p) => _adjacent(p, r));

  final anchor = before.logical.firstWhere((l) => l.primary, orElse: () => before.logical.first);
  math.Rectangle<int>? spot;
  if (placement != null) {
    final wanted = math.Rectangle(anchor.x + placement.dx, anchor.y + placement.dy, width, height);
    if (fits(wanted)) spot = wanted;
  }
  if (spot == null) {
    // Right of the monitor that reaches furthest right, tops aligned.
    final edge = rects.reduce((a, b) => a.right >= b.right ? a : b);
    spot = math.Rectangle(edge.right, edge.top, width, height);
  }

  return normalized([
    ...before.logical,
    LogicalMonitor(
      x: spot.left,
      y: spot.top,
      scale: scale,
      transform: 0,
      primary: false,
      connectors: [virtualConnector],
    ),
  ]);
}

/// Where the virtual monitor on [virtualConnector] currently sits in
/// [layout], to be remembered for next time.
VirtualPlacement? placementOf(MonitorLayout layout, String virtualConnector) {
  final virtual = layout.logicalFor(virtualConnector);
  if (virtual == null) return null;
  final others = layout.logical.where((l) => l != virtual).toList();
  if (others.isEmpty) return null;
  final anchor = others.firstWhere((l) => l.primary, orElse: () => others.first);
  return VirtualPlacement(dx: virtual.x - anchor.x, dy: virtual.y - anchor.y, scale: virtual.scale);
}

/// The arrangement of [layout] without the monitor on [connector].
List<LogicalMonitor> withoutMonitor(MonitorLayout layout, String connector) => normalized([
  for (final l in layout.logical)
    if (!l.connectors.contains(connector)) l,
]);

/// Whether [current] already arranges its monitors as [wanted].
bool sameArrangement(List<LogicalMonitor> current, List<LogicalMonitor> wanted) =>
    current.length == wanted.length && wanted.every(current.contains);
