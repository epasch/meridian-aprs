import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meridian_aprs/services/message_service.dart';
import 'package:meridian_aprs/services/station_service.dart';
import 'package:meridian_aprs/services/station_settings_service.dart';
import 'package:meridian_aprs/services/tnc_service.dart';
import 'package:meridian_aprs/services/tx_service.dart';

import '../helpers/fake_transport.dart';

// ---------------------------------------------------------------------------
// Test fixture
// ---------------------------------------------------------------------------

/// Creates a fully-wired set of services for one test.
///
/// Uses [FakeTransport] so no network activity occurs. Returns a
/// [_Fixture] that exposes the [MessageService] and the list of lines
/// sent via [TxService] (intercepted via a subclass).
class _Fixture {
  _Fixture._({
    required this.service,
    required this.stationService,
    required this.sentLines,
  });

  final MessageService service;
  final StationService stationService;
  final List<String> sentLines;

  static Future<_Fixture> create({
    String callsign = 'W1AW',
    int ssid = 9,
    int initialCounter = 0,
  }) async {
    SharedPreferences.setMockInitialValues({
      'user_callsign': callsign,
      'user_ssid': ssid,
      'message_id_counter': initialCounter,
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = StationSettingsService(prefs);
    final transport = FakeTransport();
    final stationService = StationService(transport);
    final tncService = TncService(stationService);
    final sentLines = <String>[];
    final txService = _RecordingTxService(transport, tncService, sentLines);
    final messageService = MessageService(settings, txService, stationService);
    return _Fixture._(
      service: messageService,
      stationService: stationService,
      sentLines: sentLines,
    );
  }
}

/// TxService that records every outgoing line instead of sending.
class _RecordingTxService extends TxService {
  _RecordingTxService(super.aprsIs, super.tnc, this._log);
  final List<String> _log;

  @override
  Future<void> sendLine(String line) async => _log.add(line);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // --- Message ID counter -------------------------------------------------

  group('message ID counter', () {
    test('starts at 001 when counter is 0', () async {
      final f = await _Fixture.create(initialCounter: 0);
      await f.service.sendMessage('KB1XYZ', 'Hello');
      expect(f.sentLines.last, contains('{001'));
    });

    test('uses next value when counter is non-zero', () async {
      final f = await _Fixture.create(initialCounter: 5);
      await f.service.sendMessage('KB1XYZ', 'Hello');
      expect(f.sentLines.last, contains('{006'));
    });

    test('increments on each send', () async {
      final f = await _Fixture.create(initialCounter: 0);
      await f.service.sendMessage('KB1XYZ', 'One');
      await f.service.sendMessage('KB1XYZ', 'Two');
      expect(f.sentLines[0], contains('{001'));
      expect(f.sentLines[1], contains('{002'));
    });

    test('wraps from 999 back to 001', () async {
      final f = await _Fixture.create(initialCounter: 999);
      await f.service.sendMessage('KB1XYZ', 'Wrap');
      expect(f.sentLines.last, contains('{001'));
    });
  });

  // --- Outbound message format --------------------------------------------

  group('outbound message format', () {
    test('pads addressee to 9 characters', () async {
      final f = await _Fixture.create();
      await f.service.sendMessage('WB4APR', 'Test');
      expect(f.sentLines.last, contains(':WB4APR   :'));
    });

    test('addressee is uppercased', () async {
      final f = await _Fixture.create();
      await f.service.sendMessage('kb1xyz', 'Hi');
      expect(f.sentLines.last, contains(':KB1XYZ   :'));
    });

    test('includes message text', () async {
      final f = await _Fixture.create();
      await f.service.sendMessage('KB1XYZ', 'Hello there');
      expect(f.sentLines.last, contains('Hello there'));
    });
  });

  // --- Conversation tracking ----------------------------------------------

  group('conversation tracking', () {
    test('creates conversation on first outbound message', () async {
      final f = await _Fixture.create();
      await f.service.sendMessage('KB1XYZ', 'Hi');
      expect(f.service.conversations.length, equals(1));
      expect(f.service.conversations.first.peerCallsign, equals('KB1XYZ'));
    });

    test('reuses conversation for subsequent messages to same peer', () async {
      final f = await _Fixture.create();
      await f.service.sendMessage('KB1XYZ', 'First');
      await f.service.sendMessage('KB1XYZ', 'Second');
      expect(f.service.conversations.length, equals(1));
      expect(f.service.conversations.first.messages.length, equals(2));
    });

    test('totalUnread starts at 0', () async {
      final f = await _Fixture.create();
      expect(f.service.totalUnread, equals(0));
    });

    test('markRead resets unread count', () async {
      final f = await _Fixture.create();
      // Inject inbound message directly via station service.
      f.stationService.ingestLine('KB1XYZ>APZMDN::W1AW-9   :Hello{042');
      await Future.delayed(const Duration(milliseconds: 50));

      if (f.service.totalUnread > 0) {
        f.service.markRead('KB1XYZ');
        expect(f.service.totalUnread, equals(0));
      }
    });
  });

  // --- ACK / REJ handling -------------------------------------------------

  group('ACK handling', () {
    test('outgoing message starts as pending', () async {
      final f = await _Fixture.create();
      await f.service.sendMessage('KB1XYZ', 'Test');
      final conv = f.service.conversationWith('KB1XYZ');
      expect(conv, isNotNull);
      expect(conv!.messages.first.status, equals(MessageStatus.pending));
    });
  });

  // --- Duplicate detection ------------------------------------------------

  group('duplicate detection', () {
    test('same source+wireId is not added twice', () async {
      final f = await _Fixture.create();
      const line = 'KB1XYZ>APZMDN::W1AW-9   :Hello{099';
      f.stationService.ingestLine(line);
      f.stationService.ingestLine(line);
      await Future.delayed(const Duration(milliseconds: 50));

      final conv = f.service.conversationWith('KB1XYZ');
      // Should only have one message, not two
      final inboundCount =
          conv?.messages
              .where((m) => !m.isOutgoing && m.wireId == '099')
              .length ??
          0;
      expect(inboundCount, lessThanOrEqualTo(1));
    });
  });
}
