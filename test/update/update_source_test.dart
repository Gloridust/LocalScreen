import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/update/release.dart';
import 'package:localscreen/core/update/update_source.dart';
import 'package:localscreen/core/update/version.dart';

void main() {
  late HttpServer server;
  late Directory temp;
  late Uri root;
  final package = List<int>.generate(200000, (i) => i % 251);
  var checksumBody = '';
  var latestStatus = HttpStatus.ok;

  setUp(() async {
    // flutter_test blocks real HTTP by default; these talk to localhost.
    HttpOverrides.global = null;
    temp = await Directory.systemTemp.createTemp('ls-update-test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    root = Uri.parse('http://127.0.0.1:${server.port}');
    checksumBody = '${sha256.convert(package)}  localscreen_9.9.9_amd64.deb\n';
    latestStatus = HttpStatus.ok;
    server.listen((request) async {
      final response = request.response;
      switch (request.uri.path) {
        case '/repos/acme/app/releases/latest':
          expect(request.headers.value(HttpHeaders.userAgentHeader), isNotEmpty);
          response.statusCode = latestStatus;
          response.write(
            jsonEncode({
              'tag_name': 'v9.9.9',
              'html_url': '$root/release',
              'body': 'notes',
              'assets': [
                for (final name in ['localscreen_9.9.9_amd64.deb', 'SHA256SUMS.txt'])
                  {'name': name, 'size': package.length, 'browser_download_url': '$root/$name'},
              ],
            }),
          );
        case '/localscreen_9.9.9_amd64.deb':
          response.add(package);
        case '/SHA256SUMS.txt':
          response.write(checksumBody);
        default:
          response.statusCode = HttpStatus.notFound;
      }
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await temp.delete(recursive: true);
  });

  GitHubUpdateSource source() => GitHubUpdateSource(repository: 'acme/app', api: root);

  test('reads the latest release', () async {
    final release = (await source().latest())!;
    expect(release.version, const AppVersion(9, 9, 9));
    expect(release.assetFor(UpdatePackage.deb)!.size, package.length);
  });

  test('no release yet is not an error; a server error is', () async {
    latestStatus = HttpStatus.notFound;
    expect(await source().latest(), isNull);
    latestStatus = HttpStatus.forbidden; // rate limited
    await expectLater(
      source().latest(),
      throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.network)),
    );
  });

  test('downloads the package, reports progress and checks its digest', () async {
    final s = source();
    final release = (await s.latest())!;
    final progress = <int>[];
    final stale = File('${temp.path}/old.deb')..writeAsStringSync('left over');
    final file = await s.download(
      release,
      release.assetFor(UpdatePackage.deb)!,
      temp,
      onProgress: (received, total) {
        expect(total, package.length);
        progress.add(received);
      },
    );
    expect(file.readAsBytesSync(), package);
    expect(progress.last, package.length);
    expect(stale.existsSync(), isFalse, reason: 'earlier downloads are cleared');
  });

  test('a package that does not match its checksum is discarded', () async {
    checksumBody = '${'0' * 64}  localscreen_9.9.9_amd64.deb\n';
    final s = source();
    final release = (await s.latest())!;
    await expectLater(
      s.download(release, release.assetFor(UpdatePackage.deb)!, temp),
      throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.checksum)),
    );
    expect(temp.listSync(), isEmpty);
  });

  test('a checksum list that omits the package cannot vouch for it', () async {
    checksumBody = '${'0' * 64}  something-else.deb\n';
    final s = source();
    final release = (await s.latest())!;
    await expectLater(
      s.download(release, release.assetFor(UpdatePackage.deb)!, temp),
      throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.checksum)),
    );
  });

  test('an unreachable server is a network failure', () async {
    final dead = GitHubUpdateSource(repository: 'acme/app', api: Uri.parse('http://127.0.0.1:1'));
    await expectLater(
      dead.latest(),
      throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', UpdateFailure.network)),
    );
  });
}
