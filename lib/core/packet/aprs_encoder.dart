/// APRS packet text encoder.
///
/// Produces APRS-IS formatted strings from structured data. Pure Dart — no
/// platform imports. Used by [BeaconingService] and [MessageService] to
/// construct outgoing packets before they are dispatched via [TxService].
library;

/// Encodes APRS packets to the wire text format used on APRS-IS and in the
/// info field of AX.25 UI frames.
class AprsEncoder {
  AprsEncoder._();

  // TODO(tocall): register APZMDN with WB4APR before v1.0
  static const _dest = 'APZMDN';

  // -------------------------------------------------------------------------
  // Position
  // -------------------------------------------------------------------------

  /// Encodes an uncompressed APRS position packet.
  ///
  /// Returns a full APRS-IS line including the header, e.g.:
  /// `W1AW-9>APZMDN,TCPIP*:=4903.50N/07201.75W>Comment`
  ///
  /// [callsign] must be 3–7 uppercase alphanumeric characters.
  /// [ssid] 0–15; omitted from header when 0.
  /// [symbolTable] is `'/'` (primary) or `'\\'` (alternate).
  /// [symbolCode] is the single APRS symbol character.
  /// [hasMessaging] selects DTI `=` (true) vs `!` (false).
  static String encodePosition({
    required String callsign,
    required int ssid,
    required double lat,
    required double lon,
    required String symbolTable,
    required String symbolCode,
    String comment = '',
    bool hasMessaging = true,
  }) {
    final src = _formatAddress(callsign, ssid);
    final dti = hasMessaging ? '=' : '!';
    final latStr = _encodeLat(lat);
    final lonStr = _encodeLon(lon);
    return '$src>$_dest,TCPIP*:$dti$latStr$symbolTable$lonStr$symbolCode$comment';
  }

  // -------------------------------------------------------------------------
  // Message
  // -------------------------------------------------------------------------

  /// Encodes an APRS message packet (APRS spec §14).
  ///
  /// Returns a full APRS-IS line, e.g.:
  /// `W1AW-9>APZMDN::WB4APR   :Hello there{001`
  ///
  /// [toCallsign] is padded/truncated to 9 characters per spec.
  /// [messageId] is appended as `{id}` when non-null and non-empty.
  static String encodeMessage({
    required String fromCallsign,
    required int fromSsid,
    required String toCallsign,
    required String text,
    String? messageId,
  }) {
    final src = _formatAddress(fromCallsign, fromSsid);
    final addressee = _padAddressee(toCallsign);
    final idSuffix = (messageId != null && messageId.isNotEmpty)
        ? '{$messageId'
        : '';
    return '$src>$_dest::$addressee:$text$idSuffix';
  }

  /// Encodes an APRS ACK packet.
  ///
  /// Returns a full APRS-IS line, e.g.:
  /// `W1AW-9>APZMDN::WB4APR   :ack001`
  static String encodeAck({
    required String fromCallsign,
    required int fromSsid,
    required String toCallsign,
    required String messageId,
  }) {
    final src = _formatAddress(fromCallsign, fromSsid);
    final addressee = _padAddressee(toCallsign);
    return '$src>$_dest::$addressee:ack$messageId';
  }

  /// Encodes an APRS REJ packet.
  static String encodeRej({
    required String fromCallsign,
    required int fromSsid,
    required String toCallsign,
    required String messageId,
  }) {
    final src = _formatAddress(fromCallsign, fromSsid);
    final addressee = _padAddressee(toCallsign);
    return '$src>$_dest::$addressee:rej$messageId';
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String _formatAddress(String callsign, int ssid) =>
      ssid == 0 ? callsign.toUpperCase() : '${callsign.toUpperCase()}-$ssid';

  /// Pads or truncates [callsign] to exactly 9 characters (APRS spec §14).
  static String _padAddressee(String callsign) =>
      callsign.toUpperCase().padRight(9).substring(0, 9);

  /// Encodes latitude to `DDMM.HHN` or `DDMM.HHS` format.
  static String _encodeLat(double lat) {
    final hemi = lat >= 0 ? 'N' : 'S';
    final abs = lat.abs();
    final deg = abs.truncate();
    final min = (abs - deg) * 60.0;
    return '${deg.toString().padLeft(2, '0')}${_formatMinutes(min)}$hemi';
  }

  /// Encodes longitude to `DDDMM.HHE` or `DDDMM.HHW` format.
  static String _encodeLon(double lon) {
    final hemi = lon >= 0 ? 'E' : 'W';
    final abs = lon.abs();
    final deg = abs.truncate();
    final min = (abs - deg) * 60.0;
    return '${deg.toString().padLeft(3, '0')}${_formatMinutes(min)}$hemi';
  }

  /// Formats decimal minutes as `MM.HH` (2 integer digits, 2 decimal digits).
  static String _formatMinutes(double min) {
    final intPart = min.truncate().toString().padLeft(2, '0');
    final fracPart = ((min - min.truncate()) * 100)
        .truncate()
        .toString()
        .padLeft(2, '0');
    return '$intPart.$fracPart';
  }
}
