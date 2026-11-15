import 'package:flutter/foundation.dart';

/// A semantic version such as `0.1.2` or `v1.0.0-beta.1`.
///
/// Build metadata (`+3`) is ignored, as semver requires.
@immutable
class AppVersion implements Comparable<AppVersion> {
  /// Creates a version.
  const AppVersion(this.major, this.minor, this.patch, [this.preRelease = '']);

  /// Version used when the real one is unknown (tests, broken metadata).
  static const unknown = AppVersion(0, 0, 0);

  static final _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  final int major;
  final int minor;
  final int patch;

  /// Pre-release identifiers, e.g. `beta.1`; empty for a release.
  final String preRelease;

  /// Parses [text]; returns null when it is not a semantic version.
  static AppVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m[4] ?? '');
  }

  /// Whether this is a pre-release.
  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [(major, other.major), (minor, other.minor), (patch, other.patch)]) {
      if (a != b) return a.compareTo(b);
    }
    // A release ranks above any of its pre-releases.
    if (preRelease == other.preRelease) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    final mine = preRelease.split('.');
    final theirs = other.preRelease.split('.');
    for (var i = 0; i < mine.length && i < theirs.length; i++) {
      final c = _compareIdentifier(mine[i], theirs[i]);
      if (c != 0) return c;
    }
    return mine.length.compareTo(theirs.length);
  }

  static int _compareIdentifier(String a, String b) {
    final x = int.tryParse(a);
    final y = int.tryParse(b);
    if (x != null && y != null) return x.compareTo(y);
    if (x != null) return -1; // Numeric identifiers rank lower.
    if (y != null) return 1;
    return a.compareTo(b);
  }

  /// Whether this version is newer than [other].
  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() => '$major.$minor.$patch${isPreRelease ? '-$preRelease' : ''}';
}
