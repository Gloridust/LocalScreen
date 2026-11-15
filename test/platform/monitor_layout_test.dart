import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/platform/linux/monitor_layout.dart';

MonitorState _monitor(String connector, int width, int height, {List<double>? scales}) =>
    MonitorState(
      connector: connector,
      vendor: connector.startsWith('Meta') ? 'MetaVendor' : 'XMI',
      product: connector,
      serial: '1',
      displayName: connector,
      modeId: '$width x $height',
      width: width,
      height: height,
      supportedScales: scales ?? const [1, 1.25, 1.5, 2],
    );

LogicalMonitor _logical(
  String connector,
  int x,
  int y, {
  double scale = 1,
  int transform = 0,
  bool primary = false,
}) => LogicalMonitor(
  x: x,
  y: y,
  scale: scale,
  transform: transform,
  primary: primary,
  connectors: [connector],
);

/// A 4K monitor rotated to portrait at 125 % next to a 1080p primary.
final _portrait = _logical('DP-1', 0, 0, scale: 1.25, transform: 3);
final _primary = _logical('HDMI-1', 1728, 1328, primary: true);
final _physical = [_monitor('DP-1', 3840, 2160), _monitor('HDMI-1', 1920, 1080)];

final _before = MonitorLayout(
  serial: 1,
  monitors: _physical,
  logical: [_portrait, _primary],
  logicalLayout: true,
);

/// What the compositor makes of it once the virtual monitor shows up: a
/// fresh left-to-right row, rotation and scale gone.
MonitorLayout _scrambled({int width = 1920, int height = 1080}) => MonitorLayout(
  serial: 2,
  monitors: [..._physical, _monitor('Meta-0', width, height)],
  logical: [
    _logical('HDMI-1', 0, 0, primary: true),
    _logical('DP-1', 1920, 0),
    _logical('Meta-0', 5760, 0),
  ],
  logicalLayout: true,
);

void main() {
  test('rotation and scale decide the desktop rectangle', () {
    final rect = _before.rectOf(_portrait);
    expect((rect.width, rect.height), (1728, 3072));
  });

  test('keeps every monitor in place and adds the new one on the right', () {
    final plan = planWithVirtual(before: _before, now: _scrambled(), virtualConnector: 'Meta-0')!;
    expect(plan.sublist(0, 2), [_portrait, _primary]);
    expect(plan.last, _logical('Meta-0', 3648, 1328));
  });

  test('puts the monitor back where the user left it', () {
    const below = VirtualPlacement(dx: 0, dy: 1080, scale: 1);
    final plan = planWithVirtual(
      before: _before,
      now: _scrambled(),
      virtualConnector: 'Meta-0',
      placement: below,
    )!;
    expect(plan.last, _logical('Meta-0', 1728, 2408));
  });

  test('a remembered scale is kept and shrinks the rectangle', () {
    const scaled = VirtualPlacement(dx: 1920, dy: 0, scale: 2);
    final plan = planWithVirtual(
      before: _before,
      now: _scrambled(width: 2560, height: 1600),
      virtualConnector: 'Meta-0',
      placement: scaled,
    )!;
    expect(plan.last, _logical('Meta-0', 3648, 1328, scale: 2));
  });

  test('a placement left of everything shifts the desktop origin', () {
    const left = VirtualPlacement(dx: -3648, dy: -1328, scale: 1);
    final plan = planWithVirtual(
      before: _before,
      now: _scrambled(),
      virtualConnector: 'Meta-0',
      placement: left,
    )!;
    expect(plan.last, _logical('Meta-0', 0, 0));
    expect(plan.first, _portrait.movedTo(1920, 0));
    expect(plan[1], _primary.movedTo(3648, 1328));
  });

  test('a placement that overlaps or floats falls back to the right edge', () {
    for (final bad in const [
      VirtualPlacement(dx: 100, dy: 100, scale: 1), // on top of the primary
      VirtualPlacement(dx: 4000, dy: 0, scale: 1), // touching nothing
    ]) {
      final plan = planWithVirtual(
        before: _before,
        now: _scrambled(),
        virtualConnector: 'Meta-0',
        placement: bad,
      )!;
      expect(plan.last, _logical('Meta-0', 3648, 1328), reason: '$bad');
    }
  });

  test('gives up when a monitor was unplugged meanwhile', () {
    final now = MonitorLayout(
      serial: 2,
      monitors: [_physical[1], _monitor('Meta-0', 1920, 1080)],
      logical: [_logical('HDMI-1', 0, 0, primary: true), _logical('Meta-0', 1920, 0)],
      logicalLayout: true,
    );
    expect(planWithVirtual(before: _before, now: now, virtualConnector: 'Meta-0'), isNull);
  });

  test('reads the placement back relative to the primary monitor', () {
    final layout = MonitorLayout(
      serial: 3,
      monitors: [..._physical, _monitor('Meta-0', 1920, 1080)],
      logical: [_portrait, _primary, _logical('Meta-0', 1728, 2408)],
      logicalLayout: true,
    );
    const below = VirtualPlacement(dx: 0, dy: 1080, scale: 1);
    expect(placementOf(layout, 'Meta-0'), below);
    expect(VirtualPlacement.tryParse(below.encode()), below);
    expect(VirtualPlacement.tryParse('nonsense'), isNull);
    expect(withoutMonitor(layout, 'Meta-0'), [_portrait, _primary]);
  });

  test('physical-pixel layouts ignore the scale for geometry', () {
    final before = MonitorLayout(
      serial: 1,
      monitors: _physical,
      logical: [_logical('HDMI-1', 0, 0, scale: 2, primary: true)],
      logicalLayout: false,
    );
    final now = MonitorLayout(
      serial: 2,
      monitors: [..._physical, _monitor('Meta-0', 1920, 1080)],
      logical: const [],
      logicalLayout: false,
    );
    final plan = planWithVirtual(before: before, now: now, virtualConnector: 'Meta-0')!;
    expect(plan.last, _logical('Meta-0', 1920, 0));
  });
}
