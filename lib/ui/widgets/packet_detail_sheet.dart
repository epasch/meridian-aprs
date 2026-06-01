import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/packet/aprs_packet.dart';
import '../../models/telemetry_definition.dart';
import '../../services/telemetry_service.dart';
import 'aprs_symbol_widget.dart';

/// Shows a modal bottom sheet with the full decoded detail of an [AprsPacket].
///
/// Usage:
/// ```dart
/// showPacketDetailSheet(context, packet);
/// ```
void showPacketDetailSheet(BuildContext context, AprsPacket packet) {
  // Resolve the telemetry definition here, where the provider is in scope, so
  // the sheet itself stays a pure presentation widget. Only data reports need
  // one; the lookup correlates the report's source with a stored definition.
  TelemetryDefinition? definition;
  if (packet is TelemetryPacket) {
    definition = context.read<TelemetryService>().definitionFor(packet.source);
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => PacketDetailSheet(packet: packet, definition: definition),
  );
}

class PacketDetailSheet extends StatelessWidget {
  const PacketDetailSheet({super.key, required this.packet, this.definition});

  final AprsPacket packet;

  /// Telemetry definition correlated to [packet] (only for [TelemetryPacket]);
  /// null when none has been heard, in which case channels render raw.
  final TelemetryDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final fields = decodedFields(packet, definition);
    final symbol = _symbolFor(packet);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header row: symbol + callsign + close button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  if (symbol case (final st, final sc)) ...[
                    AprsSymbolWidget(symbolTable: st, symbolCode: sc, size: 24),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      packet.source,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              // Eager `ListView(children:)` is intentional (#58): a single
              // packet decodes to a small, bounded set of text rows (~25 max
              // for a fully-populated weather/Mic-E packet) shown once in a
              // modal sheet. Lazy building would add complexity for no gain.
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Raw packet line
                  _SectionLabel(label: 'Raw packet', colorScheme: colorScheme),
                  const SizedBox(height: 4),
                  SelectableText(
                    packet.rawLine,
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Decoded fields
                  _SectionLabel(
                    label: 'Decoded fields',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 4),
                  ...fields.entries.map(
                    (e) =>
                        _FieldRow(label: e.key, value: e.value, theme: theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns (symbolTable, symbolCode) for packet types that carry a symbol,
  /// or null for those that do not.
  (String, String)? _symbolFor(AprsPacket p) {
    return switch (p) {
      PositionPacket() => (p.symbolTable, p.symbolCode),
      WeatherPacket() => (p.symbolTable, p.symbolCode),
      ObjectPacket() => (p.symbolTable, p.symbolCode),
      ItemPacket() => (p.symbolTable, p.symbolCode),
      MicEPacket() => (p.symbolTable, p.symbolCode),
      _ => null,
    };
  }

  /// Builds an ordered map of label → value for all meaningful decoded fields.
  ///
  /// [definition] is consulted only for [TelemetryPacket]s, to label and scale
  /// channels; null renders raw values. Exposed for testing so the
  /// telemetry-labelling logic can be asserted without pumping the lazy
  /// scroll view.
  @visibleForTesting
  static Map<String, String> decodedFields(
    AprsPacket p,
    TelemetryDefinition? definition,
  ) {
    final m = <String, String>{};

    // Common header fields
    m['Source'] = p.source;
    m['Destination'] = p.destination;
    m['Direction'] = p.isOutgoing ? 'Outgoing' : 'Incoming';
    m[p.isOutgoing ? 'Sent via' : 'Received via'] = _transportLabel(
      p.transportSource,
    );
    if (!p.isOutgoing && _isRf(p.transportSource)) {
      // Show only digipeaters that actually relayed this packet (H-bit set,
      // i.e. trailing '*' in the reconstructed path). Unused entries describe
      // the requested route, not the route taken.
      final usedDigis = p.path.where((d) => d.endsWith('*')).toList();
      if (usedDigis.isEmpty) {
        m['Heard'] = 'Direct from ${p.source}';
      } else {
        m['Heard via'] = [p.source, ...usedDigis].join(' → ');
      }
    } else if (p.path.isNotEmpty) {
      m['Path'] = p.path.join(', ');
    }
    if (p.thirdPartyVia != null) {
      m['Relayed via'] = p.thirdPartyVia!;
    }
    m['Received'] = p.receivedAt
        .toLocal()
        .toString()
        .replaceFirst('.000', '')
        .replaceAll('T', ' ');

    switch (p) {
      case PositionPacket():
        m['Type'] = 'Position';
        m['Latitude'] = _formatLat(p.lat);
        m['Longitude'] = _formatLon(p.lon);
        m['Symbol table'] = p.symbolTable;
        m['Symbol code'] = p.symbolCode;
        if (p.course != null) m['Course'] = '${p.course}\u00b0';
        if (p.speed != null) m['Speed'] = '${p.speed!.toStringAsFixed(1)} kt';
        if (p.altitude != null) {
          m['Altitude'] = '${p.altitude!.toStringAsFixed(0)} m';
        }
        m['Messaging'] = p.hasMessaging ? 'Yes' : 'No';
        if (p.device != null) m['Device'] = p.device!;
        if (p.comment.isNotEmpty) m['Comment'] = p.comment;
        if (p.timestamp != null) {
          m['Packet time'] = p.timestamp!.toLocal().toString();
        }

      case MessagePacket():
        m['Type'] = 'Message';
        m['Addressee'] = p.addressee;
        m['Message'] = p.message;
        if (p.messageId != null) m['Message ID'] = p.messageId!;

      case WeatherPacket():
        m['Type'] = 'Weather';
        if (p.lat != null) m['Latitude'] = _formatLat(p.lat!);
        if (p.lon != null) m['Longitude'] = _formatLon(p.lon!);
        if (p.temperature != null) {
          final c = (p.temperature! - 32) * 5 / 9;
          m['Temperature'] =
              '${p.temperature!.toStringAsFixed(1)} \u00b0F (${c.toStringAsFixed(1)} \u00b0C)';
        }
        if (p.humidity != null) m['Humidity'] = '${p.humidity}%';
        if (p.pressure != null) {
          m['Pressure'] = '${p.pressure!.toStringAsFixed(1)} hPa';
        }
        if (p.windSpeed != null) {
          m['Wind speed'] = '${p.windSpeed!.toStringAsFixed(1)} mph';
        }
        if (p.windDirection != null) {
          m['Wind direction'] = '${p.windDirection}\u00b0';
        }
        if (p.windGust != null) {
          m['Wind gust'] = '${p.windGust!.toStringAsFixed(1)} mph';
        }
        if (p.rainfall1h != null) {
          m['Rainfall 1h'] = '${(p.rainfall1h! / 100).toStringAsFixed(2)} in';
        }
        if (p.rainfall24h != null) {
          m['Rainfall 24h'] = '${(p.rainfall24h! / 100).toStringAsFixed(2)} in';
        }
        if (p.timestamp != null) {
          m['Packet time'] = p.timestamp!.toLocal().toString();
        }

      case ObjectPacket():
        m['Type'] = 'Object';
        m['Object name'] = p.objectName;
        m['Latitude'] = _formatLat(p.lat);
        m['Longitude'] = _formatLon(p.lon);
        m['Symbol table'] = p.symbolTable;
        m['Symbol code'] = p.symbolCode;
        m['Alive'] = p.isAlive ? 'Yes' : 'No (killed)';
        if (p.device != null) m['Device'] = p.device!;
        if (p.comment.isNotEmpty) m['Comment'] = p.comment;

      case ItemPacket():
        m['Type'] = 'Item';
        m['Item name'] = p.itemName;
        m['Latitude'] = _formatLat(p.lat);
        m['Longitude'] = _formatLon(p.lon);
        m['Symbol table'] = p.symbolTable;
        m['Symbol code'] = p.symbolCode;
        m['Alive'] = p.isAlive ? 'Yes' : 'No (killed)';
        if (p.device != null) m['Device'] = p.device!;
        if (p.comment.isNotEmpty) m['Comment'] = p.comment;

      case StatusPacket():
        m['Type'] = 'Status';
        m['Status'] = p.status;
        if (p.timestamp != null) {
          m['Packet time'] = p.timestamp!.toLocal().toString();
        }

      case MicEPacket():
        m['Type'] = 'Mic-E';
        m['Latitude'] = _formatLat(p.lat);
        m['Longitude'] = _formatLon(p.lon);
        m['Mic-E status'] = p.micEMessage;
        m['Symbol table'] = p.symbolTable;
        m['Symbol code'] = p.symbolCode;
        if (p.course != null) m['Course'] = '${p.course}\u00b0';
        if (p.speed != null) m['Speed'] = '${p.speed!.toStringAsFixed(1)} kt';
        if (p.altitude != null) {
          m['Altitude'] = '${p.altitude!.toStringAsFixed(0)} m';
        }
        if (p.device != null) m['Device'] = p.device!;
        if (p.comment.isNotEmpty) m['Comment'] = p.comment;

      case TelemetryPacket():
        m['Type'] = 'Telemetry';
        if (p.sequence.isNotEmpty) m['Sequence'] = p.sequence;
        final def = definition;
        if (def?.projectTitle != null) m['Project'] = def!.projectTitle!;
        for (var i = 0; i < p.analog.length; i++) {
          final v = p.analog[i];
          // Prefer the defined channel name; otherwise a generic ordinal.
          final name = def?.nameAt(i) ?? 'Analog ${i + 1}';
          final unit = def?.unitAt(i);
          if (v == null) {
            m[name] = '—';
          } else if (def != null && def.hasScaling(i)) {
            // Show the scaled, unit-tagged value with the raw count alongside.
            final scaled = _trimNum(def.scaleAnalog(i, v));
            final tagged = unit == null ? scaled : '$scaled $unit';
            m[name] = '$tagged (raw ${_trimNum(v)})';
          } else {
            final raw = _trimNum(v);
            m[name] = unit == null ? raw : '$raw $unit';
          }
        }
        if (p.digital.isNotEmpty) {
          m['Digital bits'] = p.digital.map((b) => b ? '1' : '0').join();
          // Per-bit names live at definition channels 5–12.
          for (var i = 0; i < p.digital.length; i++) {
            final name = def?.nameAt(5 + i);
            if (name != null) m[name] = p.digital[i] ? 'on' : 'off';
          }
        }
        if (p.comment != null && p.comment!.isNotEmpty) {
          m['Comment'] = p.comment!;
        }

      case TelemetryDefinitionPacket():
        m['Type'] = 'Telemetry definition';
        m['Defines'] = p.addressee;
        switch (p.kind) {
          case TelemetryDefinitionKind.parm:
            m['Component'] = 'Parameter names';
            for (var i = 0; i < p.labels.length; i++) {
              if (p.labels[i].isNotEmpty) m['Channel ${i + 1}'] = p.labels[i];
            }
          case TelemetryDefinitionKind.unit:
            m['Component'] = 'Units';
            for (var i = 0; i < p.labels.length; i++) {
              if (p.labels[i].isNotEmpty) m['Channel ${i + 1}'] = p.labels[i];
            }
          case TelemetryDefinitionKind.eqns:
            m['Component'] = 'Equations';
            m['Coefficients'] = p.coefficients
                .map((c) => c == null ? '—' : _trimNum(c))
                .join(', ');
          case TelemetryDefinitionKind.bits:
            m['Component'] = 'Bit sense';
            if (p.bitSense.isNotEmpty) {
              m['Sense mask'] = p.bitSense.map((b) => b ? '1' : '0').join();
            }
            if (p.projectTitle != null) m['Project'] = p.projectTitle!;
        }

      case QueryPacket():
        m['Type'] = 'Query';
        if (p.query.isNotEmpty) m['Query'] = p.query;

      case CapabilitiesPacket():
        m['Type'] = 'Capabilities';
        if (p.capabilities.isNotEmpty) m['Capabilities'] = p.capabilities;

      case UnknownPacket():
        m['Type'] = 'Unknown';
        m['Reason'] = p.reason;
        if (p.rawInfo.isNotEmpty) m['Raw info'] = p.rawInfo;
    }

    return m;
  }
}

bool _isRf(PacketSource src) =>
    src == PacketSource.bleTnc ||
    src == PacketSource.serialTnc ||
    src == PacketSource.classicBtTnc ||
    src == PacketSource.tnc;

String _transportLabel(PacketSource src) => switch (src) {
  PacketSource.aprsIs => 'Internet (APRS-IS)',
  PacketSource.bleTnc => 'RF (BLE TNC)',
  PacketSource.serialTnc => 'RF (Serial TNC)',
  PacketSource.classicBtTnc => 'RF (Classic BT)',
  PacketSource.tnc => 'RF (TNC)',
};

String _formatLat(double lat) {
  final dir = lat >= 0 ? 'N' : 'S';
  return '${lat.abs().toStringAsFixed(6)}\u00b0 $dir';
}

String _formatLon(double lon) {
  final dir = lon >= 0 ? 'E' : 'W';
  return '${lon.abs().toStringAsFixed(6)}\u00b0 $dir';
}

/// Formats a telemetry value as an integer when it has no fractional part.
String _trimNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: colorScheme.primary,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
