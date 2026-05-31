import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meridian_aprs/database/meridian_database.dart';

/// First-ever schema migration (v1 → v2, ADR-070): the only change is the
/// additive `telemetry_definitions` table. These tests pin the behaviour
/// because every future migration builds on this `onUpgrade` precedent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v1 → v2 onUpgrade creates telemetry_definitions and it round-trips',
    () async {
      // Present as a v1 database: stamp user_version = 1 BEFORE drift opens, so
      // drift runs onUpgrade(from: 1, to: 2) — not onCreate. The other v1 tables
      // are irrelevant to this isolated migration check.
      final db = MeridianDatabase(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA user_version = 1'),
        ),
      );

      // Touching the new table forces the migration to run.
      await db.telemetryDefinitionDao.upsert(
        TelemetryDefinitionsCompanion(
          station: const Value('N0CALL-5'),
          parameterNames: const Value('Batt,Temp'),
          equations: const Value('0,0.1,0'),
          updatedAt: const Value(1000),
        ),
      );

      final rows = await db.telemetryDefinitionDao.getAll();
      expect(rows, hasLength(1));
      expect(rows.first.station, equals('N0CALL-5'));
      expect(rows.first.parameterNames, equals('Batt,Temp'));
      expect(rows.first.units, isNull); // unheard component stays null

      await db.close();
    },
  );

  test(
    'fresh onCreate database is at schemaVersion 2 with the table present',
    () async {
      final db = MeridianDatabase(NativeDatabase.memory());
      // A brand-new DB runs onCreate (createAll) — the table must exist.
      final rows = await db.telemetryDefinitionDao.getAll();
      expect(rows, isEmpty);
      expect(db.schemaVersion, equals(2));
      await db.close();
    },
  );
}
