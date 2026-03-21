/// Platform-conditional export for [SerialKissTransport].
///
/// On desktop (dart.library.io is available) this re-exports the real
/// implementation backed by flutter_libserialport. On other platforms (web)
/// the stub is used, which throws [UnsupportedError] on connect/disconnect.
library;

export 'serial_kiss_transport_stub.dart'
    if (dart.library.io) 'serial_kiss_transport_impl.dart';
