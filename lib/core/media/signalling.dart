import 'dart:convert';

/// A signalling message carried as an opaque JSON string by the Rust
/// control channel (`NodeService.sendSignal` / `NodeEvent.signal`).
///
/// Wire format: `{"type": "offer" | "answer" | "candidate" | "control", ...}`.
sealed class SignalMessage {
  const SignalMessage();

  /// The JSON `type` discriminator.
  String get type;

  /// Fields besides `type`.
  Map<String, Object?> get fields;

  /// Serialises to the wire format.
  String encode() => jsonEncode({'type': type, ...fields});

  /// Parses a wire payload. Throws [FormatException] on malformed input.
  static SignalMessage decode(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('signal must be a JSON object');
    }
    final json = decoded;
    String str(String key) {
      final v = json[key];
      if (v is String) return v;
      throw FormatException('signal field "$key" must be a string');
    }

    return switch (json['type']) {
      'offer' => SdpSignal.offer(str('sdp')),
      'answer' => SdpSignal.answer(str('sdp')),
      'candidate' => CandidateSignal(
        candidate: str('candidate'),
        sdpMid: json['sdpMid'] as String?,
        sdpMLineIndex: (json['sdpMLineIndex'] as num?)?.toInt(),
      ),
      'control' => ControlSignal(action: str('action'), value: json['value'] as String?),
      final other => throw FormatException('unknown signal type: $other'),
    };
  }
}

/// SDP offer (host → display) or answer (display → host).
final class SdpSignal extends SignalMessage {
  /// Offer from the host.
  const SdpSignal.offer(this.sdp) : isOffer = true;

  /// Answer from the display.
  const SdpSignal.answer(this.sdp) : isOffer = false;

  final String sdp;
  final bool isOffer;

  @override
  String get type => isOffer ? 'offer' : 'answer';

  @override
  Map<String, Object?> get fields => {'sdp': sdp};

  @override
  bool operator ==(Object other) =>
      other is SdpSignal && other.sdp == sdp && other.isOffer == isOffer;

  @override
  int get hashCode => Object.hash(sdp, isOffer);
}

/// A trickled ICE candidate (LAN host candidates only).
final class CandidateSignal extends SignalMessage {
  /// Creates a candidate message.
  const CandidateSignal({required this.candidate, this.sdpMid, this.sdpMLineIndex});

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  @override
  String get type => 'candidate';

  @override
  Map<String, Object?> get fields => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };

  @override
  bool operator ==(Object other) =>
      other is CandidateSignal &&
      other.candidate == candidate &&
      other.sdpMid == sdpMid &&
      other.sdpMLineIndex == sdpMLineIndex;

  @override
  int get hashCode => Object.hash(candidate, sdpMid, sdpMLineIndex);
}

/// Out-of-band session control, e.g. `{"action": "quality", "value": "clear"}`.
final class ControlSignal extends SignalMessage {
  /// Creates a control message.
  const ControlSignal({required this.action, this.value});

  /// The host switched quality preset; [value] is the preset name.
  static const quality = 'quality';

  /// The display reports its screen size; [value] is `WIDTHxHEIGHT` in
  /// physical pixels. The host sizes its virtual monitor from it.
  static const screen = 'screen';

  /// The display asks for at most [value] frames per second, because it
  /// cannot decode and show more.
  static const pace = 'pace';

  final String action;
  final String? value;

  @override
  String get type => 'control';

  @override
  Map<String, Object?> get fields => {'action': action, 'value': ?value};

  @override
  bool operator ==(Object other) =>
      other is ControlSignal && other.action == action && other.value == value;

  @override
  int get hashCode => Object.hash(action, value);
}
