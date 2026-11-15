import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// One `org.gnome.Mutter.ScreenCast` session with a single stream, which
/// Mutter exposes as a PipeWire node this process may read.
///
/// This is the API GNOME's own screen sharing is built on. Using it directly
/// (instead of the desktop portal) means there is no system picker dialog to
/// find and answer before the picture starts.
class MutterScreenCast {
  MutterScreenCast._(this._session, this.node);

  static const _busName = 'org.gnome.Mutter.ScreenCast';
  static const _sessionInterface = 'org.gnome.Mutter.ScreenCast.Session';
  static const _timeout = Duration(seconds: 5);

  /// `cursor-mode`: the pointer is drawn into the frames.
  static const _cursorEmbedded = 1;

  final DBusRemoteObject _session;

  /// PipeWire node id of the stream.
  final int node;
  bool _stopped = false;

  /// Whether Mutter's screen-cast service is on the session bus.
  static Future<bool> available(DBusClient client) async {
    try {
      return await client.nameHasOwner(_busName).timeout(_timeout);
    } catch (e) {
      debugPrint('screen cast: probing failed: $e');
      return false;
    }
  }

  /// A new monitor that exists while the session runs. Its size comes from
  /// the first consumer of [node].
  static Future<MutterScreenCast> virtualMonitor(DBusClient client) =>
      _start(client, 'RecordVirtual', [
        DBusDict.stringVariant({
          'cursor-mode': const DBusUint32(_cursorEmbedded),
          // A real monitor: windows can be placed on it.
          'is-platform': const DBusBoolean(true),
        }),
      ]);

  /// The picture of the existing monitor on [connector].
  static Future<MutterScreenCast> monitor(DBusClient client, String connector) =>
      _start(client, 'RecordMonitor', [
        DBusString(connector),
        DBusDict.stringVariant({'cursor-mode': const DBusUint32(_cursorEmbedded)}),
      ]);

  static Future<MutterScreenCast> _start(
    DBusClient client,
    String method,
    List<DBusValue> arguments,
  ) async {
    final root = DBusRemoteObject(
      client,
      name: _busName,
      path: DBusObjectPath('/org/gnome/Mutter/ScreenCast'),
    );
    final created = await root
        .callMethod(_busName, 'CreateSession', [
          DBusDict.stringVariant(const {}),
        ], replySignature: DBusSignature('o'))
        .timeout(_timeout);
    final session = DBusRemoteObject(
      client,
      name: _busName,
      path: created.returnValues[0].asObjectPath(),
    );
    try {
      final recorded = await session
          .callMethod(_sessionInterface, method, arguments, replySignature: DBusSignature('o'))
          .timeout(_timeout);
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
      await session
          .callMethod(_sessionInterface, 'Start', [], replySignature: DBusSignature(''))
          .timeout(_timeout);
      final node = (await nodeAdded.timeout(_timeout)).values[0].asUint32();
      return MutterScreenCast._(session, node);
    } catch (_) {
      await _stopSession(session);
      rethrow;
    }
  }

  /// Ends the session; a virtual monitor disappears. Safe to call twice.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await _stopSession(_session);
  }

  static Future<void> _stopSession(DBusRemoteObject session) async {
    try {
      await session
          .callMethod(_sessionInterface, 'Stop', [], replySignature: DBusSignature(''))
          .timeout(_timeout);
    } catch (e) {
      // Already gone when its consumer went away first.
      debugPrint('screen cast: stopping the session: $e');
    }
  }
}
