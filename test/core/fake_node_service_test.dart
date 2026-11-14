import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/core/node/node_service.dart';

const _config = NodeConfig(
  deviceName: 'Test',
  deviceKind: DeviceKind.laptop,
  platform: 'linux',
  storageDir: '/tmp',
  discoverable: true,
  port: 0,
);

void main() {
  test('peers appear one by one', () {
    fakeAsync((async) {
      final node = FakeNodeService(discoveryInterval: const Duration(seconds: 1));
      final found = <String>[];
      node.events.listen((e) {
        if (e is NodeEvent_PeerFound) found.add(e.peer.id);
      });
      node.start(_config);
      async.elapse(const Duration(milliseconds: 1500));
      expect(found, hasLength(1));
      async.elapse(const Duration(seconds: 5));
      expect(found, hasLength(FakeNodeService.demoPeers.length));
      node.dispose();
    });
  });

  test('untrusted peer: PIN required, wrong PIN rejected, right PIN establishes', () {
    fakeAsync((async) {
      final node = FakeNodeService(
        discoveryInterval: Duration.zero,
        latency: const Duration(milliseconds: 10),
      );
      final events = <NodeEvent>[];
      node.events.listen(events.add);
      node.start(_config);
      async.elapse(const Duration(milliseconds: 50));
      late String id;
      node.requestSession('fake-xiaomi-pad', ShareMode.mirror).then((v) => id = v);
      async.elapse(const Duration(milliseconds: 20));
      expect(events.last, isA<NodeEvent_PinRequired>());

      node.submitPin(id, '000000');
      async.elapse(const Duration(milliseconds: 20));
      expect(events.last, NodeEvent.pinRejected(sessionId: id, attemptsLeft: 4));

      node.submitPin(id, FakeNodeService.demoPin);
      async.elapse(const Duration(milliseconds: 20));
      final established = events.whereType<NodeEvent_SessionEstablished>().single;
      expect(established.role, SessionRole.host);
      expect(events.whereType<NodeEvent_PeerFound>().last.peer.trusted, isTrue);
      node.dispose();
    });
  });

  test('five wrong PINs close the session', () {
    fakeAsync((async) {
      final node = FakeNodeService(discoveryInterval: Duration.zero, latency: Duration.zero);
      final events = <NodeEvent>[];
      node.events.listen(events.add);
      node.start(_config);
      async.elapse(const Duration(milliseconds: 1));
      late String id;
      node.requestSession('fake-pixel', ShareMode.mirror).then((v) => id = v);
      async.elapse(const Duration(milliseconds: 1));
      for (var i = 0; i < 5; i++) {
        node.submitPin(id, '111111');
        async.elapse(const Duration(milliseconds: 1));
      }
      expect(events.last, NodeEvent.sessionClosed(sessionId: id, reason: CloseReason.pinFailed));
      node.dispose();
    });
  });
}
