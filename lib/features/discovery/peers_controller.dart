import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lumen.dart';
import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';

/// Devices currently visible on the network, in the order they appeared.
final peersProvider = NotifierProvider<PeersNotifier, List<DeviceInfo>>(PeersNotifier.new);

/// Folds `PeerFound` / `PeerLost` events into [peersProvider].
class PeersNotifier extends Notifier<List<DeviceInfo>> {
  final _byId = <String, DeviceInfo>{};

  @override
  List<DeviceInfo> build() {
    final service = ref.watch(nodeServiceProvider);
    final sub = service.events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    ref.listen(localNodeProvider, (_, next) {
      if (next is LocalNodeRunning) unawaited(_snapshot());
    });
    return const [];
  }

  void _onEvent(NodeEvent event) {
    switch (event) {
      case NodeEvent_PeerFound(:final peer):
        // A new neighbour is worth a ripple; a refreshed one is not.
        if (!_byId.containsKey(peer.id)) LsAmbient.pulse();
        _byId[peer.id] = peer;
      case NodeEvent_PeerLost(:final id):
        if (_byId.remove(id) == null) return;
      default:
        return;
    }
    state = List.unmodifiable(_byId.values);
  }

  Future<void> _snapshot() async {
    try {
      final peers = await ref.read(nodeServiceProvider).listPeers();
      if (!ref.mounted) return;
      for (final p in peers) {
        _byId[p.id] = p;
      }
      state = List.unmodifiable(_byId.values);
    } catch (_) {
      // Events will fill the list.
    }
  }

  /// Probes [address] directly and adds the device to the list.
  Future<DeviceInfo> connectManual(String address) async {
    final peer = await ref.read(nodeServiceProvider).connectManual(address.trim());
    _byId[peer.id] = peer;
    state = List.unmodifiable(_byId.values);
    return peer;
  }
}
