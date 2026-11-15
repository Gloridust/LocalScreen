// Exercises extend mode against a real GNOME session: the virtual monitor,
// the monitor arrangement around it, and the direct capture into WebRTC.
//
// It rearranges monitors, so run it only inside a disposable session (for
// example `gnome-shell --headless --virtual-monitor 1920x1080
// --virtual-monitor 2560x1440` on its own D-Bus), never on a desktop in use:
//
//     LS_GNOME_SANDBOX=1 flutter test integration_test/extend_capture_test.dart -d linux
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:localscreen/core/media/captured_screen.dart';
import 'package:localscreen/core/media/media_session.dart';
import 'package:localscreen/core/media/quality.dart';
import 'package:localscreen/core/media/screen_capture.dart';
import 'package:localscreen/core/media/webrtc_media_session.dart';
import 'package:localscreen/core/node/node_service.dart';
import 'package:localscreen/core/platform/linux/monitor_layout.dart';
import 'package:localscreen/core/platform/linux/mutter_display_config.dart';
import 'package:localscreen/core/platform/linux/mutter_monitor_capture.dart';
import 'package:localscreen/core/platform/linux/mutter_virtual_display.dart';
import 'package:localscreen/core/platform/virtual_display.dart';
import 'package:localscreen/features/session/session_controller.dart';

/// How many frames [receiver] has decoded.
Future<int> _decoded(RTCPeerConnection receiver) async {
  for (final report in await receiver.getStats()) {
    if (report.type != 'inbound-rtp' || report.values['kind'] != 'video') continue;
    return (report.values['framesDecoded'] as num?)?.toInt() ?? 0;
  }
  return 0;
}

/// Sends [captured] over a loopback connection and returns the receiving end.
Future<(RTCPeerConnection, RTCPeerConnection)> _loopback(CapturedScreen captured) async {
  const configuration = <String, dynamic>{'iceServers': <Object>[], 'sdpSemantics': 'unified-plan'};
  final sender = await createPeerConnection(configuration);
  final receiver = await createPeerConnection(configuration);
  sender.onIceCandidate = receiver.addCandidate;
  receiver.onIceCandidate = sender.addCandidate;
  await sender.addTransceiver(
    track: captured.stream.getVideoTracks().first,
    kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
    init: RTCRtpTransceiverInit(
      direction: TransceiverDirection.SendOnly,
      streams: [captured.stream],
    ),
  );
  final offer = await sender.createOffer();
  await sender.setLocalDescription(offer);
  await receiver.setRemoteDescription(offer);
  final answer = await receiver.createAnswer();
  await receiver.setLocalDescription(answer);
  await sender.setRemoteDescription(answer);
  return (sender, receiver);
}

/// Waits until [receiver] has decoded frames, then checks they keep coming
/// although nothing on the screen changes.
Future<void> _expectSteadyPicture(RTCPeerConnection receiver) async {
  var frames = await _decoded(receiver);
  for (var i = 0; i < 100 && frames == 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    frames = await _decoded(receiver);
  }
  expect(frames, greaterThan(0), reason: 'no frame was decoded');
  await Future<void>.delayed(const Duration(seconds: 3));
  expect(
    await _decoded(receiver),
    greaterThan(frames + 10),
    reason: 'a still screen stalled the video',
  );
}

/// Carries signalling between two controllers in this process, standing in
/// for the encrypted channel between two devices.
class _Wire implements NodeService {
  late final SessionController other;

  @override
  Future<void> sendSignal(String sessionId, String payload) => other.handleSignal(payload);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _device = DeviceInfo(
  id: 'tablet',
  name: 'Tablet',
  kind: DeviceKind.tablet,
  platform: 'android',
  addresses: ['127.0.0.1'],
  port: 53520,
  trusted: true,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['LS_GNOME_SANDBOX'] == '1';
  // Needs LS_GNOME_SANDBOX=1 inside a disposable GNOME session.
  final skip = !enabled;

  late DBusClient client;
  late MutterDisplayConfig config;
  late List<LogicalMonitor> arranged;

  /// A portrait monitor at a fractional scale beside a landscape primary,
  /// like a real multi-monitor desk.
  Future<void> arrangeDesk() async {
    final layout = await config.current();
    expect(layout.monitors.length, 2, reason: 'the sandbox needs exactly two monitors');
    final big = layout.monitors.reduce((a, b) => a.width >= b.width ? a : b);
    final small = layout.monitors.firstWhere((m) => m != big);
    final scale = big.supportedScales.firstWhere((s) => s > 1.2 && s < 1.3, orElse: () => 1);
    final portraitWidth = (big.height / scale).round();
    arranged = [
      LogicalMonitor(
        x: 0,
        y: 0,
        scale: scale,
        transform: 3,
        primary: false,
        connectors: [big.connector],
      ),
      LogicalMonitor(
        x: portraitWidth,
        y: 400,
        scale: 1,
        transform: 0,
        primary: true,
        connectors: [small.connector],
      ),
    ];
    await config.apply(layout, arranged);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(sameArrangement((await config.current()).logical, arranged), isTrue);
  }

  setUpAll(() async {
    if (!enabled) return;
    client = DBusClient.session();
    config = MutterDisplayConfig(client);
    await arrangeDesk();
  });

  tearDownAll(() async {
    if (enabled) await client.close();
  });

  testWidgets('extend keeps the desk arranged and streams the new monitor', (tester) async {
    final placements = InMemoryPlacementStore();
    final provider = MutterVirtualDisplayProvider(placements: placements);
    expect(await provider.isSupported(), isTrue);

    // First connection: everything stays put, the new monitor goes right.
    var display = await provider.create(
      size: const ScreenSize(1920, 1080),
      refreshRate: 60,
      placementKey: 'tablet',
    );
    addTearDown(() => display.dispose());
    var layout = await config.current();
    final virtual = layout.monitor(display.label!)!;
    expect((virtual.width, virtual.height), (1920, 1080));
    for (final monitor in arranged) {
      expect(layout.logical, contains(monitor), reason: 'a monitor moved: ${layout.logical}');
    }
    final primary = arranged.last;
    expect(layout.logicalFor(display.label!)!.x, primary.x + 1920);
    expect(layout.logicalFor(display.label!)!.y, primary.y);

    // Its own picture arrives without any picker, and keeps arriving.
    final (sender, receiver) = await _loopback(display.capture!);
    await _expectSteadyPicture(receiver);
    expect(display.capture!.size, (1920, 1080));
    await sender.close();
    await receiver.close();

    // The user drags it below the primary monitor in Settings.
    final moved = [
      ...arranged,
      LogicalMonitor(
        x: primary.x,
        y: primary.y + 1080,
        scale: 1,
        transform: 0,
        primary: false,
        connectors: [display.label!],
      ),
    ];
    await config.apply(layout, moved);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await display.dispose();
    await display.dispose(); // idempotent
    layout = await config.current();
    expect(layout.monitors.length, 2);
    expect(sameArrangement(layout.logical, arranged), isTrue, reason: '${layout.logical}');
    expect(placements.read('tablet'), const VirtualPlacement(dx: 0, dy: 1080, scale: 1));

    // Second connection: it comes back below the primary monitor.
    display = await provider.create(
      size: const ScreenSize(1920, 1080),
      refreshRate: 60,
      placementKey: 'tablet',
    );
    layout = await config.current();
    expect(
      sameArrangement(layout.logical, [...arranged, moved.last.copyFor(display.label!)]),
      isTrue,
      reason: '${layout.logical}',
    );
    await display.dispose();
    expect(sameArrangement((await config.current()).logical, arranged), isTrue);
  }, skip: skip);

  testWidgets('a whole extend session shows the new monitor on the display', (tester) async {
    final engine = WebRtcMediaEngine(
      capture: ScreenCapture(
        chooser: (_) async => fail('extend must not ask which screen to share'),
        notificationText: () => '',
      ),
    );
    final failures = <MediaFailure>[];
    final toDisplay = _Wire();
    final toHost = _Wire();
    SessionController controller(SessionRole role, NodeService node) => SessionController(
      sessionId: 's1',
      peer: _device,
      role: role,
      mode: ShareMode.extend,
      quality: QualityPreset.balanced,
      media: engine.create(),
      node: node,
      virtualDisplays: MutterVirtualDisplayProvider(placements: InMemoryPlacementStore()),
      localScreen: const ScreenSize(1600, 2560),
      onMediaFailure: failures.add,
      onExtendFallback: () => fail('extend fell back to mirroring'),
    );
    final host = controller(SessionRole.host, toDisplay);
    final display = controller(SessionRole.display, toHost);
    toDisplay.other = display;
    toHost.other = host;
    addTearDown(host.close);
    addTearDown(display.close);

    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: display.buildView(fill: false)),
    );
    await display.start();
    await host.start();
    for (var i = 0; i < 150 && display.phase != MediaPhase.live; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(failures, isEmpty);
    expect(host.phase, MediaPhase.live);
    expect(display.phase, MediaPhase.live, reason: 'the display never got a picture');
    expect(host.mustPickVirtualDisplay, isFalse);

    // The display reported a portrait 1600×2560 screen: a landscape monitor
    // of that size joins the desk, which otherwise stays as it was.
    final layout = await config.current();
    final virtual = layout.monitor(host.virtualDisplayLabel!)!;
    expect((virtual.width, virtual.height), (2560, 1600));
    for (final monitor in arranged) {
      expect(layout.logical, contains(monitor));
    }

    await host.close();
    await display.close();
    expect(sameArrangement((await config.current()).logical, arranged), isTrue);
  }, skip: skip);

  testWidgets('mirror records the chosen monitor without a system dialog', (tester) async {
    final offered = <ScreenOption>[];
    final captured = await const MutterMonitorCapture().open(
      frameRate: 30,
      chooser: (screens) async {
        offered.addAll(screens);
        return screens.firstWhere((s) => s.id == arranged.first.connectors.single);
      },
    );
    expect(offered.length, 2);
    expect(offered.every((s) => s.title != null && s.detail != null), isTrue);

    final (sender, receiver) = await _loopback(captured!);
    await _expectSteadyPicture(receiver);
    // The portrait monitor is sent as it is seen: taller than wide.
    final (width, height) = captured.size!;
    expect(height, greaterThan(width));
    await sender.close();
    await receiver.close();
    for (final track in captured.stream.getTracks()) {
      await track.stop();
    }
    await captured.stream.dispose();
    await captured.close();
  }, skip: skip);
}

extension on LogicalMonitor {
  /// This monitor's geometry for another connector.
  LogicalMonitor copyFor(String connector) => LogicalMonitor(
    x: x,
    y: y,
    scale: scale,
    transform: transform,
    primary: primary,
    connectors: [connector],
  );
}
