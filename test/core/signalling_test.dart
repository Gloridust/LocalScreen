import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:localscreen/core/media/signalling.dart';

void main() {
  group('SignalMessage', () {
    test('offer and answer round-trip with the documented wire format', () {
      const offer = SdpSignal.offer('v=0\r\no=- 1 2 IN IP4 127.0.0.1');
      final wire = jsonDecode(offer.encode()) as Map<String, Object?>;
      expect(wire, {'type': 'offer', 'sdp': offer.sdp});
      expect(SignalMessage.decode(offer.encode()), offer);

      const answer = SdpSignal.answer('v=0');
      expect(jsonDecode(answer.encode())['type'], 'answer');
      expect(SignalMessage.decode(answer.encode()), answer);
    });

    test('candidate keeps mid and line index', () {
      const c = CandidateSignal(
        candidate: 'candidate:1 1 udp 2122260223 192.168.1.5 54321 typ host',
        sdpMid: '0',
        sdpMLineIndex: 0,
      );
      final decoded = SignalMessage.decode(c.encode());
      expect(decoded, c);
      expect(decoded, isA<CandidateSignal>());
    });

    test('candidate tolerates missing optional fields', () {
      final decoded = SignalMessage.decode('{"type":"candidate","candidate":"x"}');
      expect(decoded, const CandidateSignal(candidate: 'x'));
    });

    test('control carries an action and value', () {
      const c = ControlSignal(action: ControlSignal.quality, value: 'clear');
      expect(jsonDecode(c.encode()), {'type': 'control', 'action': 'quality', 'value': 'clear'});
      expect(SignalMessage.decode(c.encode()), c);
    });

    test('rejects malformed payloads with FormatException', () {
      for (final bad in [
        'not json',
        '[1,2]',
        '{"type":"offer"}',
        '{"type":"wat","sdp":"x"}',
        '{"type":"candidate","candidate":5}',
      ]) {
        expect(() => SignalMessage.decode(bad), throwsFormatException, reason: bad);
      }
    });
  });
}
