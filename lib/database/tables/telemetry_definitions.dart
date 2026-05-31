import 'package:drift/drift.dart';

/// Accumulated telemetry definitions, one row per described station.
///
/// PARM/UNIT/EQNS/BITS components arrive as separate messages and are merged
/// into a single row (keyed by [station] — the definition addressee, trimmed +
/// upper-cased, SSID preserved). Components are stored as their raw wire
/// payload strings (the part after the keyword) so round-tripping needs no
/// converter: comma-joined for PARM/UNIT/EQNS, the bit-mask run for BITS.
/// A null column means that component has not been heard yet.
///
/// Unlike the packet log, this table is NOT retention-pruned: definitions are
/// slowly-changing and must outlive the packet window so channels stay
/// labelled across restarts.
@DataClassName('TelemetryDefinitionRow')
class TelemetryDefinitions extends Table {
  TextColumn get station => text()();

  /// PARM labels, comma-joined (`Battery,Temp,...`).
  TextColumn get parameterNames => text().named('parameter_names').nullable()();

  /// UNIT labels, comma-joined.
  TextColumn get units => text().nullable()();

  /// EQNS coefficients, comma-joined (`0,0.075,0,...`).
  TextColumn get equations => text().nullable()();

  /// BITS sense mask as transmitted (`10110000`).
  TextColumn get bitSense => text().named('bit_sense').nullable()();

  /// BITS project title, verbatim.
  TextColumn get projectTitle => text().named('project_title').nullable()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {station};
}
