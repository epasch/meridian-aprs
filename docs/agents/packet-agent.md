# Packet Agent — Context Brief

## Scope

You are responsible for the **AX.25/APRS packet parsing and encoding layer** of Meridian APRS.

**Your files:**
- `lib/core/packet/` — APRS information field parsing and encoding
- `lib/core/ax25/` — AX.25 frame structure (address, control, PID, info)
- `test/packet/` — unit tests for all parsing logic

Do not modify UI, service, or transport code unless explicitly asked.

---

## Non-Negotiables

- **Pure Dart only.** No `dart:ffi`, no platform imports. This code runs on web — keep it portable.
- **Test everything.** Every packet type must have unit tests. Use real-world packet strings as test vectors.
- **Correctness over cleverness.** APRS has many edge cases and ambiguities. When in doubt, match what Dire Wolf and aprslib produce.

---

## Reference Projects (Logic Reference Only — No Code Copying)

| Project | What to reference |
|---|---|
| **Dire Wolf** | Definitive APRS/AX.25 decoder. Use its source and output as a correctness oracle. |
| **aprslib** (Python) | Clean, readable APRS parser. Good for understanding format edge cases. |
| **Xastir** | Comprehensive packet type coverage including obscure/legacy formats. |
| **APRSDroid** | Android client — useful for understanding real-world packet variety. |

When unsure about a format detail, check the APRS spec (APRS 1.0.1) first, then Dire Wolf source, then aprslib.

---

## Packet Types to Support (by milestone)

- **v0.1:** Plain and compressed lat/lon position (no messaging)
- **v0.2:** Position (all formats), message, object, item, weather, telemetry, status
- **v0.5:** Encoding — position and message types for transmit

---

## Key Format References

- APRS Protocol Reference 1.0.1
- AX.25 Link Access Protocol for Amateur Packet Radio, v2.2
- `rotate.aprs2.net` sends IS-formatted packets (no AX.25 frame wrapping for APRS-IS; KISS/TNC path includes full AX.25 framing)
