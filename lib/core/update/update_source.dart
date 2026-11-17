import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'release.dart';

/// Why an update step failed.
enum UpdateFailure {
  /// The server could not be reached or answered with an error.
  network,

  /// The release has no package for this platform.
  noPackage,

  /// The download did not match its published checksum.
  checksum,

  /// The platform installer failed.
  install,
}

/// An update step failed for [failure].
class UpdateException implements Exception {
  /// Creates the exception.
  const UpdateException(this.failure, [this.detail]);

  final UpdateFailure failure;
  final Object? detail;

  @override
  String toString() => 'UpdateException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Called while a download runs; [total] is 0 when unknown.
typedef DownloadProgress = void Function(int received, int total);

/// Where releases come from.
abstract interface class UpdateSource {
  /// The newest published release, or null if there is none.
  Future<AppRelease?> latest();

  /// Downloads [asset] of [release] into [directory] and checks it against
  /// the release's checksum list. Throws [UpdateException].
  Future<File> download(
    AppRelease release,
    ReleaseAsset asset,
    Directory directory, {
    DownloadProgress? onProgress,
  });
}

/// Releases of a GitHub repository.
///
/// The only request LocalScreen makes outside the local network. It sends
/// nothing but the request itself.
class GitHubUpdateSource implements UpdateSource {
  /// Reads releases of [repository] (`owner/name`) from the API at [api].
  GitHubUpdateSource({this.repository = 'Gloridust/LocalScreen', Uri? api, HttpClient? client})
    : api = api ?? Uri.https('api.github.com'),
      _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 15));

  final String repository;

  /// Root of the GitHub REST API.
  final Uri api;
  final HttpClient _client;

  static const _userAgent = 'LocalScreen-Updater';

  Future<HttpClientResponse> _get(Uri url, {String accept = '*/*'}) async {
    try {
      final request = await _client.getUrl(url);
      request.headers
        ..set(HttpHeaders.userAgentHeader, _userAgent)
        ..set(HttpHeaders.acceptHeader, accept);
      return await request.close().timeout(const Duration(seconds: 30));
    } on Object catch (e) {
      throw UpdateException(UpdateFailure.network, e);
    }
  }

  @override
  Future<AppRelease?> latest() async {
    final response = await _get(
      api.replace(path: '/repos/$repository/releases/latest'),
      accept: 'application/vnd.github+json',
    );
    try {
      final body = await utf8.decodeStream(response).timeout(const Duration(seconds: 30));
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException(UpdateFailure.network, 'HTTP ${response.statusCode}');
      }
      final json = jsonDecode(body);
      return json is Map<String, Object?> ? AppRelease.fromGitHub(json) : null;
    } on UpdateException {
      rethrow;
    } on Object catch (e) {
      throw UpdateException(UpdateFailure.network, e);
    }
  }

  @override
  Future<File> download(
    AppRelease release,
    ReleaseAsset asset,
    Directory directory, {
    DownloadProgress? onProgress,
  }) async {
    final expected = await _expectedDigest(release, asset);
    await _emptied(directory);
    final file = File('${directory.path}${Platform.pathSeparator}${asset.name}');
    final partial = File('${file.path}.part');
    final response = await _get(asset.url);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw UpdateException(UpdateFailure.network, 'HTTP ${response.statusCode}');
    }
    final total = response.contentLength > 0 ? response.contentLength : asset.size;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final out = partial.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        out.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await out.close();
    } on Object catch (e) {
      await out.close().catchError((_) {});
      await partial.delete().catchError((_) => partial);
      throw UpdateException(UpdateFailure.network, e);
    }
    hasher.close();
    if (expected != null && digestSink.value.toString() != expected) {
      await partial.delete();
      throw const UpdateException(UpdateFailure.checksum);
    }
    return partial.rename(file.path);
  }

  /// Creates [directory], or clears out earlier downloads left in it.
  static Future<void> _emptied(Directory directory) async {
    try {
      if (directory.existsSync()) await directory.delete(recursive: true);
      await directory.create(recursive: true);
    } on FileSystemException catch (e) {
      throw UpdateException(UpdateFailure.network, e);
    }
  }

  /// The published digest of [asset]; null when the release lists none.
  Future<String?> _expectedDigest(AppRelease release, ReleaseAsset asset) async {
    final list = release.checksums;
    if (list == null) return null;
    final response = await _get(list.url);
    try {
      final text = await utf8.decodeStream(response).timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw UpdateException(UpdateFailure.network, 'HTTP ${response.statusCode}');
      }
      final digest = parseChecksums(text)[asset.name];
      // A list that does not mention the file means it cannot be verified.
      if (digest == null) throw const UpdateException(UpdateFailure.checksum);
      return digest;
    } on UpdateException {
      rethrow;
    } on Object catch (e) {
      throw UpdateException(UpdateFailure.network, e);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Serves one canned release; for tests and the `LS_FAKE` demo.
class FakeUpdateSource implements UpdateSource {
  /// Serves [release] (null: nothing published).
  FakeUpdateSource(
    this.release, {
    this.delay = const Duration(milliseconds: 300),
    this.failCheck = false,
    this.failDownload,
  });

  AppRelease? release;
  final Duration delay;

  /// Makes [latest] throw a network failure.
  bool failCheck;

  /// Makes [download] throw this failure.
  UpdateFailure? failDownload;

  /// How many times [latest] ran.
  int checks = 0;

  @override
  Future<AppRelease?> latest() async {
    checks++;
    await Future<void>.delayed(delay);
    if (failCheck) throw const UpdateException(UpdateFailure.network);
    return release;
  }

  @override
  Future<File> download(
    AppRelease release,
    ReleaseAsset asset,
    Directory directory, {
    DownloadProgress? onProgress,
  }) async {
    const steps = 5;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(delay ~/ steps);
      onProgress?.call(asset.size * i ~/ steps, asset.size);
    }
    if (failDownload case final failure?) throw UpdateException(failure);
    return File('${directory.path}${Platform.pathSeparator}${asset.name}');
  }
}
