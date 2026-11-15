import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/captured_screen.dart';
import 'linux/monitor_layout.dart';

/// Pixel size of a screen, as exchanged between host and display.
class ScreenSize {
  /// Creates a size; both edges are in physical pixels.
  const ScreenSize(this.width, this.height);

  /// Used when the display never reports its own size.
  static const fallback = ScreenSize(1920, 1080);

  /// Largest virtual monitor edge the host will create.
  static const maxEdge = 3840;

  final int width;
  final int height;

  /// Physical size of the screen the app is shown on, if known.
  static ScreenSize? ofPrimaryDisplay() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return null;
    final size = views.first.display.size;
    if (size.width < 1 || size.height < 1) return null;
    return ScreenSize(size.width.round(), size.height.round());
  }

  /// Parses `WIDTHxHEIGHT`; returns null for anything else.
  static ScreenSize? tryParse(String? text) {
    final parts = text?.split('x');
    if (parts == null || parts.length != 2) return null;
    final w = int.tryParse(parts[0]);
    final h = int.tryParse(parts[1]);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return ScreenSize(w, h);
  }

  /// Landscape, even-edged and no larger than [maxEdge]: what video encoders
  /// and compositors accept everywhere.
  ScreenSize normalized() {
    var w = width > height ? width : height;
    var h = width > height ? height : width;
    if (w > maxEdge) {
      h = (h * maxEdge / w).round();
      w = maxEdge;
    }
    return ScreenSize(w - w % 2, h - h % 2);
  }

  /// `WIDTHxHEIGHT`.
  String encode() => '${width}x$height';

  @override
  bool operator ==(Object other) =>
      other is ScreenSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => encode();
}

/// An extra monitor that exists only while a session runs.
abstract class VirtualDisplay {
  /// Name the desktop shows for the monitor, when known.
  String? get label;

  /// The monitor's own picture, when the platform can read it directly.
  /// Null means it has to be captured like any other screen, which may ask
  /// the user to pick it.
  CapturedScreen? get capture;

  /// Removes the monitor. Safe to call more than once.
  Future<void> dispose();
}

/// Creates [VirtualDisplay]s on the host so a remote device can act as a real
/// additional monitor ("extend" mode). Every OS needs its own mechanism; see
/// docs/PLAN.md for the per-platform plan.
abstract class VirtualDisplayProvider {
  /// Whether this machine can create virtual monitors right now.
  Future<bool> isSupported();

  /// Adds a monitor of [size] at [refreshRate] Hz.
  ///
  /// [placementKey] identifies whose monitor this is (the display device),
  /// so it reappears where the user last put it.
  ///
  /// Throws if the monitor cannot be created.
  Future<VirtualDisplay> create({
    required ScreenSize size,
    required int refreshRate,
    String? placementKey,
  });
}

/// Remembers where each device's virtual monitor sits on the desktop.
abstract interface class VirtualPlacementStore {
  /// The placement saved for [key], if any.
  VirtualPlacement? read(String key);

  /// Saves [placement] for [key].
  void write(String key, VirtualPlacement placement);
}

/// Keeps placements in memory only.
class InMemoryPlacementStore implements VirtualPlacementStore {
  final _placements = <String, VirtualPlacement>{};

  @override
  VirtualPlacement? read(String key) => _placements[key];

  @override
  void write(String key, VirtualPlacement placement) => _placements[key] = placement;
}

/// Platforms without a virtual-monitor mechanism yet: extend falls back to
/// mirroring.
class UnsupportedVirtualDisplayProvider implements VirtualDisplayProvider {
  /// Creates the provider.
  const UnsupportedVirtualDisplayProvider();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<VirtualDisplay> create({
    required ScreenSize size,
    required int refreshRate,
    String? placementKey,
  }) => throw UnsupportedError('virtual displays are not supported on this platform');
}

/// In-memory provider for tests and the demo mode.
class FakeVirtualDisplayProvider implements VirtualDisplayProvider {
  /// Creates the provider; [failing] makes [create] throw.
  FakeVirtualDisplayProvider({this.failing = false});

  final bool failing;

  /// Sizes requested so far.
  final created = <ScreenSize>[];

  /// Placement keys requested so far.
  final placementKeys = <String?>[];

  /// Number of displays currently alive.
  int alive = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<VirtualDisplay> create({
    required ScreenSize size,
    required int refreshRate,
    String? placementKey,
  }) async {
    if (failing) throw StateError('simulated failure');
    created.add(size);
    placementKeys.add(placementKey);
    alive++;
    return _FakeVirtualDisplay(this);
  }
}

class _FakeVirtualDisplay implements VirtualDisplay {
  _FakeVirtualDisplay(this._owner);

  final FakeVirtualDisplayProvider _owner;
  bool _disposed = false;

  @override
  String? get label => 'Fake-0';

  @override
  CapturedScreen? get capture => null;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _owner.alive--;
  }
}

/// The platform's virtual-display mechanism; overridden at startup.
final virtualDisplayProvider = Provider<VirtualDisplayProvider>(
  (ref) => const UnsupportedVirtualDisplayProvider(),
);

/// Whether "extend" really adds a monitor on this machine.
final extendSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(virtualDisplayProvider).isSupported(),
);
