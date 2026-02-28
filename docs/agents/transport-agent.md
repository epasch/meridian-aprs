# Transport Agent — Context Brief

## Scope

You are responsible for the **connectivity layer** of Meridian APRS — moving bytes between the app and the outside world.

**Your files:**
- `lib/core/transport/` — abstract transport interface and all implementations
- Platform-specific glue for serial and BLE as needed

Do not modify packet parsing, UI, or service orchestration code unless explicitly asked.

---

## Transport Implementations

| Transport | Platforms | Plugin |
|---|---|---|
| APRS-IS TCP | iOS, Android, macOS, Linux, Windows | `dart:io` (RawSocket) |
| APRS-IS WebSocket proxy | Web only | `dart:html` WebSocket |
| KISS/USB Serial | macOS, Linux, Windows | `flutter_libserialport` |
| KISS/BLE | iOS, Android | `flutter_blue_plus` |

---

## Design Requirements

- All transports implement a **common abstract interface**: connect, disconnect, a byte stream in, a byte sink out.
- The Service Layer must be transport-agnostic — it should not need to know which transport is active.
- KISS framing (encode/decode) lives in the Packet Core (`lib/core/ax25/`), not here. The transport layer deals in raw bytes only.
- Web platform **cannot open TCP sockets** — this is a hard browser constraint. On web, always use the WebSocket proxy path. Do not attempt to conditionally try TCP on web.

---

## Platform Awareness

Use `dart:io` checks (`Platform.isAndroid`, etc.) to guard platform-specific code. Ensure the web build never imports `dart:io`. Use conditional imports where necessary.

---

## Connection Lifecycle

Each transport should handle:
- Initial connection with timeout
- Reconnect on unexpected disconnect (with backoff)
- Clean disconnect on user request
- Exposing connection state as a stream

---

## APRS-IS Protocol Notes

- Login line: `user CALLSIGN pass PASSCODE vers meridian-aprs 0.1\r\n`
- Server filter: sent after login, e.g. `#filter r/lat/lon/radius\r\n`
- Keep connection alive: server sends `#` comment lines; client should respond to keepalives if required
- `rotate.aprs2.net:14580` is the standard rotating APRS-IS server pool
