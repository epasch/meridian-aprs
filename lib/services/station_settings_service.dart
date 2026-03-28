/// Persistent My Station settings.
///
/// Owns the four user-configurable identity fields (callsign, SSID, symbol,
/// comment) that are consumed by [BeaconingService] and [MessageService].
/// Persists changes immediately to [SharedPreferences] on every setter call —
/// there is no Save button.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StationSettingsService extends ChangeNotifier {
  StationSettingsService(this._prefs)
    : _callsign = _prefs.getString(_keyCallsign) ?? '',
      _ssid = _prefs.getInt(_keySsid) ?? 0,
      _symbolTable = _prefs.getString(_keySymbolTable) ?? '/',
      _symbolCode = _prefs.getString(_keySymbolCode) ?? '>',
      _comment = _prefs.getString(_keyComment) ?? '',
      _manualLat = _prefs.getDouble(_keyManualLat),
      _manualLon = _prefs.getDouble(_keyManualLon);

  final SharedPreferences _prefs;

  // SharedPreferences keys — reuse existing keys for callsign/SSID so that
  // values entered during onboarding are reflected here automatically.
  static const _keyCallsign = 'user_callsign';
  static const _keySsid = 'user_ssid';
  static const _keySymbolTable = 'user_symbol_table';
  static const _keySymbolCode = 'user_symbol_code';
  static const _keyComment = 'user_comment';
  static const _keyManualLat = 'user_manual_lat';
  static const _keyManualLon = 'user_manual_lon';

  String _callsign;
  int _ssid;
  String _symbolTable;
  String _symbolCode;
  String _comment;
  double? _manualLat;
  double? _manualLon;

  String get callsign => _callsign;
  int get ssid => _ssid;
  String get symbolTable => _symbolTable;
  String get symbolCode => _symbolCode;
  String get comment => _comment;

  /// Manually entered fallback position. Null if not set.
  double? get manualLat => _manualLat;
  double? get manualLon => _manualLon;
  bool get hasManualPosition => _manualLat != null && _manualLon != null;

  /// Full AX.25 address string, e.g. `W1AW-9` (or `W1AW` when SSID is 0).
  String get fullAddress => _ssid == 0
      ? _callsign.toUpperCase()
      : '${_callsign.toUpperCase()}-$_ssid';

  Future<void> setCallsign(String value) async {
    final v = value.trim().toUpperCase();
    if (v == _callsign) return;
    _callsign = v;
    await _prefs.setString(_keyCallsign, v);
    notifyListeners();
  }

  Future<void> setSsid(int value) async {
    final v = value.clamp(0, 15);
    if (v == _ssid) return;
    _ssid = v;
    await _prefs.setInt(_keySsid, v);
    notifyListeners();
  }

  Future<void> setSymbol(String table, String code) async {
    if (table == _symbolTable && code == _symbolCode) return;
    _symbolTable = table;
    _symbolCode = code;
    await _prefs.setString(_keySymbolTable, table);
    await _prefs.setString(_keySymbolCode, code);
    notifyListeners();
  }

  Future<void> setComment(String value) async {
    // Enforce APRS spec 43-character limit.
    final v = value.length > 43 ? value.substring(0, 43) : value;
    if (v == _comment) return;
    _comment = v;
    await _prefs.setString(_keyComment, v);
    notifyListeners();
  }

  Future<void> setManualPosition(double lat, double lon) async {
    _manualLat = lat;
    _manualLon = lon;
    await _prefs.setDouble(_keyManualLat, lat);
    await _prefs.setDouble(_keyManualLon, lon);
    notifyListeners();
  }

  Future<void> clearManualPosition() async {
    _manualLat = null;
    _manualLon = null;
    await _prefs.remove(_keyManualLat);
    await _prefs.remove(_keyManualLon);
    notifyListeners();
  }
}
