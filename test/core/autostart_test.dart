import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/platform/autostart.dart';
import 'package:localscreen/core/prefs/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DesktopAutostartService on Linux', () {
    late Directory config;
    setUp(() => config = Directory.systemTemp.createTempSync('ls-autostart-'));
    tearDown(() => config.deleteSync(recursive: true));

    test('writes and removes an XDG autostart entry under XDG_CONFIG_HOME', () async {
      final service = DesktopAutostartService(
        executable: '/opt/Local Screen/localscreen',
        environment: {'XDG_CONFIG_HOME': config.path, 'HOME': '/nonexistent'},
      );
      final entry = File('${config.path}/autostart/localscreen.desktop');
      expect(service.linuxEntry.path, entry.path);
      expect(await service.isEnabled(), isFalse);

      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
      final text = entry.readAsStringSync();
      expect(text, startsWith('[Desktop Entry]'));
      expect(text, contains('Exec="/opt/Local Screen/localscreen" $autostartFlag'));

      await service.setEnabled(false);
      expect(entry.existsSync(), isFalse);
      // Disabling twice is harmless.
      await service.setEnabled(false);
    });
  }, skip: !Platform.isLinux);

  group('reconcileAutostart', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('adopts an entry that exists in the OS', () async {
      final store = PreferencesStore(await SharedPreferences.getInstance());
      await reconcileAutostart(InMemoryAutostartService(enabled: true), store);
      expect(store.load().launchAtStartup, isTrue);
    });

    test('clears the preference when the entry was removed outside the app', () async {
      final store = PreferencesStore(await SharedPreferences.getInstance());
      await store.save(const Preferences(launchAtStartup: true));
      await reconcileAutostart(InMemoryAutostartService(), store);
      expect(store.load().launchAtStartup, isFalse);
    });

    test('does nothing where autostart is not supported', () async {
      final store = PreferencesStore(await SharedPreferences.getInstance());
      await reconcileAutostart(const UnsupportedAutostartService(), store);
      expect(store.load().launchAtStartup, isFalse);
    });
  });
}
