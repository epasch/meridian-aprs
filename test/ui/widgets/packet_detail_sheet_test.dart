import 'package:flutter_test/flutter_test.dart';

import 'package:meridian_aprs/core/packet/aprs_packet.dart';
import 'package:meridian_aprs/models/telemetry_definition.dart';
import 'package:meridian_aprs/ui/widgets/packet_detail_sheet.dart';

TelemetryPacket _telemetry() => TelemetryPacket(
  rawLine: 'N0CALL-5>APRS:T#014,200,4,0,0,0,11000000',
  source: 'N0CALL-5',
  destination: 'APRS',
  path: const [],
  receivedAt: DateTime.utc(2026, 1, 1),
  sequence: '014',
  analog: const [200, 4, 0, 0, 0],
  digital: const [true, true, false, false, false, false, false, false],
);

void main() {
  group('PacketDetailSheet.decodedFields — telemetry', () {
    test('labels and scales channels when a definition is present', () {
      final def = TelemetryDefinition(
        station: 'N0CALL-5',
        updatedAt: DateTime.utc(2026, 1, 1),
        parameterNames: ['Battery', 'Temp', '', '', '', 'Door'],
        units: ['Volts', 'degF'],
        coefficients: [0, 0.075, 0], // ch0 ×0.075 → 200 = 15
        projectTitle: 'Shack',
      );

      final m = PacketDetailSheet.decodedFields(_telemetry(), def);

      expect(m['Project'], equals('Shack'));
      // Named, scaled, unit-tagged, with the raw count alongside.
      expect(m['Battery'], equals('15 Volts (raw 200)'));
      // Named-but-unscaled channel keeps its unit only.
      expect(m['Temp'], equals('4 degF'));
      // Binary channel name lives at definition index 5.
      expect(m['Door'], equals('on'));
      // A blank PARM slot falls back to the ordinal label.
      expect(m['Analog 3'], equals('0'));
    });

    test('falls back to raw ordinals when no definition is known', () {
      final m = PacketDetailSheet.decodedFields(_telemetry(), null);

      expect(m['Analog 1'], equals('200')); // unscaled raw value
      expect(m['Analog 2'], equals('4'));
      expect(m.containsKey('Battery'), isFalse);
      expect(m['Digital bits'], equals('11000000'));
    });
  });
}
