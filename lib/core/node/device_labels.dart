import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import 'node_service.dart';

/// Icon for a device form factor.
IconData deviceKindIcon(DeviceKind kind) => switch (kind) {
  DeviceKind.desktop => Icons.desktop_windows_rounded,
  DeviceKind.laptop => Icons.laptop_rounded,
  DeviceKind.tablet => Icons.tablet_android_rounded,
  DeviceKind.phone => Icons.smartphone_rounded,
  DeviceKind.tv => Icons.tv_rounded,
};

/// Human name of a lower-case platform id (`linux` → `Linux`).
String platformLabel(String platform) => switch (platform) {
  'linux' => 'Linux',
  'windows' => 'Windows',
  'macos' => 'macOS',
  'android' => 'Android',
  'ios' => 'iOS',
  _ => platform,
};

/// `Android · 192.168.1.42` style detail line for a device.
String deviceDetails(DeviceInfo d) {
  final address = d.addresses.isEmpty ? null : d.addresses.first;
  return [platformLabel(d.platform), ?address].join(' · ');
}
