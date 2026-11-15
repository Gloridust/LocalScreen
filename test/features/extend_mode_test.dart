import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/media/fake_media_session.dart';
import 'package:localscreen/core/media/quality.dart';
import 'package:localscreen/core/media/signalling.dart';
import 'package:localscreen/core/node/fake_node_service.dart';
import 'package:localscreen/core/node/node_service.dart';
import 'package:localscreen/core/platform/virtual_display.dart';
import 'package:localscreen/features/session/session_controller.dart';

const _peer = DeviceInfo(
  id: 'pad',
  name: 'Pad',
  kind: DeviceKind.tablet,
  platform: 'android',
  addresses: ['192.168.1.42'],
  port: 53520,
  trusted: true,
);

void main() {
  group('ScreenSize', () {
    test('round-trips through its wire form', () {
      expect(
        ScreenSize.tryParse(const ScreenSize(2560, 1600).encode()),
        const ScreenSize(2560, 1600),
      );
      expect(ScreenSize.tryParse('2560'), isNull);
      expect(ScreenSize.tryParse('0x1600'), isNull);
      expect(ScreenSize.tryParse(null), isNull);
    });

    test('normalizes to landscape, even edges and a sane maximum', () {
      expect(const ScreenSize(1600, 2560).normalized(), const ScreenSize(2560, 1600));
      expect(const ScreenSize(1367, 769).normalized(), const ScreenSize(1366, 768));
      expect(const ScreenSize(7680, 4320).normalized(), const ScreenSize(3840, 2160));
    });
  });

  group('extend mode', () {
    late FakeNodeService node;
    late FakeMediaSession media;
    var fallbacks = 0;

    SessionController controller(
      VirtualDisplayProvider displays, {
      SessionRole role = SessionRole.host,
      ShareMode mode = ShareMode.extend,
      ScreenSize? localScreen,
    }) {
      node = FakeNodeService();
      media = FakeMediaSession(connectDelay: const Duration(milliseconds: 10));
      fallbacks = 0;
      return SessionController(
        sessionId: 's1',
        peer: _peer,
        role: role,
        mode: mode,
        quality: QualityPreset.balanced,
        media: media,
        node: node,
        virtualDisplays: displays,
        localScreen: localScreen,
        onMediaFailure: (_) {},
        onExtendFallback: () => fallbacks++,
      );
    }

    test('host adds a monitor sized like the display and removes it on close', () {
      fakeAsync((async) {
        final displays = FakeVirtualDisplayProvider();
        final c = controller(displays);
        c.start();
        async.flushMicrotasks();
        expect(c.preparingDisplay, isTrue);

        c.handleSignal(
          const ControlSignal(action: ControlSignal.screen, value: '1600x2560').encode(),
        );
        async.elapse(const Duration(milliseconds: 50));
        expect(displays.created, [const ScreenSize(2560, 1600)]);
        // Keyed by the display device, so its monitor returns to its place.
        expect(displays.placementKeys, [c.peer.id]);
        expect(displays.alive, 1);
        expect(c.preparingDisplay, isFalse);
        expect(c.virtualDisplayLabel, isNotNull);

        c.close();
        async.elapse(const Duration(milliseconds: 50));
        expect(displays.alive, 0);
        expect(fallbacks, 0);
      });
    });

    test('host uses a default size when the display never reports one', () {
      fakeAsync((async) {
        final displays = FakeVirtualDisplayProvider();
        final c = controller(displays)..start();
        async.elapse(SessionController.screenReportTimeout + const Duration(milliseconds: 50));
        expect(displays.created, [ScreenSize.fallback]);
        c.close();
        async.flushMicrotasks();
      });
    });

    test('host falls back to mirroring when the monitor cannot be created', () {
      fakeAsync((async) {
        final displays = FakeVirtualDisplayProvider(failing: true);
        final c = controller(displays)..start();
        c.handleSignal(
          const ControlSignal(action: ControlSignal.screen, value: '1920x1080').encode(),
        );
        async.elapse(const Duration(milliseconds: 50));
        expect(fallbacks, 1);
        expect(c.virtualDisplayLabel, isNull);
        c.close();
        async.flushMicrotasks();
      });
    });

    test('mirror mode never creates a monitor', () {
      fakeAsync((async) {
        final displays = FakeVirtualDisplayProvider();
        final c = controller(displays, mode: ShareMode.mirror)..start();
        async.elapse(const Duration(seconds: 2));
        expect(displays.created, isEmpty);
        c.close();
        async.flushMicrotasks();
      });
    });

    test('display reports its screen size to the host', () {
      fakeAsync((async) {
        final c = controller(
          const UnsupportedVirtualDisplayProvider(),
          role: SessionRole.display,
          localScreen: const ScreenSize(2560, 1600),
        )..start();
        async.elapse(const Duration(milliseconds: 50));
        expect(
          node.sentSignals.map(SignalMessage.decode),
          contains(const ControlSignal(action: ControlSignal.screen, value: '2560x1600')),
        );
        c.close();
        async.flushMicrotasks();
      });
    });
  });
}
