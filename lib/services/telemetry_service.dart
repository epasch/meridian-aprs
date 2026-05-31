/// Accumulates APRS telemetry definitions (PARM/UNIT/EQNS/BITS) per station so
/// that telemetry *data* reports can be shown with channel labels, units, and
/// EQNS scaling (ADR-070).
///
/// Definitions arrive as four independent messages, often minutes apart, with
/// any subset present. The parser yields a [TelemetryDefinitionPacket] per
/// component (kept out of the message/conversation pipeline). This service
/// merges them into a per-station [TelemetryDefinition] aggregate, write-through
/// to drift so labels survive restarts and the packet-log retention window.
///
/// Correlation: a definition's `addressee` is the described station; a data
/// report's `source` is matched against it (both trimmed + upper-cased, SSID
/// preserved — telemetry is SSID-specific). Mirrors the [BulletinService]
/// pattern: an in-memory cache written through to drift, with a synchronous
/// [definitionFor] lookup for the UI.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../core/packet/aprs_packet.dart';
import '../core/util/clock.dart';
import '../database/daos/telemetry_definition_dao.dart';
import '../database/meridian_database.dart'
    show TelemetryDefinitionRow, TelemetryDefinitionsCompanion;
import '../models/telemetry_definition.dart';
import 'station_service.dart';

class TelemetryService extends ChangeNotifier {
  TelemetryService({
    required StationService stations,
    required TelemetryDefinitionDao dao,
    Clock clock = DateTime.now,
  }) : _dao = dao,
       _clock = clock {
    _sub = stations.packetStream.listen(_onPacket);
  }

  final TelemetryDefinitionDao _dao;
  final Clock _clock;
  StreamSubscription<AprsPacket>? _sub;

  final Map<String, TelemetryDefinition> _defs = {};

  /// Restores persisted definitions into the in-memory cache. Call once at
  /// startup before the UI reads [definitionFor].
  Future<void> load() async {
    final rows = await _dao.getAll();
    _defs.clear();
    for (final row in rows) {
      _defs[row.station] = _fromRow(row);
    }
    notifyListeners();
  }

  /// The accumulated definition for [callsign] (a data report's source), or
  /// null if none has been heard. Normalizes to match the stored key.
  TelemetryDefinition? definitionFor(String callsign) =>
      _defs[_normalize(callsign)];

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _onPacket(AprsPacket packet) {
    if (packet is! TelemetryDefinitionPacket) return;
    final key = _normalize(packet.addressee);
    if (key.isEmpty) return;

    final def = _defs[key] ??= TelemetryDefinition(
      station: key,
      updatedAt: _clock(),
    );
    def.applyComponent(packet);
    _dao.upsert(_toCompanion(def)); // ignore: unawaited_futures
    notifyListeners();
  }

  static String _normalize(String callsign) => callsign.trim().toUpperCase();

  // --- (de)serialization -----------------------------------------------------

  TelemetryDefinitionsCompanion _toCompanion(TelemetryDefinition d) {
    return TelemetryDefinitionsCompanion(
      station: Value(d.station),
      parameterNames: Value(
        d.parameterNames.isEmpty ? null : d.parameterNames.join(','),
      ),
      units: Value(d.units.isEmpty ? null : d.units.join(',')),
      equations: Value(
        d.coefficients.isEmpty
            ? null
            : d.coefficients.map((c) => c?.toString() ?? '').join(','),
      ),
      bitSense: Value(
        d.bitSense.isEmpty ? null : d.bitSense.map((b) => b ? '1' : '0').join(),
      ),
      projectTitle: Value(d.projectTitle),
      updatedAt: Value(d.updatedAt.millisecondsSinceEpoch),
    );
  }

  TelemetryDefinition _fromRow(TelemetryDefinitionRow row) {
    return TelemetryDefinition(
      station: row.station,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      parameterNames: row.parameterNames?.split(','),
      units: row.units?.split(','),
      coefficients: row.equations
          ?.split(',')
          .map((s) => s.isEmpty ? null : double.tryParse(s))
          .toList(),
      bitSense: row.bitSense == null
          ? null
          : [for (final c in row.bitSense!.split('')) c == '1'],
      projectTitle: row.projectTitle,
    );
  }
}
