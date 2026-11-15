import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../node/node_service.dart';

/// Facts about this device that do not change while the app runs.
@immutable
class DeviceProfile {
  /// Creates a profile.
  const DeviceProfile({
    required this.defaultName,
    required this.kind,
    required this.platform,
    required this.storageDir,
    this.memoryMb,
  });

  /// Name used until the user picks one.
  final String defaultName;
  final DeviceKind kind;

  /// Lower-case OS id: `linux`, `windows`, `macos`, `android`, `ios`.
  final String platform;

  /// Writable directory for the identity key and trusted-device store.
  final String storageDir;

  /// Physical RAM in megabytes; null when the platform does not say.
  final int? memoryMb;

  /// Desktop platforms (window management, pointer-first).
  bool get isDesktop => const {'linux', 'windows', 'macos'}.contains(platform);

  /// Detects the profile of the running device.
  static Future<DeviceProfile> detect() async {
    final platform = Platform.operatingSystem;
    final info = DeviceInfoPlugin();
    final storage = await getApplicationSupportDirectory();
    final shortestSide = _shortestLogicalSide();
    var name = Platform.localHostname;
    var kind = DeviceKind.desktop;
    int? memoryMb;
    try {
      switch (platform) {
        case 'android':
          final a = await info.androidInfo;
          name = a.name.isNotEmpty ? a.name : '${a.manufacturer} ${a.model}';
          kind = _mobileKind(shortestSide);
          memoryMb = a.physicalRamSize;
        case 'ios':
          final i = await info.iosInfo;
          name = i.name;
          kind = _mobileKind(shortestSide);
          memoryMb = i.physicalRamSize;
        case 'macos':
          final m = await info.macOsInfo;
          name = m.computerName;
          kind = m.model.toLowerCase().contains('book') ? DeviceKind.laptop : DeviceKind.desktop;
          memoryMb = m.memorySize ~/ (1024 * 1024);
        case 'windows':
          final w = await info.windowsInfo;
          name = w.computerName;
          memoryMb = w.systemMemoryInMegabytes;
        case 'linux':
          final l = await info.linuxInfo;
          name = Platform.localHostname.isNotEmpty ? Platform.localHostname : l.prettyName;
          kind = _hasBattery() ? DeviceKind.laptop : DeviceKind.desktop;
          memoryMb = _linuxMemoryMb();
      }
    } catch (e) {
      debugPrint('device_info unavailable: $e');
    }
    return DeviceProfile(
      defaultName: name.trim().isEmpty ? 'LocalScreen' : name.trim(),
      kind: kind,
      platform: platform,
      storageDir: storage.path,
      memoryMb: memoryMb != null && memoryMb > 0 ? memoryMb : null,
    );
  }

  /// `MemTotal` of `/proc/meminfo`.
  static int? _linuxMemoryMb() {
    try {
      for (final line in File('/proc/meminfo').readAsLinesSync()) {
        if (!line.startsWith('MemTotal:')) continue;
        final kb = int.tryParse(RegExp(r'\d+').firstMatch(line)?.group(0) ?? '');
        return kb == null ? null : kb ~/ 1024;
      }
    } catch (_) {
      // Not Linux enough.
    }
    return null;
  }

  static double _shortestLogicalSide() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return 0;
    final v = views.first;
    return v.physicalSize.shortestSide / v.devicePixelRatio;
  }

  static DeviceKind _mobileKind(double shortestSide) =>
      shortestSide >= 600 ? DeviceKind.tablet : DeviceKind.phone;

  /// Linux laptops expose a battery under sysfs; desktops do not.
  static bool _hasBattery() {
    try {
      final dir = Directory('/sys/class/power_supply');
      return dir.existsSync() &&
          dir.listSync().any((e) => e.path.split('/').last.startsWith('BAT'));
    } catch (_) {
      return false;
    }
  }
}

/// The detected [DeviceProfile]; overridden at startup.
final deviceProfileProvider = Provider<DeviceProfile>(
  (ref) => throw UnimplementedError('deviceProfileProvider must be overridden'),
);
