import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../media/quality.dart';
import '../node/node_service.dart';
import '../platform/linux/monitor_layout.dart';
import '../platform/virtual_display.dart';

/// User preferences, persisted with `shared_preferences`.
class Preferences {
  /// Creates a preference snapshot.
  const Preferences({
    this.deviceName,
    this.discoverable = true,
    this.defaultMode = ShareMode.mirror,
    this.defaultQuality = QualityPreset.balanced,
    this.autoAcceptTrusted = false,
    this.themeMode = ThemeMode.system,
    this.locale,
    this.launchAtStartup = false,
  });

  /// Custom device name; null means the platform default.
  final String? deviceName;
  final bool discoverable;
  final ShareMode defaultMode;
  final QualityPreset defaultQuality;

  /// Accept requests from trusted hosts without asking.
  final bool autoAcceptTrusted;
  final ThemeMode themeMode;

  /// Null follows the system language.
  final Locale? locale;

  /// Start at login (desktop only); mirrors the OS autostart entry.
  final bool launchAtStartup;

  /// Returns a copy with the given fields replaced. Use [clearDeviceName] /
  /// [clearLocale] to reset the nullable fields.
  Preferences copyWith({
    String? deviceName,
    bool clearDeviceName = false,
    bool? discoverable,
    ShareMode? defaultMode,
    QualityPreset? defaultQuality,
    bool? autoAcceptTrusted,
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    bool? launchAtStartup,
  }) {
    return Preferences(
      deviceName: clearDeviceName ? null : deviceName ?? this.deviceName,
      discoverable: discoverable ?? this.discoverable,
      defaultMode: defaultMode ?? this.defaultMode,
      defaultQuality: defaultQuality ?? this.defaultQuality,
      autoAcceptTrusted: autoAcceptTrusted ?? this.autoAcceptTrusted,
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : locale ?? this.locale,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
    );
  }
}

/// Reads and writes [Preferences] in a [SharedPreferences] instance.
class PreferencesStore {
  /// Wraps [prefs].
  const PreferencesStore(this.prefs);

  final SharedPreferences prefs;

  static const _deviceName = 'ls.deviceName';
  static const _discoverable = 'ls.discoverable';
  static const _defaultMode = 'ls.defaultMode';
  static const _defaultQuality = 'ls.defaultQuality';
  static const _autoAccept = 'ls.autoAcceptTrusted';
  static const _themeMode = 'ls.themeMode';
  static const _locale = 'ls.locale';
  static const _launchAtStartup = 'ls.launchAtStartup';

  /// Loads the stored preferences, using defaults for missing keys.
  Preferences load() {
    T byName<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    final localeTag = prefs.getString(_locale);
    final name = prefs.getString(_deviceName)?.trim();
    return Preferences(
      deviceName: name == null || name.isEmpty ? null : name,
      discoverable: prefs.getBool(_discoverable) ?? true,
      defaultMode: byName(ShareMode.values, prefs.getString(_defaultMode), ShareMode.mirror),
      defaultQuality: QualityPreset.parse(prefs.getString(_defaultQuality)),
      autoAcceptTrusted: prefs.getBool(_autoAccept) ?? false,
      themeMode: byName(ThemeMode.values, prefs.getString(_themeMode), ThemeMode.system),
      locale: localeTag == null || localeTag.isEmpty ? null : Locale(localeTag),
      launchAtStartup: prefs.getBool(_launchAtStartup) ?? false,
    );
  }

  /// Persists every field of [p].
  Future<void> save(Preferences p) async {
    await Future.wait([
      if (p.deviceName == null)
        prefs.remove(_deviceName)
      else
        prefs.setString(_deviceName, p.deviceName!),
      prefs.setBool(_discoverable, p.discoverable),
      prefs.setString(_defaultMode, p.defaultMode.name),
      prefs.setString(_defaultQuality, p.defaultQuality.name),
      prefs.setBool(_autoAccept, p.autoAcceptTrusted),
      prefs.setString(_themeMode, p.themeMode.name),
      prefs.setBool(_launchAtStartup, p.launchAtStartup),
      if (p.locale == null)
        prefs.remove(_locale)
      else
        prefs.setString(_locale, p.locale!.languageCode),
    ]);
  }
}

/// Keeps each display device's virtual-monitor placement in
/// [SharedPreferences], so the monitor reappears where it was last put.
class PreferencesPlacementStore implements VirtualPlacementStore {
  /// Wraps [prefs].
  const PreferencesPlacementStore(this.prefs);

  final SharedPreferences prefs;

  static String _key(String key) => 'ls.extendPlacement.$key';

  @override
  VirtualPlacement? read(String key) => VirtualPlacement.tryParse(prefs.getString(_key(key)));

  @override
  void write(String key, VirtualPlacement placement) {
    prefs.setString(_key(key), placement.encode());
  }
}

/// The app's [SharedPreferences]; overridden at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Current preferences. Every update is persisted immediately.
final preferencesProvider = NotifierProvider<PreferencesNotifier, Preferences>(
  PreferencesNotifier.new,
);

/// Owns [Preferences] and writes changes through [PreferencesStore].
class PreferencesNotifier extends Notifier<Preferences> {
  late PreferencesStore _store;

  @override
  Preferences build() {
    _store = PreferencesStore(ref.watch(sharedPreferencesProvider));
    return _store.load();
  }

  /// Applies [change] and persists the result.
  Future<void> update(Preferences Function(Preferences p) change) async {
    state = change(state);
    await _store.save(state);
  }
}
