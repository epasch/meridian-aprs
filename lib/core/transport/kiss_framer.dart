import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

/// Transforms a stream of raw serial bytes into decoded AX.25 frame payloads.
///
/// Implements KISS framing per the KISS TNC specification. Feed raw bytes via
/// [addBytes]. One [Uint8List] event is emitted on [frames] per complete
/// data frame received (command byte 0x00). Non-data frames are silently
/// discarded. Malformed frames (invalid escape sequences) are discarded and
/// parsing continues from the next FEND.
///
/// This class is pure Dart and has no platform dependencies.
class KissFramer {
  static const int _fend = 0xC0;
  static const int _fesc = 0xDB;
  static const int _tfend = 0xDC;
  static const int _tfesc = 0xDD;

  final _controller = StreamController<Uint8List>.broadcast();

  /// Stream of decoded AX.25 frame payloads (KISS header stripped).
  /// One event per complete data frame.
  Stream<Uint8List> get frames => _controller.stream;

  final _buffer = <int>[];
  bool _inFrame = false;
  bool _escaped = false;

  /// Feed raw bytes from the serial port into the framer.
  ///
  /// May be called multiple times with partial data; the framer accumulates
  /// bytes internally until a complete frame is detected.
  void addBytes(List<int> bytes) {
    for (final b in bytes) {
      if (b == _fend) {
        if (_inFrame && _buffer.isNotEmpty) {
          // First byte in buffer is the KISS command byte.
          final cmd = _buffer.first;
          if (cmd == 0x00 && _buffer.length > 1) {
            // Data frame: emit payload (everything after command byte).
            _controller.add(Uint8List.fromList(_buffer.sublist(1)));
          }
          // Non-data commands and empty payloads are silently discarded.
        }
        _buffer.clear();
        _inFrame = true;
        _escaped = false;
      } else if (!_inFrame) {
        // Bytes before the first FEND are ignored.
        continue;
      } else if (b == _fesc) {
        _escaped = true;
      } else if (_escaped) {
        _escaped = false;
        if (b == _tfend) {
          _buffer.add(_fend);
        } else if (b == _tfesc) {
          _buffer.add(_fesc);
        } else {
          // Invalid escape sequence — discard frame and wait for next FEND.
          debugPrint(
            'KissFramer: invalid escape sequence '
            '0x${b.toRadixString(16).padLeft(2, '0')}, discarding frame',
          );
          _buffer.clear();
          _inFrame = false;
        }
      } else {
        _buffer.add(b);
      }
    }
  }

  /// Encode an AX.25 payload as a KISS data frame ready for serial transmission.
  ///
  /// Output format: `FEND 0x00 <escaped payload> FEND`
  static Uint8List encode(Uint8List payload) {
    final out = <int>[_fend, 0x00];
    for (final b in payload) {
      if (b == _fend) {
        out.add(_fesc);
        out.add(_tfend);
      } else if (b == _fesc) {
        out.add(_fesc);
        out.add(_tfesc);
      } else {
        out.add(b);
      }
    }
    out.add(_fend);
    return Uint8List.fromList(out);
  }

  /// Release resources. Call when the transport is disconnected.
  void dispose() => _controller.close();
}
