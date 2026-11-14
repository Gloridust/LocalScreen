@TestOn('linux')
library;

import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/platform/mutter_virtual_display.dart';
import 'package:localscreen/core/platform/virtual_display.dart';

/// Talks to the real GNOME session and briefly adds a monitor to the desktop,
/// so it only runs on request:
///
///     LS_REAL_MUTTER=1 flutter test test/platform/mutter_virtual_display_test.dart
void main() {
  final enabled = Platform.environment['LS_REAL_MUTTER'] == '1';

  /// Connector name → `WIDTHxHEIGHT` of each mode the monitor offers.
  Future<Map<String, List<String>>> monitorModes() async {
    final client = DBusClient.session();
    const name = 'org.gnome.Mutter.DisplayConfig';
    final object = DBusRemoteObject(
      client,
      name: name,
      path: DBusObjectPath('/org/gnome/Mutter/DisplayConfig'),
    );
    final state = await object.callMethod(name, 'GetCurrentState', []);
    await client.close();
    return {
      for (final m in state.returnValues[1].asArray())
        m.asStruct()[0].asStruct()[0].asString(): [
          for (final mode in m.asStruct()[1].asArray())
            '${mode.asStruct()[1].asInt32()}x${mode.asStruct()[2].asInt32()}',
        ],
    };
  }

  Future<List<String>> monitors() async {
    final client = DBusClient.session();
    const name = 'org.gnome.Mutter.DisplayConfig';
    final object = DBusRemoteObject(
      client,
      name: name,
      path: DBusObjectPath('/org/gnome/Mutter/DisplayConfig'),
    );
    final state = await object.callMethod(name, 'GetCurrentState', []);
    await client.close();
    return [
      for (final m in state.returnValues[1].asArray()) m.asStruct()[0].asStruct()[0].asString(),
    ];
  }

  test('adds a monitor of the requested size and removes it again', () async {
    final provider = MutterVirtualDisplayProvider();
    expect(await provider.isSupported(), isTrue);

    final before = await monitors();
    final display = await provider.create(size: const ScreenSize(2560, 1600), refreshRate: 60);
    final during = await monitors();
    expect(during.length, before.length + 1);
    expect(during, contains(display.label));
    expect((await monitorModes())[display.label], contains('2560x1600'));

    await display.dispose();
    await display.dispose(); // idempotent
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(await monitors(), before);
  }, skip: enabled ? false : 'set LS_REAL_MUTTER=1 to run against the real desktop');
}
