import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

import 'virtual_display.dart';

/// Virtual monitors on GNOME (Wayland) through Mutter's ScreenCast API.
///
/// `RecordVirtual` makes Mutter create a monitor whose size comes from the
/// PipeWire format its consumer negotiates, and which lives exactly as long
/// as that consumer stays connected. A minimal GStreamer pipeline
/// (`pipewiresrc ! fakesink`) is that consumer: it fixes the size and keeps
/// the monitor alive. The picture itself is captured separately, like any
/// other monitor, through the screen-cast portal.
///
/// Needs GNOME 42+ and the GStreamer PipeWire plugin, both part of a default
/// GNOME desktop.
class MutterVirtualDisplayProvider implements VirtualDisplayProvider {
  static const _busName = 'org.gnome.Mutter.ScreenCast';
  static const _sessionInterface = 'org.gnome.Mutter.ScreenCast.Session';
  static const _gstLaunch = 'gst-launch-1.0';

  /// Mutter's `cursor-mode` for "do not draw the pointer into this stream".
  static const _cursorHidden = 0;

  static const _timeout = Duration(seconds: 5);

  Future<bool>? _supported;

  @override
  Future<bool> isSupported() => _supported ??= _probe();

  Future<bool> _probe() async {
    if (!Platform.isLinux) return false;
    final client = DBusClient.session();
    try {
      if (!await client.nameHasOwner(_busName).timeout(_timeout)) return false;
      final plugin = await Process.run('gst-inspect-1.0', ['--exists', 'pipewiresrc']);
      return plugin.exitCode == 0;
    } catch (e) {
      debugPrint('virtual display probe failed: $e');
      return false;
    } finally {
      await client.close();
    }
  }

  @override
  Future<VirtualDisplay> create({required ScreenSize size, required int refreshRate}) async {
    final client = DBusClient.session();
    DBusRemoteObject? session;
    Process? consumer;
    try {
      final before = await _monitorConnectors(client);
      final root = DBusRemoteObject(
        client,
        name: _busName,
        path: DBusObjectPath('/org/gnome/Mutter/ScreenCast'),
      );
      final created = await root.callMethod(_busName, 'CreateSession', [
        DBusDict.stringVariant(const {}),
      ], replySignature: DBusSignature('o'));
      session = DBusRemoteObject(
        client,
        name: _busName,
        path: created.returnValues[0].asObjectPath(),
      );

      final recorded = await session.callMethod(_sessionInterface, 'RecordVirtual', [
        DBusDict.stringVariant({
          'cursor-mode': const DBusUint32(_cursorHidden),
          'is-platform': const DBusBoolean(true),
        }),
      ], replySignature: DBusSignature('o'));
      final stream = DBusRemoteObject(
        client,
        name: _busName,
        path: recorded.returnValues[0].asObjectPath(),
      );
      // Subscribe before `Start`, which is what triggers the signal.
      final nodeAdded = DBusRemoteObjectSignalStream(
        object: stream,
        interface: 'org.gnome.Mutter.ScreenCast.Stream',
        name: 'PipeWireStreamAdded',
        signature: DBusSignature('u'),
      ).first;
      await session.callMethod(_sessionInterface, 'Start', [], replySignature: DBusSignature(''));
      final nodeId = (await nodeAdded.timeout(_timeout)).values[0].asUint32();

      consumer = await Process.start(_gstLaunch, [
        '--quiet',
        'pipewiresrc',
        'path=$nodeId',
        '!',
        'video/x-raw,width=${size.width},height=${size.height},max-framerate=$refreshRate/1',
        '!',
        'fakesink',
        'sync=false',
      ]);
      unawaited(consumer.stdout.drain<void>());
      unawaited(consumer.stderr.drain<void>());

      final label = await _waitForNewMonitor(client, before);
      return _MutterVirtualDisplay(client, session, consumer, label);
    } catch (_) {
      consumer?.kill();
      await _stop(session);
      await client.close();
      rethrow;
    }
  }

  /// Polls until Mutter lists a monitor that was not in [before].
  static Future<String> _waitForNewMonitor(DBusClient client, Set<String> before) async {
    final deadline = DateTime.now().add(_timeout);
    while (DateTime.now().isBefore(deadline)) {
      final added = (await _monitorConnectors(client)).difference(before);
      if (added.isNotEmpty) return added.first;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    throw TimeoutException('the virtual monitor did not appear');
  }

  /// Connector names (`HDMI-1`, `Meta-0`, …) of the current monitors.
  static Future<Set<String>> _monitorConnectors(DBusClient client) async {
    const displayConfig = 'org.gnome.Mutter.DisplayConfig';
    final object = DBusRemoteObject(
      client,
      name: displayConfig,
      path: DBusObjectPath('/org/gnome/Mutter/DisplayConfig'),
    );
    final state = await object.callMethod(displayConfig, 'GetCurrentState', []).timeout(_timeout);
    // (serial, monitors: a((connector, vendor, product, serial), modes, props), …)
    return {
      for (final monitor in state.returnValues[1].asArray())
        monitor.asStruct()[0].asStruct()[0].asString(),
    };
  }

  static Future<void> _stop(DBusRemoteObject? session) async {
    if (session == null) return;
    try {
      await session
          .callMethod(_sessionInterface, 'Stop', [], replySignature: DBusSignature(''))
          .timeout(_timeout);
    } catch (e) {
      // The session is already gone if the consumer exited first.
      debugPrint('stopping the virtual display session: $e');
    }
  }
}

class _MutterVirtualDisplay implements VirtualDisplay {
  _MutterVirtualDisplay(this._client, this._session, this._consumer, this.label);

  final DBusClient _client;
  final DBusRemoteObject _session;
  final Process _consumer;
  bool _disposed = false;

  @override
  final String label;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await MutterVirtualDisplayProvider._stop(_session);
    _consumer.kill();
    await _client.close();
  }
}
