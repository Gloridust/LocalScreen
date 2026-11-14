import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/media/quality.dart';
import 'package:localscreen/core/node/node_service.dart';
import 'package:localscreen/core/prefs/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults when nothing is stored', () async {
    final store = PreferencesStore(await SharedPreferences.getInstance());
    final p = store.load();
    expect(p.deviceName, isNull);
    expect(p.discoverable, isTrue);
    expect(p.defaultMode, ShareMode.mirror);
    expect(p.defaultQuality, QualityPreset.balanced);
    expect(p.autoAcceptTrusted, isFalse);
    expect(p.themeMode, ThemeMode.system);
    expect(p.locale, isNull);
  });

  test('every field survives a save / load round trip', () async {
    final sp = await SharedPreferences.getInstance();
    const saved = Preferences(
      deviceName: '书房的平板',
      discoverable: false,
      defaultMode: ShareMode.extend,
      defaultQuality: QualityPreset.clear,
      autoAcceptTrusted: true,
      themeMode: ThemeMode.light,
      locale: Locale('en'),
    );
    await PreferencesStore(sp).save(saved);
    final loaded = PreferencesStore(sp).load();
    expect(loaded.deviceName, '书房的平板');
    expect(loaded.discoverable, isFalse);
    expect(loaded.defaultMode, ShareMode.extend);
    expect(loaded.defaultQuality, QualityPreset.clear);
    expect(loaded.autoAcceptTrusted, isTrue);
    expect(loaded.themeMode, ThemeMode.light);
    expect(loaded.locale, const Locale('en'));
  });

  test('clearing nullable fields removes their keys', () async {
    final sp = await SharedPreferences.getInstance();
    final store = PreferencesStore(sp);
    await store.save(const Preferences(deviceName: 'x', locale: Locale('zh')));
    await store.save(store.load().copyWith(clearDeviceName: true, clearLocale: true));
    expect(sp.containsKey('ls.deviceName'), isFalse);
    expect(sp.containsKey('ls.locale'), isFalse);
  });

  test('unknown stored values fall back to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'ls.defaultMode': 'hologram',
      'ls.defaultQuality': 'ultra',
      'ls.themeMode': 'sepia',
      'ls.deviceName': '   ',
    });
    final p = PreferencesStore(await SharedPreferences.getInstance()).load();
    expect(p.defaultMode, ShareMode.mirror);
    expect(p.defaultQuality, QualityPreset.balanced);
    expect(p.themeMode, ThemeMode.system);
    expect(p.deviceName, isNull);
  });

  test('PreferencesNotifier persists updates immediately', () async {
    final sp = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
    );
    addTearDown(container.dispose);
    await container
        .read(preferencesProvider.notifier)
        .update((p) => p.copyWith(defaultQuality: QualityPreset.smooth, themeMode: ThemeMode.dark));
    expect(container.read(preferencesProvider).defaultQuality, QualityPreset.smooth);
    expect(sp.getString('ls.defaultQuality'), 'smooth');
    expect(sp.getString('ls.themeMode'), 'dark');
  });
}
