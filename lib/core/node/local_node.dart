import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/device_profile.dart';
import '../prefs/preferences.dart';
import 'node_service.dart';

/// The [NodeService] in use; overridden at startup (Rust or fake).
final nodeServiceProvider = Provider<NodeService>(
  (ref) => throw UnimplementedError('nodeServiceProvider must be overridden'),
);

/// Lifecycle of the local node.
sealed class LocalNodeState {
  const LocalNodeState();
}

/// The node is starting.
final class LocalNodeStarting extends LocalNodeState {
  /// Creates the starting state.
  const LocalNodeStarting();
}

/// The node is up and reachable at [identity].
final class LocalNodeRunning extends LocalNodeState {
  /// Creates the running state.
  const LocalNodeRunning(this.identity);

  final LocalIdentity identity;
}

/// The node could not start.
final class LocalNodeFailed extends LocalNodeState {
  /// Creates the failed state.
  const LocalNodeFailed(this.error);

  final Object error;
}

/// Starts the node and owns the settings that are pushed to it
/// (name, discoverability).
final localNodeProvider = NotifierProvider<LocalNodeNotifier, LocalNodeState>(
  LocalNodeNotifier.new,
);

/// See [localNodeProvider].
class LocalNodeNotifier extends Notifier<LocalNodeState> {
  @override
  LocalNodeState build() {
    final service = ref.watch(nodeServiceProvider);
    ref.onDispose(() => service.stop().catchError((Object _) {}));
    Future.microtask(_start);
    return const LocalNodeStarting();
  }

  NodeService get _service => ref.read(nodeServiceProvider);

  /// The name advertised to peers right now.
  String get deviceName {
    final prefs = ref.read(preferencesProvider);
    return prefs.deviceName ?? ref.read(deviceProfileProvider).defaultName;
  }

  Future<void> _start() async {
    final prefs = ref.read(preferencesProvider);
    final profile = ref.read(deviceProfileProvider);
    try {
      await _service.start(
        NodeConfig(
          deviceName: deviceName,
          deviceKind: profile.kind,
          platform: profile.platform,
          storageDir: profile.storageDir,
          discoverable: prefs.discoverable,
          port: 0,
        ),
      );
      final identity = await _service.localIdentity();
      if (ref.mounted) state = LocalNodeRunning(identity);
    } catch (e) {
      debugPrint('node failed to start: $e');
      if (ref.mounted) state = LocalNodeFailed(e);
    }
  }

  /// Tries to start again after a failure.
  Future<void> retry() async {
    state = const LocalNodeStarting();
    await _start();
  }

  /// Turns advertisement on or off and remembers the choice.
  Future<void> setDiscoverable(bool value) async {
    await ref.read(preferencesProvider.notifier).update((p) => p.copyWith(discoverable: value));
    if (state is LocalNodeRunning) {
      await _service.setDiscoverable(value).catchError((Object e) => debugPrint('$e'));
    }
  }

  /// Renames the device; an empty [name] restores the platform default.
  Future<void> rename(String name) async {
    final trimmed = name.trim();
    await ref
        .read(preferencesProvider.notifier)
        .update(
          (p) => trimmed.isEmpty || trimmed == ref.read(deviceProfileProvider).defaultName
              ? p.copyWith(clearDeviceName: true)
              : p.copyWith(deviceName: trimmed),
        );
    if (state is! LocalNodeRunning) return;
    try {
      await _service.renameDevice(deviceName);
      final identity = await _service.localIdentity();
      if (ref.mounted) state = LocalNodeRunning(identity);
    } catch (e) {
      debugPrint('rename failed: $e');
    }
  }
}
