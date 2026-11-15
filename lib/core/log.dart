import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Keeps the app's diagnostic output in a file, so a problem seen on one
/// device can be looked at afterwards.
///
/// Everything printed with [debugPrint] is appended to `localscreen.log` in
/// the directory given to [start]; the previous run's file is kept beside it
/// as `localscreen.previous.log`. Nothing leaves the device.
abstract final class AppLog {
  static const _name = 'localscreen.log';
  static const _previousName = 'localscreen.previous.log';

  /// A file larger than this is not carried over into the next run.
  static const _maxBytes = 2 * 1024 * 1024;

  static IOSink? _sink;
  static Directory? _directory;

  /// Folder holding the log files; null before [start] or if it failed.
  static Directory? get directory => _directory;

  /// Starts logging into [directory], headed by [banner] (version, device).
  static Future<void> start(String directory, {required String banner}) async {
    if (_sink != null) return;
    try {
      final dir = await Directory(directory).create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$_name');
      if (file.existsSync()) {
        final previous = File('${dir.path}${Platform.pathSeparator}$_previousName');
        if (previous.existsSync()) await previous.delete();
        if (file.lengthSync() <= _maxBytes) {
          await file.rename(previous.path);
        } else {
          await file.delete();
        }
      }
      _sink = file.openWrite(mode: FileMode.append);
      _directory = dir;
    } on Object catch (e) {
      debugPrint('log file unavailable: $e');
      return;
    }
    final print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      print(message, wrapWidth: wrapWidth);
      _write(message ?? '');
    };
    final onFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      _write('flutter error: ${details.exceptionAsString()}\n${details.stack}');
      onFlutterError?.call(details);
    };
    final onPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _write('uncaught error: $error\n$stack');
      return onPlatformError?.call(error, stack) ?? false;
    };
    _write(banner);
    _memory();
    Timer.periodic(_memoryInterval, (_) => _memory());
  }

  /// How often the process's memory is noted, so growth shows in the log.
  static const _memoryInterval = Duration(minutes: 1);

  static void _memory() => _write('app: memory ${ProcessInfo.currentRss ~/ (1024 * 1024)} MB');

  static void _write(String message) {
    final sink = _sink;
    if (sink == null) return;
    sink.writeln('${DateTime.now().toIso8601String()} $message');
    // Flushed lazily by the sink; a crash can lose only the last moments.
  }

  /// Writes everything buffered so far to disk.
  static Future<void> flush() async {
    try {
      await _sink?.flush();
    } on Object {
      // A flush is already in progress.
    }
  }

  /// Shows the log folder in the desktop's file manager.
  static Future<void> reveal() async {
    final dir = _directory;
    if (dir == null) return;
    await flush();
    final command = switch (Platform.operatingSystem) {
      'windows' => 'explorer',
      'macos' => 'open',
      _ => 'xdg-open',
    };
    try {
      await Process.run(command, [dir.path]);
    } on Object catch (e) {
      debugPrint('could not open the log folder: $e');
    }
  }
}
