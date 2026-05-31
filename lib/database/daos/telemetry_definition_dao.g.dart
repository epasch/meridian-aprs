// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telemetry_definition_dao.dart';

// ignore_for_file: type=lint
mixin _$TelemetryDefinitionDaoMixin on DatabaseAccessor<MeridianDatabase> {
  $TelemetryDefinitionsTable get telemetryDefinitions =>
      attachedDatabase.telemetryDefinitions;
  TelemetryDefinitionDaoManager get managers =>
      TelemetryDefinitionDaoManager(this);
}

class TelemetryDefinitionDaoManager {
  final _$TelemetryDefinitionDaoMixin _db;
  TelemetryDefinitionDaoManager(this._db);
  $$TelemetryDefinitionsTableTableManager get telemetryDefinitions =>
      $$TelemetryDefinitionsTableTableManager(
        _db.attachedDatabase,
        _db.telemetryDefinitions,
      );
}
