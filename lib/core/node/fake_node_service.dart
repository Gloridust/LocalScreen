import 'dart:async';

import 'node_service.dart';

/// In-memory [NodeService] that simulates a small LAN.
///
/// Used by widget tests and by the `--dart-define=LS_FAKE=true` demo mode so
/// the UI can be built without the Rust core. Peers appear one by one, any
/// untrusted peer asks for [expectedPin], and trusted peers accept directly.
class FakeNodeService implements NodeService {
  /// Creates a fake network.
  FakeNodeService({
    List<DeviceInfo>? peers,
    this.discoveryInterval = const Duration(milliseconds: 650),
    this.latency = const Duration(milliseconds: 600),
    this.expectedPin = demoPin,
    this.maxPinAttempts = 5,
  }) : _pending = List.of(peers ?? demoPeers),
       _trusted = {
         for (final p in peers ?? demoPeers)
           if (p.trusted) p.id: p,
       };

  /// The PIN every simulated display shows.
  static const demoPin = '482913';

  /// A plausible set of nearby devices.
  static const demoPeers = <DeviceInfo>[
    DeviceInfo(
      id: 'fake-xiaomi-pad',
      name: '小米平板 6 Pro',
      kind: DeviceKind.tablet,
      platform: 'android',
      addresses: ['192.168.1.42'],
      port: 53520,
      trusted: false,
    ),
    DeviceInfo(
      id: 'fake-surface',
      name: 'Surface Go 3',
      kind: DeviceKind.tablet,
      platform: 'windows',
      addresses: ['192.168.1.57'],
      port: 53520,
      trusted: true,
    ),
    DeviceInfo(
      id: 'fake-macbook',
      name: 'MacBook Air',
      kind: DeviceKind.laptop,
      platform: 'macos',
      addresses: ['192.168.1.23'],
      port: 53520,
      trusted: false,
    ),
    DeviceInfo(
      id: 'fake-pixel',
      name: 'Pixel 8',
      kind: DeviceKind.phone,
      platform: 'android',
      addresses: ['192.168.1.88'],
      port: 53520,
      trusted: false,
    ),
  ];

  final Duration discoveryInterval;
  final Duration latency;
  final String expectedPin;
  final int maxPinAttempts;

  final _events = StreamController<NodeEvent>.broadcast();
  final List<DeviceInfo> _pending;
  final Map<String, DeviceInfo> _visible = {};
  final Map<String, DeviceInfo> _trusted;
  final Map<String, _FakeSession> _sessions = {};
  final List<Timer> _timers = [];
  NodeConfig? _config;
  int _nextSession = 0;

  /// Every signalling payload sent through [sendSignal], for assertions.
  final List<String> sentSignals = [];

  /// Number of [respondToRequest] calls that accepted, for assertions.
  int acceptedRequests = 0;

  @override
  Stream<NodeEvent> get events => _events.stream;

  void _emit(NodeEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _later(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      action();
    });
    _timers.add(timer);
  }

  @override
  Future<void> start(NodeConfig config) async {
    _config = config;
    for (var i = 0; i < _pending.length; i++) {
      final peer = _pending[i];
      _later(discoveryInterval * (i + 1), () {
        _visible[peer.id] = _withTrust(peer);
        _emit(NodeEvent.peerFound(peer: _visible[peer.id]!));
      });
    }
  }

  DeviceInfo _withTrust(DeviceInfo p) => DeviceInfo(
    id: p.id,
    name: p.name,
    kind: p.kind,
    platform: p.platform,
    addresses: p.addresses,
    port: p.port,
    trusted: _trusted.containsKey(p.id),
  );

  @override
  Future<LocalIdentity> localIdentity() async {
    final config = _config;
    if (config == null) throw StateError('node not started');
    return LocalIdentity(
      id: 'fake-local',
      name: config.deviceName,
      port: 53520,
      addresses: const ['192.168.1.10'],
    );
  }

  @override
  Future<void> stop() async {
    for (final t in List.of(_timers)) {
      t.cancel();
    }
    _timers.clear();
    _visible.clear();
    _config = null;
  }

  @override
  Future<void> setDiscoverable(bool discoverable) async {}

  @override
  Future<void> renameDevice(String name) async {
    final config = _config;
    if (config == null) return;
    _config = NodeConfig(
      deviceName: name,
      deviceKind: config.deviceKind,
      platform: config.platform,
      storageDir: config.storageDir,
      discoverable: config.discoverable,
      port: config.port,
    );
  }

  @override
  Future<List<DeviceInfo>> listPeers() async => _visible.values.toList();

  @override
  Future<DeviceInfo> connectManual(String address) async {
    await Future<void>.delayed(latency);
    final host = address.split(':').first;
    final known = _visible.values.where((p) => p.addresses.contains(host));
    if (known.isNotEmpty) return known.first;
    if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
      throw ArgumentError.value(address, 'address', 'unreachable');
    }
    final peer = DeviceInfo(
      id: 'fake-manual-$host',
      name: 'LocalScreen @ $host',
      kind: DeviceKind.desktop,
      platform: 'linux',
      addresses: [host],
      port: 53520,
      trusted: false,
    );
    _visible[peer.id] = peer;
    _emit(NodeEvent.peerFound(peer: peer));
    return peer;
  }

  String _newSessionId() => 'fake-session-${_nextSession++}';

  @override
  Future<String> requestSession(String peerId, ShareMode mode) async {
    final peer = _visible[peerId] ?? _trusted[peerId];
    if (peer == null) throw ArgumentError.value(peerId, 'peerId', 'unknown peer');
    final id = _newSessionId();
    final session = _FakeSession(peer: peer, mode: mode, attemptsLeft: maxPinAttempts);
    _sessions[id] = session;
    _later(latency, () {
      if (!_sessions.containsKey(id)) return;
      if (_trusted.containsKey(peerId)) {
        _establish(id, SessionRole.host);
      } else {
        _emit(NodeEvent.pinRequired(sessionId: id));
      }
    });
    return id;
  }

  void _establish(String id, SessionRole role) {
    final s = _sessions[id];
    if (s == null) return;
    s.established = true;
    _emit(NodeEvent.sessionEstablished(sessionId: id, peer: s.peer, role: role, mode: s.mode));
  }

  @override
  Future<void> submitPin(String sessionId, String pin) async {
    final s = _sessions[sessionId];
    if (s == null) throw StateError('no such session');
    _later(latency, () {
      if (!_sessions.containsKey(sessionId)) return;
      if (pin == expectedPin) {
        _trusted[s.peer.id] = s.peer;
        if (_visible.containsKey(s.peer.id)) {
          _visible[s.peer.id] = _withTrust(s.peer);
          _emit(NodeEvent.peerFound(peer: _visible[s.peer.id]!));
        }
        _establish(sessionId, SessionRole.host);
        return;
      }
      s.attemptsLeft--;
      if (s.attemptsLeft <= 0) {
        _close(sessionId, CloseReason.pinFailed);
      } else {
        _emit(NodeEvent.pinRejected(sessionId: sessionId, attemptsLeft: s.attemptsLeft));
      }
    });
  }

  @override
  Future<void> respondToRequest(String sessionId, {required bool accept}) async {
    if (!_sessions.containsKey(sessionId)) throw StateError('no such session');
    if (accept) acceptedRequests++;
    _later(latency ~/ 2, () {
      if (accept) {
        _establish(sessionId, SessionRole.display);
      } else {
        _close(sessionId, CloseReason.declined);
      }
    });
  }

  @override
  Future<void> sendSignal(String sessionId, String payload) async {
    sentSignals.add(payload);
  }

  @override
  Future<void> closeSession(String sessionId) async {
    _later(Duration.zero, () => _close(sessionId, CloseReason.localHangup));
  }

  void _close(String id, CloseReason reason) {
    if (_sessions.remove(id) == null) return;
    _emit(NodeEvent.sessionClosed(sessionId: id, reason: reason));
  }

  @override
  Future<List<DeviceInfo>> listTrusted() async => [for (final p in _trusted.values) _withTrust(p)];

  @override
  Future<void> forgetTrusted(String id) async {
    _trusted.remove(id);
    final peer = _visible[id];
    if (peer != null) {
      _visible[id] = _withTrust(peer);
      _emit(NodeEvent.peerFound(peer: _visible[id]!));
    }
  }

  /// Display side: simulates [from] asking to use this device as a screen.
  ///
  /// With [withPin] the request carries [demoPin]; if [autoPairAfter] is set
  /// the simulated host "types" it after that delay. Returns the session id.
  String simulateIncomingRequest({
    DeviceInfo? from,
    bool withPin = true,
    ShareMode mode = ShareMode.mirror,
    Duration? autoPairAfter,
  }) {
    final host = from ?? demoHost;
    final id = _newSessionId();
    _sessions[id] = _FakeSession(peer: host, mode: mode, attemptsLeft: maxPinAttempts);
    _emit(
      NodeEvent.incomingRequest(
        sessionId: id,
        peer: host,
        mode: mode,
        pin: withPin ? expectedPin : null,
      ),
    );
    if (withPin && autoPairAfter != null) {
      _later(autoPairAfter, () => _establish(id, SessionRole.display));
    }
    return id;
  }

  /// Simulates the remote side ending [sessionId].
  void simulateRemoteHangup(String sessionId) => _close(sessionId, CloseReason.remoteHangup);

  /// The host used by [simulateIncomingRequest] by default.
  static const demoHost = DeviceInfo(
    id: 'fake-ubuntu',
    name: 'Ubuntu 工作站',
    kind: DeviceKind.desktop,
    platform: 'linux',
    addresses: ['192.168.1.5'],
    port: 53520,
    trusted: false,
  );

  @override
  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}

class _FakeSession {
  _FakeSession({required this.peer, required this.mode, required this.attemptsLeft});

  final DeviceInfo peer;
  final ShareMode mode;
  int attemptsLeft;
  bool established = false;
}
