/// An accumulated APRS telemetry definition for one station.
///
/// A complete definition arrives as four independent messages (PARM/UNIT/EQNS/
/// BITS, APRS 1.0.1 §13), often minutes apart and any subset may be missing.
/// [TelemetryService] merges each [TelemetryDefinitionPacket] component into
/// the per-station aggregate held here; partial definitions are the normal
/// case. Channel indices 0–4 are the analog channels; 5–12 are the eight binary
/// channels.
library;

import '../core/packet/aprs_packet.dart';

class TelemetryDefinition {
  TelemetryDefinition({
    required this.station,
    required this.updatedAt,
    List<String>? parameterNames,
    List<String>? units,
    List<double?>? coefficients,
    List<bool>? bitSense,
    this.projectTitle,
  }) : parameterNames = parameterNames ?? const [],
       units = units ?? const [],
       coefficients = coefficients ?? const [],
       bitSense = bitSense ?? const [];

  /// Correlation key: the described station, trimmed + upper-cased with the
  /// SSID preserved (telemetry is SSID-specific).
  final String station;

  /// PARM channel names (up to 13: 5 analog + 8 binary). May be empty.
  List<String> parameterNames;

  /// UNIT labels, parallel to [parameterNames]. May be empty.
  List<String> units;

  /// EQNS coefficients as a flat list (conventionally 5 channels × `a,b,c`).
  /// A null entry marks an unparseable field. May be empty.
  List<double?> coefficients;

  /// BITS 8-bit sense mask (MSB first). May be empty.
  List<bool> bitSense;

  /// Optional project title from the BITS component.
  String? projectTitle;

  /// Last time any component of this definition was heard.
  DateTime updatedAt;

  /// True when nothing useful has been captured yet.
  bool get isEmpty =>
      parameterNames.isEmpty &&
      units.isEmpty &&
      coefficients.isEmpty &&
      bitSense.isEmpty &&
      projectTitle == null;

  /// Channel name at [index] (0-based over all 13 channels), or null if not
  /// defined / blank.
  String? nameAt(int index) {
    if (index < 0 || index >= parameterNames.length) return null;
    final n = parameterNames[index].trim();
    return n.isEmpty ? null : n;
  }

  /// Unit label at [index], or null if not defined / blank.
  String? unitAt(int index) {
    if (index < 0 || index >= units.length) return null;
    final u = units[index].trim();
    return u.isEmpty ? null : u;
  }

  /// Applies the EQNS scaling for analog channel [channel] (0–4):
  /// `value = a·raw² + b·raw + c`. Missing or unparseable coefficients fall
  /// back to identity (a=0, b=1, c=0), so a channel with no EQNS returns [raw]
  /// unchanged.
  double scaleAnalog(int channel, double raw) {
    final base = channel * 3;
    final a = _coeff(base) ?? 0.0;
    final b = _coeff(base + 1) ?? 1.0;
    final c = _coeff(base + 2) ?? 0.0;
    return a * raw * raw + b * raw + c;
  }

  /// True when an EQNS scaling other than the identity is defined for analog
  /// channel [channel] — i.e. applying [scaleAnalog] would change the raw value
  /// for some inputs. Used by the UI to decide whether to show "raw → scaled".
  bool hasScaling(int channel) {
    final base = channel * 3;
    final a = _coeff(base);
    final b = _coeff(base + 1);
    final c = _coeff(base + 2);
    if (a != null && a != 0) return true;
    if (b != null && b != 1) return true;
    if (c != null && c != 0) return true;
    return false;
  }

  double? _coeff(int i) =>
      (i >= 0 && i < coefficients.length) ? coefficients[i] : null;

  /// Merges one decoded definition component into this aggregate, bumping
  /// [updatedAt]. Only the field(s) carried by [packet] are replaced.
  void applyComponent(TelemetryDefinitionPacket packet) {
    switch (packet.kind) {
      case TelemetryDefinitionKind.parm:
        parameterNames = List.of(packet.labels);
      case TelemetryDefinitionKind.unit:
        units = List.of(packet.labels);
      case TelemetryDefinitionKind.eqns:
        coefficients = List.of(packet.coefficients);
      case TelemetryDefinitionKind.bits:
        bitSense = List.of(packet.bitSense);
        projectTitle = packet.projectTitle;
    }
    if (packet.receivedAt.isAfter(updatedAt)) updatedAt = packet.receivedAt;
  }
}
