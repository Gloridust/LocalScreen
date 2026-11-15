import 'package:flutter/foundation.dart';

import 'version.dart';

/// One downloadable file of a release.
@immutable
class ReleaseAsset {
  /// Creates an asset.
  const ReleaseAsset({required this.name, required this.url, required this.size});

  final String name;
  final Uri url;

  /// Size in bytes.
  final int size;
}

/// The installer format this platform updates from.
enum UpdatePackage {
  /// Debian package (Linux x64).
  deb('_amd64.deb'),

  /// Inno Setup installer (Windows x64).
  windowsSetup('-windows-x64-setup.exe'),

  /// Disk image (macOS).
  dmg('-macos.dmg'),

  /// Android package.
  apk('-android.apk');

  const UpdatePackage(this.suffix);

  /// How release asset names of this format end (see `build.yml`).
  final String suffix;

  /// The format for [platform] (`DeviceProfile.platform`) on a CPU that
  /// is [x64] or not; null where no package is published.
  static UpdatePackage? forPlatform(String platform, {required bool x64}) => switch (platform) {
    'linux' when x64 => deb,
    'windows' when x64 => windowsSetup,
    'macos' => dmg,
    'android' => apk,
    _ => null,
  };
}

/// A published release.
@immutable
class AppRelease {
  /// Creates a release.
  const AppRelease({
    required this.version,
    required this.page,
    this.notes = '',
    this.publishedAt,
    this.assets = const [],
  });

  /// Reads a GitHub "release" object; null when the tag is not a version.
  static AppRelease? fromGitHub(Map<String, Object?> json) {
    final version = AppVersion.tryParse(json['tag_name'] as String? ?? '');
    final page = Uri.tryParse(json['html_url'] as String? ?? '');
    if (version == null || page == null || !page.hasScheme) return null;
    final assets = <ReleaseAsset>[];
    for (final a
        in (json['assets'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>()) {
      final url = Uri.tryParse(a['browser_download_url'] as String? ?? '');
      final name = a['name'] as String?;
      if (url == null || !url.hasScheme || name == null) continue;
      assets.add(ReleaseAsset(name: name, url: url, size: (a['size'] as num?)?.toInt() ?? 0));
    }
    return AppRelease(
      version: version,
      page: page,
      notes: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
      assets: assets,
    );
  }

  final AppVersion version;

  /// The release's web page.
  final Uri page;

  /// Release notes, in Markdown.
  final String notes;
  final DateTime? publishedAt;
  final List<ReleaseAsset> assets;

  /// File name of the checksum list published with each release.
  static const checksumsName = 'SHA256SUMS.txt';

  /// The installer of [package] in this release, if published.
  ReleaseAsset? assetFor(UpdatePackage package) {
    for (final a in assets) {
      if (a.name.endsWith(package.suffix)) return a;
    }
    return null;
  }

  /// The checksum list, if published.
  ReleaseAsset? get checksums {
    for (final a in assets) {
      if (a.name == checksumsName) return a;
    }
    return null;
  }
}

/// Reads `sha256sum` output into a map from file name to lower-case digest.
Map<String, String> parseChecksums(String text) {
  final sums = <String, String>{};
  for (final line in text.split('\n')) {
    final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$').firstMatch(line);
    if (m != null) sums[m[2]!] = m[1]!.toLowerCase();
  }
  return sums;
}
