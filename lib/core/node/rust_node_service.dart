import 'dart:async';

import '../../src/rust/api/node.dart' as bridge;
import '../../src/rust/frb_generated.dart';
import 'node_service.dart';

/// [NodeService] backed by the Rust core through flutter_rust_bridge.
class RustNodeService implements NodeService {
  RustNodeService._();

  /// Loads the native library and returns the service.
  static Future<RustNodeService> create() async {
    await RustLib.init();
    return RustNodeService._();
  }

  final _events = StreamController<NodeEvent>.broadcast();
  StreamSubscription<NodeEvent>? _node;

  @override
  Stream<NodeEvent> get events => _events.stream;

  @override
  Future<void> start(NodeConfig config) async {
    await _node?.cancel();
    // The bridge reports the outcome in-band: `Ready` is the first event of a
    // successful start, a failure arrives as a stream error.
    final started = Completer<void>();
    _node = bridge
        .startNode(config: config)
        .listen(
          (event) {
            if (event is NodeEvent_Ready) {
              if (!started.isCompleted) started.complete();
              return;
            }
            _events.add(event);
          },
          onError: (Object e, StackTrace s) {
            if (!started.isCompleted) {
              started.completeError(e, s);
            } else {
              _events.addError(e, s);
            }
          },
        );
    return started.future;
  }

  @override
  Future<LocalIdentity> localIdentity() => bridge.localIdentity();

  @override
  Future<void> stop() async {
    await bridge.stopNode();
    await _node?.cancel();
    _node = null;
  }

  @override
  Future<void> setDiscoverable(bool discoverable) =>
      bridge.setDiscoverable(discoverable: discoverable);

  @override
  Future<void> renameDevice(String name) => bridge.renameDevice(name: name);

  @override
  Future<List<DeviceInfo>> listPeers() => bridge.listPeers();

  @override
  Future<DeviceInfo> connectManual(String address) => bridge.connectManual(address: address);

  @override
  Future<String> requestSession(String peerId, ShareMode mode) =>
      bridge.requestSession(peerId: peerId, mode: mode);

  @override
  Future<void> submitPin(String sessionId, String pin) =>
      bridge.submitPin(sessionId: sessionId, pin: pin);

  @override
  Future<void> respondToRequest(String sessionId, {required bool accept}) =>
      bridge.respondToRequest(sessionId: sessionId, accept: accept);

  @override
  Future<void> sendSignal(String sessionId, String payload) =>
      bridge.sendSignal(sessionId: sessionId, payload: payload);

  @override
  Future<void> closeSession(String sessionId) => bridge.closeSession(sessionId: sessionId);

  @override
  Future<List<DeviceInfo>> listTrusted() => bridge.listTrusted();

  @override
  Future<void> forgetTrusted(String id) => bridge.forgetTrusted(id: id);

  @override
  Future<void> dispose() async {
    await _node?.cancel();
    await _events.close();
  }
}
