import 'package:dbus/dbus.dart';

import 'monitor_layout.dart';

/// Reads and changes GNOME's monitor arrangement through
/// `org.gnome.Mutter.DisplayConfig`.
class MutterDisplayConfig {
  /// Uses [client] (the session bus), which the caller keeps open.
  MutterDisplayConfig(DBusClient client)
    : _object = DBusRemoteObject(client, name: _name, path: DBusObjectPath(_path));

  static const _name = 'org.gnome.Mutter.DisplayConfig';
  static const _path = '/org/gnome/Mutter/DisplayConfig';
  static const _timeout = Duration(seconds: 5);

  /// `ApplyMonitorsConfig` method: apply now, do not write `monitors.xml`.
  static const _temporary = 1;

  /// `layout-mode` value for positions in scaled pixels.
  static const _logicalMode = 1;

  final DBusRemoteObject _object;

  /// The current monitors and their arrangement.
  Future<MonitorLayout> current() async {
    final reply = await _object.callMethod(_name, 'GetCurrentState', []).timeout(_timeout);
    final values = reply.returnValues;
    final monitors = <MonitorState>[];
    for (final raw in values[1].asArray()) {
      final fields = raw.asStruct();
      final id = fields[0].asStruct();
      final properties = fields[2].asStringVariantDict();
      String? modeId;
      var width = 0;
      var height = 0;
      var scales = const <double>[];
      for (final rawMode in fields[1].asArray()) {
        final mode = rawMode.asStruct();
        final modeProperties = mode[6].asStringVariantDict();
        if (modeProperties['is-current']?.asBoolean() ?? false) {
          modeId = mode[0].asString();
          width = mode[1].asInt32();
          height = mode[2].asInt32();
          scales = [for (final s in mode[5].asArray()) s.asDouble()];
        }
      }
      final connector = id[0].asString();
      monitors.add(
        MonitorState(
          connector: connector,
          vendor: id[1].asString(),
          product: id[2].asString(),
          serial: id[3].asString(),
          displayName: properties['display-name']?.asString() ?? connector,
          modeId: modeId,
          width: width,
          height: height,
          supportedScales: scales,
        ),
      );
    }
    final logical = <LogicalMonitor>[
      for (final raw in values[2].asArray().map((l) => l.asStruct()))
        LogicalMonitor(
          x: raw[0].asInt32(),
          y: raw[1].asInt32(),
          scale: raw[2].asDouble(),
          transform: raw[3].asUint32(),
          primary: raw[4].asBoolean(),
          connectors: [for (final m in raw[5].asArray()) m.asStruct()[0].asString()],
        ),
    ];
    final properties = values[3].asStringVariantDict();
    return MonitorLayout(
      serial: values[0].asUint32(),
      monitors: monitors,
      logical: logical,
      // Without the property the compositor works in physical pixels.
      logicalLayout: properties['layout-mode']?.asUint32() == _logicalMode,
    );
  }

  /// Arranges the monitors of [layout] as [logical], for this session only:
  /// the user's saved configuration is not overwritten.
  ///
  /// Throws if the compositor rejects the arrangement.
  Future<void> apply(MonitorLayout layout, List<LogicalMonitor> logical) async {
    final entries = <DBusValue>[];
    for (final l in logical) {
      final monitors = <DBusValue>[];
      for (final connector in l.connectors) {
        final modeId = layout.monitor(connector)?.modeId;
        if (modeId == null) throw StateError('$connector has no active mode');
        monitors.add(
          DBusStruct([DBusString(connector), DBusString(modeId), DBusDict.stringVariant(const {})]),
        );
      }
      entries.add(
        DBusStruct([
          DBusInt32(l.x),
          DBusInt32(l.y),
          DBusDouble(l.scale),
          DBusUint32(l.transform),
          DBusBoolean(l.primary),
          DBusArray(DBusSignature('(ssa{sv})'), monitors),
        ]),
      );
    }
    await _object
        .callMethod(_name, 'ApplyMonitorsConfig', [
          DBusUint32(layout.serial),
          const DBusUint32(_temporary),
          DBusArray(DBusSignature('(iiduba(ssa{sv}))'), entries),
          DBusDict.stringVariant({
            'layout-mode': DBusUint32(layout.logicalLayout ? _logicalMode : 2),
          }),
        ], replySignature: DBusSignature(''))
        .timeout(_timeout);
  }
}
