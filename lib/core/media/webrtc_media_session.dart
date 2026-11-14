import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'media_session.dart';
import 'media_stats.dart';
import 'quality.dart';
import 'screen_capture.dart';
import 'signalling.dart';

/// [MediaEngine] backed by flutter_webrtc (libwebrtc).
class WebRtcMediaEngine implements MediaEngine {
  /// Creates the engine; [capture] is used by host sessions.
  const WebRtcMediaEngine({required this.capture});

  final ScreenCapture capture;

  @override
  MediaSession create() => WebRtcMediaSession(capture: capture);
}

/// One LAN-only peer connection carrying a single screen video track.
///
/// * No STUN/TURN (`iceServers: []`): only host candidates, traffic stays on
///   the local network.
/// * The host is the offerer and sends one video track send-only; the
///   display is receive-only.
/// * H.264 is preferred, VP8 next, via codec preferences where supported.
class WebRtcMediaSession implements MediaSession {
  /// Creates an idle session.
  WebRtcMediaSession({required this.capture});

  final ScreenCapture capture;

  static const _configuration = <String, dynamic>{
    'iceServers': <Map<String, dynamic>>[],
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  /// How long a `disconnected` state may last before it counts as failure.
  static const _disconnectGrace = Duration(seconds: 6);

  void Function(SignalMessage message) _send = (_) {};
  RTCPeerConnection? _pc;

  /// Completes once [_pc] exists (or the session closed), so signals that
  /// arrive while the peer connection is still being created are not lost.
  final _peerReady = Completer<void>();
  MediaStream? _localStream;
  RTCRtpSender? _sender;
  RTCVideoRenderer? _renderer;
  final _pendingCandidates = <RTCIceCandidate>[];
  bool _remoteDescriptionSet = false;
  bool _isHost = false;
  bool _closed = false;
  QualityPreset _quality = QualityPreset.balanced;
  double _scale = 1;
  Timer? _statsTimer;
  Timer? _disconnectTimer;
  final _sampler = StatsSampler();
  final _stats = StreamController<MediaStats>.broadcast();
  final _rendererReady = ValueNotifier<bool>(false);

  @override
  final phase = ValueNotifier(MediaPhase.idle);

  @override
  MediaFailure? failure;

  @override
  set onSignal(void Function(SignalMessage message) send) => _send = send;

  @override
  Stream<MediaStats> get stats => _stats.stream;

  Future<RTCPeerConnection> _createPeer() async {
    final pc = await createPeerConnection(_configuration);
    pc.onIceCandidate = (candidate) {
      final c = candidate.candidate;
      if (c == null || c.isEmpty) return;
      _send(
        CandidateSignal(
          candidate: c,
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        ),
      );
    };
    pc.onConnectionState = _onConnectionState;
    _pc = pc;
    if (!_peerReady.isCompleted) _peerReady.complete();
    return pc;
  }

  void _onConnectionState(RTCPeerConnectionState state) {
    if (_closed) return;
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _disconnectTimer?.cancel();
        if (_isHost) _setPhase(MediaPhase.live);
        _startStats();
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        _disconnectTimer ??= Timer(_disconnectGrace, () => _fail(MediaFailure.connection));
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _fail(MediaFailure.connection);
      default:
        break;
    }
  }

  void _setPhase(MediaPhase p) {
    if (!_closed && phase.value != MediaPhase.failed) phase.value = p;
  }

  void _fail(MediaFailure reason) {
    if (_closed || phase.value == MediaPhase.failed) return;
    failure = reason;
    phase.value = MediaPhase.failed;
  }

  @override
  Future<void> startHost(QualityPreset quality) async {
    _isHost = true;
    _quality = quality;
    _setPhase(MediaPhase.capturing);
    final MediaStream? stream;
    try {
      stream = await capture.open(frameRate: quality.maxFramerate);
    } catch (e) {
      debugPrint('screen capture failed: $e');
      _fail(MediaFailure.capture);
      return;
    }
    if (stream == null || stream.getVideoTracks().isEmpty || _closed) {
      await stream?.dispose();
      _fail(MediaFailure.capture);
      return;
    }
    _localStream = stream;
    final track = stream.getVideoTracks().first;
    // The user can stop sharing from the system UI (portal, notification).
    track.onEnded = () => _fail(MediaFailure.capture);

    _setPhase(MediaPhase.connecting);
    try {
      final pc = await _createPeer();
      final transceiver = await pc.addTransceiver(
        track: track,
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.SendOnly,
          streams: [stream],
          sendEncodings: [_encodingFor(quality)],
        ),
      );
      _sender = transceiver.sender;
      await _preferCodecs(transceiver);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _send(SdpSignal.offer(offer.sdp!));
      await _applySenderParameters();
    } catch (e) {
      debugPrint('host negotiation failed: $e');
      _fail(MediaFailure.connection);
    }
  }

  RTCRtpEncoding _encodingFor(QualityPreset q) => RTCRtpEncoding(
    minBitrate: q.minBitrate,
    maxBitrate: q.maxBitrate,
    maxFramerate: q.maxFramerate,
    scaleResolutionDownBy: _scale,
  );

  /// Orders codecs H.264 → VP8 → everything else; keeps RTX/RED/FEC.
  Future<void> _preferCodecs(RTCRtpTransceiver transceiver) async {
    try {
      final caps = await getRtpSenderCapabilities('video');
      final codecs = List.of(caps.codecs ?? const <RTCRtpCodecCapability>[]);
      if (codecs.isEmpty) return;
      int rank(RTCRtpCodecCapability c) {
        final mime = c.mimeType.toLowerCase();
        final fmtp = c.sdpFmtpLine ?? '';
        if (mime == 'video/h264') {
          // Packetization mode 1 + constrained baseline decode everywhere.
          final mode1 = fmtp.contains('packetization-mode=1');
          final baseline = fmtp.contains('profile-level-id=42e0');
          return mode1 && baseline ? 0 : (mode1 ? 1 : 2);
        }
        if (mime == 'video/vp8') return 3;
        if (mime == 'video/rtx' || mime == 'video/red' || mime == 'video/ulpfec') return 5;
        return 4;
      }

      final ordered = [
        for (final r in [0, 1, 2, 3, 4, 5]) ...codecs.where((c) => rank(c) == r),
      ];
      await transceiver.setCodecPreferences(ordered);
    } catch (e) {
      // Older platforms: libwebrtc's default order (VP8 first) is fine.
      debugPrint('codec preferences unsupported: $e');
    }
  }

  /// Pushes bitrate / frame-rate / scale / degradation to the encoder.
  Future<void> _applySenderParameters() async {
    final sender = _sender;
    if (sender == null) return;
    final params = sender.parameters;
    final encodings = params.encodings;
    if (encodings == null || encodings.isEmpty) {
      params.encodings = [_encodingFor(_quality)];
    } else {
      final e = encodings.first;
      e.minBitrate = _quality.minBitrate;
      e.maxBitrate = _quality.maxBitrate;
      e.maxFramerate = _quality.maxFramerate;
      e.scaleResolutionDownBy = _scale;
    }
    params.degradationPreference = switch (_quality.degradation) {
      QualityDegradation.maintainFramerate => RTCDegradationPreference.MAINTAIN_FRAMERATE,
      QualityDegradation.maintainResolution => RTCDegradationPreference.MAINTAIN_RESOLUTION,
      QualityDegradation.balanced => RTCDegradationPreference.BALANCED,
    };
    try {
      await sender.setParameters(params);
    } catch (e) {
      debugPrint('setParameters failed: $e');
    }
  }

  @override
  Future<void> applyQuality(QualityPreset quality) async {
    _quality = quality;
    _scale = 1;
    _sourceSize = null;
    await _applySenderParameters();
  }

  @override
  Future<void> startDisplay() async {
    _isHost = false;
    _setPhase(MediaPhase.connecting);
    final renderer = _renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.onFirstFrameRendered = () => _setPhase(MediaPhase.live);
    _rendererReady.value = true;
    final pc = await _createPeer();
    pc.onTrack = (event) async {
      if (event.track.kind != 'video' || _closed) return;
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams.first;
      } else {
        final stream = await createLocalMediaStream('remote-screen');
        await stream.addTrack(event.track);
        renderer.srcObject = stream;
      }
    };
  }

  @override
  Future<void> receive(SignalMessage message) async {
    await _peerReady.future;
    final pc = _pc;
    if (pc == null || _closed) return;
    try {
      switch (message) {
        case SdpSignal(isOffer: true, :final sdp) when !_isHost:
          await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
          await _remoteDescriptionReady();
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          _send(SdpSignal.answer(answer.sdp!));
        case SdpSignal(isOffer: false, :final sdp) when _isHost:
          await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
          await _remoteDescriptionReady();
        case CandidateSignal(:final candidate, :final sdpMid, :final sdpMLineIndex):
          final c = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
          if (_remoteDescriptionSet) {
            await pc.addCandidate(c);
          } else {
            _pendingCandidates.add(c);
          }
        default:
          debugPrint('ignored signal: ${message.type}');
      }
    } catch (e) {
      debugPrint('signal ${message.type} failed: $e');
      _fail(MediaFailure.connection);
    }
  }

  Future<void> _remoteDescriptionReady() async {
    _remoteDescriptionSet = true;
    final pc = _pc!;
    for (final c in _pendingCandidates) {
      await pc.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  (int, int)? _sourceSize;

  void _startStats() {
    _statsTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _pollStats());
  }

  Future<void> _pollStats() async {
    final pc = _pc;
    if (pc == null || _closed) return;
    try {
      final reports = await pc.getStats();
      final entries = [
        for (final r in reports)
          StatsEntry(r.type, r.timestamp / 1000, Map<Object?, Object?>.from(r.values)),
      ];
      if (_isHost) _adaptScale(entries);
      if (!_stats.isClosed) _stats.add(_sampler.sample(entries, inbound: !_isHost));
    } catch (e) {
      debugPrint('getStats failed: $e');
    }
  }

  /// Once the capture size is known, scales it down to the preset's target.
  void _adaptScale(List<StatsEntry> entries) {
    if (_sourceSize != null) return;
    for (final e in entries) {
      if (e.type != 'media-source' || e.values['kind'] == 'audio') continue;
      final w = (e.values['width'] as num?)?.toInt();
      final h = (e.values['height'] as num?)?.toInt();
      if (w == null || h == null || w == 0 || h == 0) continue;
      _sourceSize = (w, h);
      final scale = _quality.scaleFor(w, h);
      if (scale != _scale) {
        _scale = scale;
        unawaited(_applySenderParameters());
      }
      return;
    }
  }

  @override
  Widget buildView({required bool fill}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _rendererReady,
      builder: (context, ready, _) {
        final renderer = _renderer;
        if (!ready || renderer == null) return const SizedBox.expand();
        return RTCVideoView(
          renderer,
          objectFit: fill
              ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
              : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_peerReady.isCompleted) _peerReady.complete();
    _statsTimer?.cancel();
    _disconnectTimer?.cancel();
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final t in stream.getTracks()) {
        await _quietly(t.stop);
      }
      await _quietly(stream.dispose);
    }
    final pc = _pc;
    _pc = null;
    if (pc != null) {
      await _quietly(pc.close);
      await _quietly(pc.dispose);
    }
    final renderer = _renderer;
    _renderer = null;
    _rendererReady.value = false;
    if (renderer != null) {
      renderer.srcObject = null;
      await _quietly(renderer.dispose);
    }
    if (_isHost) await capture.release();
    await _stats.close();
  }

  static Future<void> _quietly(Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      debugPrint('media teardown step failed: $e');
    }
  }
}
