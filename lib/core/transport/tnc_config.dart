import 'tnc_preset.dart';

/// Runtime TNC configuration for a serial port connection.
///
/// Derived from a [TncPreset] via [TncConfig.fromPreset], or built directly
/// for custom parameters. Serializable to/from SharedPreferences via
/// [toPrefsMap] and [fromPrefsMap].
class TncConfig {
  const TncConfig({
    required this.port,
    required this.baudRate,
    this.dataBits = 8,
    this.stopBits = 1,
    this.parity = 'none',
    this.hardwareFlowControl = false,
    this.kissTxDelayMs = 50,
    this.kissPersistence = 63,
    this.kissSlotTimeMs = 10,
    this.presetId,
  });

  final String port;
  final int baudRate;
  final int dataBits;
  final int stopBits;

  /// Parity: 'none' | 'odd' | 'even'
  final String parity;
  final bool hardwareFlowControl;

  /// KISS TX delay in milliseconds. Default: 50.
  final int kissTxDelayMs;

  /// KISS persistence value (0–255). Default: 63.
  final int kissPersistence;

  /// KISS slot time in milliseconds. Default: 10.
  final int kissSlotTimeMs;

  /// The preset id this config was derived from, or null for custom.
  final String? presetId;

  /// Build a [TncConfig] from a [TncPreset] and a port name.
  factory TncConfig.fromPreset(TncPreset preset, {required String port}) {
    return TncConfig(
      port: port,
      baudRate: preset.baudRate,
      dataBits: preset.dataBits,
      stopBits: preset.stopBits,
      parity: preset.parity,
      hardwareFlowControl: preset.hardwareFlowControl,
      presetId: preset.id,
    );
  }

  /// Serialize to a flat Map suitable for SharedPreferences storage.
  Map<String, Object> toPrefsMap() {
    return {
      'tnc_port': port,
      'tnc_baud': baudRate,
      'tnc_data_bits': dataBits,
      'tnc_stop_bits': stopBits,
      'tnc_parity': parity,
      'tnc_hw_flow': hardwareFlowControl,
      'tnc_kiss_tx_delay': kissTxDelayMs,
      'tnc_kiss_persistence': kissPersistence,
      'tnc_kiss_slot_time': kissSlotTimeMs,
      // ignore: use_null_aware_elements
      if (presetId != null) 'tnc_preset_id': presetId!,
    };
  }

  /// Deserialize from SharedPreferences map. Returns null if `tnc_port` is
  /// absent or empty (i.e. no config has been saved yet).
  static TncConfig? fromPrefsMap(Map<String, Object?> map) {
    final port = map['tnc_port'] as String?;
    if (port == null || port.isEmpty) return null;
    return TncConfig(
      port: port,
      baudRate: (map['tnc_baud'] as int?) ?? 9600,
      dataBits: (map['tnc_data_bits'] as int?) ?? 8,
      stopBits: (map['tnc_stop_bits'] as int?) ?? 1,
      parity: (map['tnc_parity'] as String?) ?? 'none',
      hardwareFlowControl: (map['tnc_hw_flow'] as bool?) ?? false,
      kissTxDelayMs: (map['tnc_kiss_tx_delay'] as int?) ?? 50,
      kissPersistence: (map['tnc_kiss_persistence'] as int?) ?? 63,
      kissSlotTimeMs: (map['tnc_kiss_slot_time'] as int?) ?? 10,
      presetId: map['tnc_preset_id'] as String?,
    );
  }
}
