import 'package:flutter_test/flutter_test.dart';

import 'package:meridian_aprs/services/station_service.dart';
import 'package:meridian_aprs/services/telemetry_service.dart';

import '../helpers/test_database.dart';

/// Drives [TelemetryService] by feeding raw lines through a real
/// [StationService] (whose parser produces the typed packets), mirroring the
/// production wiring.
Future<({StationService stations, TelemetryService telemetry})>
_buildFixture() async {
  final db = buildTestDatabase();
  final stations = StationService(
    stationDao: db.stationDao,
    packetDao: db.packetDao,
  );
  final telemetry = TelemetryService(
    stations: stations,
    dao: db.telemetryDefinitionDao,
  );
  await telemetry.load();
  addTearDown(() async {
    telemetry.dispose();
    await stations.stop();
    await db.close();
  });
  return (stations: stations, telemetry: telemetry);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TelemetryService — accumulation', () {
    test(
      'merges PARM/UNIT/EQNS/BITS into one per-station definition',
      () async {
        final f = await _buildFixture();
        f.stations
          ..ingestLine('N0CALL-5>APRS::N0CALL-5 :PARM.Batt,Temp,Solar')
          ..ingestLine('N0CALL-5>APRS::N0CALL-5 :UNIT.Volts,degF,Watts')
          ..ingestLine('N0CALL-5>APRS::N0CALL-5 :EQNS.0,0.1,0,0,1,0')
          ..ingestLine('N0CALL-5>APRS::N0CALL-5 :BITS.11000000,Shack');
        await _settle();

        final def = f.telemetry.definitionFor('N0CALL-5');
        expect(def, isNotNull);
        expect(def!.nameAt(0), equals('Batt'));
        expect(def.unitAt(1), equals('degF'));
        expect(def.projectTitle, equals('Shack'));
        expect(def.bitSense.first, isTrue);
      },
    );

    test(
      'correlation keeps the SSID (data source matches definition)',
      () async {
        final f = await _buildFixture();
        f.stations.ingestLine('N0CALL-9>APRS::N0CALL-9 :PARM.Speed');
        await _settle();

        // A different SSID must NOT share the definition.
        expect(f.telemetry.definitionFor('N0CALL-9'), isNotNull);
        expect(f.telemetry.definitionFor('N0CALL-1'), isNull);
        // Lookup is case-insensitive and trims.
        expect(f.telemetry.definitionFor(' n0call-9 '), isNotNull);
      },
    );

    test('a later component updates only its own field', () async {
      final f = await _buildFixture();
      f.stations.ingestLine('N0CALL-5>APRS::N0CALL-5 :PARM.A,B,C');
      await _settle();
      f.stations.ingestLine('N0CALL-5>APRS::N0CALL-5 :PARM.X,Y,Z');
      await _settle();

      final def = f.telemetry.definitionFor('N0CALL-5')!;
      expect(def.parameterNames, equals(['X', 'Y', 'Z']));
    });
  });

  group('TelemetryService — EQNS scaling', () {
    test('applies a·v² + b·v + c per analog channel', () async {
      final f = await _buildFixture();
      // ch0: 0,0.075,0 → linear ×0.075 ; ch1: 1,0,0 → square
      f.stations.ingestLine('N0CALL-5>APRS::N0CALL-5 :EQNS.0,0.075,0,1,0,0');
      await _settle();

      final def = f.telemetry.definitionFor('N0CALL-5')!;
      expect(def.scaleAnalog(0, 200), closeTo(15.0, 1e-9));
      expect(def.scaleAnalog(1, 4), closeTo(16.0, 1e-9));
      expect(def.hasScaling(0), isTrue);
    });

    test('channels without coefficients fall back to identity', () async {
      final f = await _buildFixture();
      f.stations.ingestLine('N0CALL-5>APRS::N0CALL-5 :EQNS.0,2,0');
      await _settle();

      final def = f.telemetry.definitionFor('N0CALL-5')!;
      // ch0 scales ×2; ch3 has no coeffs → returns the raw value unchanged.
      expect(def.scaleAnalog(0, 5), closeTo(10.0, 1e-9));
      expect(def.scaleAnalog(3, 42), closeTo(42.0, 1e-9));
      expect(def.hasScaling(3), isFalse);
    });
  });

  group('TelemetryService — persistence', () {
    test('definitions survive a restart on the same database', () async {
      final db = buildTestDatabase();
      final stations = StationService(
        stationDao: db.stationDao,
        packetDao: db.packetDao,
      );
      final first = TelemetryService(
        stations: stations,
        dao: db.telemetryDefinitionDao,
      );
      await first.load();
      stations
        ..ingestLine('N0CALL-5>APRS::N0CALL-5 :PARM.Batt,Temp')
        ..ingestLine('N0CALL-5>APRS::N0CALL-5 :EQNS.0,0.1,0');
      await _settle();
      first.dispose();

      // New service over the SAME db — load() must restore the definition.
      final second = TelemetryService(
        stations: stations,
        dao: db.telemetryDefinitionDao,
      );
      await second.load();

      final def = second.definitionFor('N0CALL-5');
      expect(def, isNotNull);
      expect(def!.nameAt(0), equals('Batt'));
      expect(def.scaleAnalog(0, 100), closeTo(10.0, 1e-9));

      second.dispose();
      await stations.stop();
      await db.close();
    });
  });
}
