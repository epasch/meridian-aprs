import 'package:drift/drift.dart';

import '../core/packet/aprs_packet.dart';
import '../core/packet/station.dart';
import '../models/bulletin.dart';
import '../models/message_category.dart';
import '../models/message_status.dart';
import 'converters/bulletin_transports_converter.dart';
import 'daos/bulletin_dao.dart';
import 'daos/message_dao.dart';
import 'daos/packet_dao.dart';
import 'daos/station_dao.dart';
import 'daos/telemetry_definition_dao.dart';
import 'tables/bulletins.dart';
import 'tables/conversations.dart';
import 'tables/group_message_entries.dart';
import 'tables/message_entries.dart';
import 'tables/outgoing_bulletins.dart';
import 'tables/packets.dart';
import 'tables/position_history.dart';
import 'tables/stations.dart';
import 'tables/telemetry_definitions.dart';

part 'meridian_database.g.dart';

@DriftDatabase(
  tables: [
    Stations,
    PositionHistory,
    Packets,
    Conversations,
    MessageEntries,
    GroupMessageEntries,
    Bulletins,
    OutgoingBulletins,
    TelemetryDefinitions,
  ],
  daos: [
    StationDao,
    PacketDao,
    MessageDao,
    BulletinDao,
    TelemetryDefinitionDao,
  ],
)
class MeridianDatabase extends _$MeridianDatabase {
  MeridianDatabase(super.executor);

  MeridianDatabase.connect(DatabaseConnection super.connection) : super();

  // v1 → v2 (Unit 2, ADR-070): added the telemetry_definitions table. This is
  // the app's first schema migration — it must be strictly additive and
  // non-destructive (existing installs carry real packet/message/station data).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX position_history_callsign_timestamp '
        'ON position_history(callsign, timestamp)',
      );
      await customStatement(
        'CREATE INDEX packets_received_at ON packets(received_at)',
      );
      await customStatement(
        'CREATE INDEX packets_source_callsign '
        'ON packets(source_callsign)',
      );
      await customStatement(
        'CREATE INDEX message_entries_conversation_peer_timestamp '
        'ON message_entries(conversation_peer, timestamp)',
      );
      await customStatement(
        'CREATE INDEX group_message_entries_group_name_timestamp '
        'ON group_message_entries(group_name, timestamp)',
      );
      await customStatement(
        'CREATE INDEX bulletins_last_heard_at ON bulletins(last_heard_at)',
      );
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2: telemetry_definitions table (additive; no data touched).
      if (from < 2) {
        await m.createTable(telemetryDefinitions);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
