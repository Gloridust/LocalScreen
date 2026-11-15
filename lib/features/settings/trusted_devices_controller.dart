import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/node/local_node.dart';
import '../../core/node/node_service.dart';
import '../../core/notices.dart';

/// Devices paired before, refreshed after every new pairing.
final trustedDevicesProvider = NotifierProvider<TrustedDevicesNotifier, List<DeviceInfo>>(
  TrustedDevicesNotifier.new,
);

/// See [trustedDevicesProvider].
class TrustedDevicesNotifier extends Notifier<List<DeviceInfo>> {
  @override
  List<DeviceInfo> build() {
    final service = ref.watch(nodeServiceProvider);
    final sub = service.events.listen((e) {
      if (e is NodeEvent_SessionEstablished || e is NodeEvent_PeerFound) unawaited(refresh());
    });
    ref.onDispose(sub.cancel);
    ref.listen(localNodeProvider, (_, next) {
      if (next is LocalNodeRunning) unawaited(refresh());
    }, fireImmediately: true);
    return const [];
  }

  /// Reloads the list from the node.
  Future<void> refresh() async {
    if (ref.read(localNodeProvider) is! LocalNodeRunning) return;
    try {
      final list = await ref.read(nodeServiceProvider).listTrusted();
      if (ref.mounted) state = List.unmodifiable(list);
    } catch (_) {
      // Keep the last known list.
    }
  }

  /// Forgets [device]; it will need a PIN again.
  Future<void> forget(DeviceInfo device) async {
    await ref.read(nodeServiceProvider).forgetTrusted(device.id);
    state = List.unmodifiable(state.where((d) => d.id != device.id));
    ref.read(noticeProvider.notifier).post(ForgotNotice(device.name));
  }
}
