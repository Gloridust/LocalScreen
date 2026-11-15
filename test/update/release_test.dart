import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/update/release.dart';
import 'package:localscreen/core/update/release_notes.dart';
import 'package:localscreen/core/update/version.dart';

void main() {
  group('AppVersion', () {
    test('parses tags and pubspec versions alike', () {
      expect(AppVersion.tryParse('v0.1.3'), const AppVersion(0, 1, 3));
      expect(AppVersion.tryParse('0.1.3+4'), const AppVersion(0, 1, 3));
      expect(AppVersion.tryParse(' 1.2.3-beta.1 '), const AppVersion(1, 2, 3, 'beta.1'));
      expect('${const AppVersion(1, 2, 3, 'beta.1')}', '1.2.3-beta.1');
      for (final bad in ['', 'latest', '1.2', 'v1.2.x', '1.2.3.4']) {
        expect(AppVersion.tryParse(bad), isNull, reason: bad);
      }
    });

    test('orders numerically, with pre-releases below their release', () {
      AppVersion v(String s) => AppVersion.tryParse(s)!;
      expect(v('0.1.10') > v('0.1.9'), isTrue);
      expect(v('0.2.0') > v('0.1.99'), isTrue);
      expect(v('1.0.0') > v('0.99.99'), isTrue);
      expect(v('1.0.0') > v('1.0.0-rc.2'), isTrue);
      expect(v('1.0.0-rc.2') > v('1.0.0-rc.1'), isTrue);
      expect(v('1.0.0-rc.1') > v('1.0.0-beta.9'), isTrue);
      expect(v('1.0.0') > v('1.0.0'), isFalse);
      expect(v('0.1.3+9'), v('0.1.3'));
    });
  });

  group('AppRelease', () {
    final release = AppRelease.fromGitHub({
      'tag_name': 'v0.1.4',
      'html_url': 'https://github.com/Gloridust/LocalScreen/releases/tag/v0.1.4',
      'body': '## Fixed\n- Something',
      'published_at': '2026-11-16T10:00:00Z',
      'assets': [
        for (final name in [
          'localscreen_0.1.4_amd64.deb',
          'LocalScreen-0.1.4-windows-x64-setup.exe',
          'LocalScreen-0.1.4-macos.dmg',
          'LocalScreen-0.1.4-android.apk',
          'SHA256SUMS.txt',
        ])
          {'name': name, 'size': 1234, 'browser_download_url': 'https://example.invalid/$name'},
        {'name': 'broken'},
      ],
    })!;

    test('reads a GitHub release', () {
      expect(release.version, const AppVersion(0, 1, 4));
      expect(release.publishedAt, DateTime.utc(2026, 11, 16, 10));
      expect(release.assets.length, 5);
      expect(release.checksums!.name, 'SHA256SUMS.txt');
      expect(AppRelease.fromGitHub({'tag_name': 'nightly', 'html_url': 'https://x'}), isNull);
    });

    test('finds the package of each platform', () {
      expect(
        release.assetFor(UpdatePackage.forPlatform('linux', x64: true)!)!.name,
        'localscreen_0.1.4_amd64.deb',
      );
      expect(
        release.assetFor(UpdatePackage.forPlatform('windows', x64: true)!)!.name,
        'LocalScreen-0.1.4-windows-x64-setup.exe',
      );
      expect(release.assetFor(UpdatePackage.dmg)!.name, 'LocalScreen-0.1.4-macos.dmg');
      expect(release.assetFor(UpdatePackage.apk)!.name, 'LocalScreen-0.1.4-android.apk');
      expect(UpdatePackage.forPlatform('linux', x64: false), isNull);
      expect(UpdatePackage.forPlatform('ios', x64: false), isNull);
    });
  });

  test('checksum lists map file names to digests', () {
    final a = 'a' * 64;
    final b = 'B' * 64;
    final sums = parseChecksums('$a  one.deb\n$b *two.exe\nnot a line\n');
    expect(sums, {'one.deb': a, 'two.exe': 'b' * 64});
  });

  test('release notes reduce to headings, bullets and paragraphs', () {
    final blocks = parseReleaseNotes('''
Short **summary** with a [link](https://example.invalid).
Second line of it.

## Fixed

- **Idle CPU.** Ripples rest.
* Another `thing`

| Platform | File |
| --- | --- |
| Linux | deb |

---
''');
    expect(blocks.map((b) => (b.runtimeType, b.text)).toList(), [
      (NoteParagraph, 'Short summary with a link. Second line of it.'),
      (NoteHeading, 'Fixed'),
      (NoteBullet, 'Idle CPU. Ripples rest.'),
      (NoteBullet, 'Another thing'),
    ]);
  });
}
