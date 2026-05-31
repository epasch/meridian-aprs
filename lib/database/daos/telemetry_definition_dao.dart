import 'package:drift/drift.dart';

import '../meridian_database.dart';
import '../tables/telemetry_definitions.dart';

part 'telemetry_definition_dao.g.dart';

@DriftAccessor(tables: [TelemetryDefinitions])
class TelemetryDefinitionDao extends DatabaseAccessor<MeridianDatabase>
    with _$TelemetryDefinitionDaoMixin {
  TelemetryDefinitionDao(super.db);

  /// Upsert keyed by `station` — a new component for a known station updates
  /// the existing row rather than appending.
  Future<void> upsert(TelemetryDefinitionsCompanion def) =>
      into(telemetryDefinitions).insertOnConflictUpdate(def);

  /// One-shot read of every stored definition. Used by [load] at startup.
  Future<List<TelemetryDefinitionRow>> getAll() =>
      select(telemetryDefinitions).get();

  Future<void> clearAll() => delete(telemetryDefinitions).go();
}
