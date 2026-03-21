import 'dart:async';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:meridian_aprs/core/transport/kiss_framer.dart';

/// Feed [bytes] into [framer] and collect up to [count] emitted frames.
///
/// Drains the microtask queue after feeding so synchronous StreamController
/// events are flushed before the subscription is cancelled.
Future<List<Uint8List>> feedAndCollect(
  KissFramer framer,
  List<int> bytes, {
  int count = 1,
}) async {
  final frames = <Uint8List>[];
  final sub = framer.frames.listen(frames.add);
  framer.addBytes(bytes);
  // Drain the microtask queue so broadcast-stream events are delivered.
  await Future<void>.delayed(Duration.zero);
  await sub.cancel();
  return frames;
}

void main() {
  group('KissFramer', () {
    late KissFramer framer;

    setUp(() {
      framer = KissFramer();
    });

    tearDown(() {
      framer.dispose();
    });

    // -------------------------------------------------------------------------
    // addBytes — decoding
    // -------------------------------------------------------------------------

    test('decodes a basic data frame', () async {
      // FEND  CMD   A     B     C    FEND
      final input = [0xC0, 0x00, 0x41, 0x42, 0x43, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, hasLength(1));
      expect(frames[0], equals([0x41, 0x42, 0x43]));
    });

    test('decodes FEND escaped in data (FESC TFEND → 0xC0)', () async {
      // FEND  CMD   FESC  TFEND  FEND
      final input = [0xC0, 0x00, 0xDB, 0xDC, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, hasLength(1));
      expect(frames[0], equals([0xC0]));
    });

    test('decodes FESC escaped in data (FESC TFESC → 0xDB)', () async {
      // FEND  CMD   FESC  TFESC  FEND
      final input = [0xC0, 0x00, 0xDB, 0xDD, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, hasLength(1));
      expect(frames[0], equals([0xDB]));
    });

    test('ignores bytes before first FEND', () async {
      // Garbage  FEND  CMD   A    FEND
      final input = [0x01, 0x02, 0x03, 0xC0, 0x00, 0x41, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, hasLength(1));
      expect(frames[0], equals([0x41]));
    });

    test('discards non-data command frames (cmd 0x01)', () async {
      // FEND  CMD=1  AA    BB   FEND
      final input = [0xC0, 0x01, 0xAA, 0xBB, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, isEmpty);
    });

    test('decodes back-to-back frames', () async {
      // FEND  CMD  A  FEND | FEND  CMD  B  FEND
      final input = [0xC0, 0x00, 0x41, 0xC0, 0xC0, 0x00, 0x42, 0xC0];
      final frames = await feedAndCollect(framer, input, count: 2);

      expect(frames, hasLength(2));
      expect(frames[0], equals([0x41]));
      expect(frames[1], equals([0x42]));
    });

    test('discards empty payload (only command byte)', () async {
      // FEND  CMD  FEND — payload after stripping cmd byte is empty
      final input = [0xC0, 0x00, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, isEmpty);
    });

    test('discards frame with invalid escape sequence', () async {
      // FEND  CMD  FESC  0x41(invalid)  FEND — 0x41 is not TFEND or TFESC
      final input = [0xC0, 0x00, 0xDB, 0x41, 0xC0];
      final frames = await feedAndCollect(framer, input);

      expect(frames, isEmpty);
    });

    test('handles data split across multiple addBytes calls', () async {
      final frames = <Uint8List>[];
      final sub = framer.frames.listen(frames.add);

      framer.addBytes([0xC0, 0x00, 0x41]); // frame open, partial payload
      framer.addBytes([0x42, 0xC0]); // close frame
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(frames, hasLength(1));
      expect(frames[0], equals([0x41, 0x42]));
    });

    // -------------------------------------------------------------------------
    // encode (static)
    // -------------------------------------------------------------------------

    test('encode wraps payload with FEND and command byte', () {
      final encoded = KissFramer.encode(Uint8List.fromList([0x41, 0x42]));
      expect(encoded, equals([0xC0, 0x00, 0x41, 0x42, 0xC0]));
    });

    test('encode escapes FEND (0xC0) in payload', () {
      final encoded = KissFramer.encode(Uint8List.fromList([0xC0]));
      expect(encoded, equals([0xC0, 0x00, 0xDB, 0xDC, 0xC0]));
    });

    test('encode escapes FESC (0xDB) in payload', () {
      final encoded = KissFramer.encode(Uint8List.fromList([0xDB]));
      expect(encoded, equals([0xC0, 0x00, 0xDB, 0xDD, 0xC0]));
    });

    test('encode+decode round-trip preserves payload', () async {
      final payload = Uint8List.fromList([0x00, 0xC0, 0xDB, 0xFF, 0x7E]);
      final encoded = KissFramer.encode(payload);
      final frames = await feedAndCollect(framer, encoded);

      expect(frames, hasLength(1));
      expect(frames[0], equals(payload));
    });
  });
}
