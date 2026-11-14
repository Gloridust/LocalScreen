import '../../src/rust/api/types.dart';

export '../../src/rust/api/types.dart';

/// The control plane as seen by the UI: discovery, pairing, sessions and
/// signalling transport.
///
/// Mirrors `rust/src/api/node.rs` one-to-one so that features never call the
/// generated bridge directly. [RustNodeService] talks to the Rust core;
/// [FakeNodeService] simulates it for tests and the `LS_FAKE` demo mode.
abstract class NodeService {
  /// Every event of the running node. Broadcast; safe to listen to before
  /// [start] so no early event is missed.
  Stream<NodeEvent> get events;

  /// Starts the node. Events flow through [events] until [stop].
  Future<void> start(NodeConfig config);

  /// Identity of the running node.
  Future<LocalIdentity> localIdentity();

  /// Stops discovery, closes every session and releases the port.
  Future<void> stop();

  /// Turns LAN advertisement on or off.
  Future<void> setDiscoverable(bool discoverable);

  /// Changes the advertised device name.
  Future<void> renameDevice(String name);

  /// Peers currently visible.
  Future<List<DeviceInfo>> listPeers();

  /// Probes `host` or `host:port` directly when multicast is blocked.
  Future<DeviceInfo> connectManual(String address);

  /// Host side: asks [peerId] to become a display. Returns the session id.
  Future<String> requestSession(String peerId, ShareMode mode);

  /// Host side: submits the PIN shown on the display.
  Future<void> submitPin(String sessionId, String pin);

  /// Display side: answers a request from a trusted host.
  Future<void> respondToRequest(String sessionId, {required bool accept});

  /// Sends an opaque signalling payload over the encrypted channel.
  Future<void> sendSignal(String sessionId, String payload);

  /// Ends a session or cancels a pending request.
  Future<void> closeSession(String sessionId);

  /// Devices paired before.
  Future<List<DeviceInfo>> listTrusted();

  /// Forgets a trusted device; it will need a PIN again.
  Future<void> forgetTrusted(String id);

  /// Releases resources held by the service itself.
  Future<void> dispose();
}

/// Extracts the session id an event refers to, if any.
String? sessionIdOf(NodeEvent event) => switch (event) {
  NodeEvent_IncomingRequest(:final sessionId) ||
  NodeEvent_PinRequired(:final sessionId) ||
  NodeEvent_PinRejected(:final sessionId) ||
  NodeEvent_SessionEstablished(:final sessionId) ||
  NodeEvent_Signal(:final sessionId) ||
  NodeEvent_SessionClosed(:final sessionId) => sessionId,
  NodeEvent_Ready() || NodeEvent_PeerFound() || NodeEvent_PeerLost() => null,
};
