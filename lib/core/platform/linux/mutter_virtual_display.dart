import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import '../../media/captured_screen.dart';
import '../virtual_display.dart';
import 'monitor_layout.dart';
import 'mutter_display_config.dart';
import 'mutter_screen_cast.dart';
import 'pipewire_capture.dart';

/// Virtual monitors on GNOME (Wayland) through Mutter's ScreenCast API.
///
/// `RecordVirtual` makes Mutter create a monitor whose size comes from the
/// PipeWire format its consumer negotiates, and which lives as long as the
/// session. The consumer is the capture itself: the monitor's own stream is
/// what the display receives, so no screen has to be picked.
///
/// Adding a monitor makes Mutter rearrange the desktop from scratch, because
/// it has never seen this exact set of monitors (every virtual monitor gets
/// a new serial). The provider therefore records the arrangement first and
/// reapplies it with the new monitor added: at the place the user last moved
/// it to for this [placementKey], or to the right of everything.
///
/// Needs GNOME 42+ and the GStreamer PipeWire plugin, both part of a default
/// GNOME desktop.
class MutterVirtualDisplayProvider implements VirtualDisplayProvider {
  /// Creates the provider; [placements] remembers where each device's
  /// monitor was put.
  MutterVirtualDisplayProvider({required this.placements});

  final VirtualPlacementStore placements;

  static const _timeout = Duration(seconds: 5);

  Future<bool>? _supported;

  @override
  Future<bool> isSupported() => _supported ??= _probe();

  Future<bool> _probe() async {
    if (!Platform.isLinux) return false;
    final client = DBusClient.session();
    try {
      return await MutterScreenCast.available(client) && await PipeWireCapture.supported();
    } finally {
      await client.close();
    }
  }

  @override
  Future<VirtualDisplay> create({
    required ScreenSize size,
    required int refreshRate,
    String? placementKey,
  }) async {
    final client = DBusClient.session();
    MutterScreenCast? cast;
    CapturedScreen? capture;
    try {
      final config = MutterDisplayConfig(client);
      final before = await config.current();
      cast = await MutterScreenCast.virtualMonitor(client);
      // Reading the stream at `size` is what creates the monitor.
      capture = await PipeWireCapture.start(node: cast.node, frameRate: refreshRate, size: size);
      final connector = await _waitForNewMonitor(config, before);
      final saved = placementKey == null ? null : placements.read(placementKey);
      await _arrange(config, before, connector, saved);
      return _MutterVirtualDisplay(
        client: client,
        config: config,
        cast: cast,
        capture: capture,
        connector: connector,
        before: before,
        remember: placementKey == null ? null : (p) => placements.write(placementKey, p),
      );
    } catch (_) {
      await capture?.close();
      await cast?.stop();
      await client.close();
      rethrow;
    }
  }

  /// Polls until Mutter lists a monitor that was not in [before].
  static Future<String> _waitForNewMonitor(MutterDisplayConfig config, MonitorLayout before) async {
    final known = {for (final m in before.monitors) m.connector};
    final deadline = DateTime.now().add(_timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final m in (await config.current()).monitors) {
        if (!known.contains(m.connector)) return m.connector;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException('the virtual monitor did not appear');
  }

  /// Puts every monitor back where it was and the new one at [saved].
  static Future<void> _arrange(
    MutterDisplayConfig config,
    MonitorLayout before,
    String connector,
    VirtualPlacement? saved,
  ) async {
    // Without the remembered spot on the second pass, in case it is what the
    // compositor objects to.
    for (final placement in {saved, null}) {
      try {
        final now = await config.current();
        final plan = planWithVirtual(
          before: before,
          now: now,
          virtualConnector: connector,
          placement: placement,
        );
        if (plan == null) return;
        if (!sameArrangement(now.logical, plan)) await config.apply(now, plan);
        debugPrint('virtual display: arranged as $plan');
        return;
      } catch (e) {
        debugPrint('virtual display: arranging failed (placement $placement): $e');
      }
    }
  }
}

class _MutterVirtualDisplay implements VirtualDisplay {
  _MutterVirtualDisplay({
    required this.client,
    required this.config,
    required this.cast,
    required this.capture,
    required this.connector,
    required this.before,
    required this.remember,
  });

  final DBusClient client;
  final MutterDisplayConfig config;
  final MutterScreenCast cast;
  final String connector;

  /// The arrangement before the monitor was added.
  final MonitorLayout before;
  final void Function(VirtualPlacement placement)? remember;
  bool _disposed = false;

  @override
  final CapturedScreen capture;

  @override
  String get label => connector;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // What the user has now, minus this monitor: restored below, because
    // Mutter otherwise falls back to whatever it last saved for the
    // remaining monitors, which may be an older arrangement.
    List<LogicalMonitor>? remaining;
    try {
      final layout = await config.current();
      final placement = placementOf(layout, connector);
      if (placement != null) remember?.call(placement);
      remaining = withoutMonitor(layout, connector);
    } catch (e) {
      debugPrint('virtual display: reading the layout failed: $e');
    }
    await capture.close();
    await cast.stop();
    try {
      await _restore(remaining);
    } catch (e) {
      debugPrint('virtual display: restoring the layout failed: $e');
    }
    await client.close();
  }

  Future<void> _restore(List<LogicalMonitor>? remaining) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    var now = await config.current();
    while (now.monitor(connector) != null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      now = await config.current();
    }
    for (final wanted in [?remaining, before.logical]) {
      if (wanted.isEmpty || wanted.any((l) => l.connectors.any((c) => now.monitor(c) == null))) {
        continue;
      }
      if (sameArrangement(now.logical, wanted)) return;
      try {
        await config.apply(now, wanted);
        debugPrint('virtual display: restored $wanted');
        return;
      } catch (e) {
        debugPrint('virtual display: could not restore $wanted: $e');
        now = await config.current();
      }
    }
  }
}
