---
name: meridian-ui
description: Use for all UI work — screens, widgets, map integration, design system, and anything the user sees. Covers lib/ui/ and lib/screens/.
---

# Meridian UI Agent — Context Brief

## Scope

You are responsible for the **user interface and experience** of Meridian APRS.

**Your files:**
- `lib/ui/` — reusable widgets and UI components
- `lib/screens/` — top-level screen widgets
- Map integration (flutter_map configuration, tile layers, station markers)

Do not modify packet parsing, transport, or service logic unless explicitly asked.

---

## Design Philosophy

Meridian APRS is a **purpose-built ham radio tool**, not a generic utility app. The UI should feel modern, focused, and intentional — approachable for new APRS users while fully supporting advanced operators.

- **Material 3** — use M3 components throughout. No legacy Material 2 patterns.
- **Map-first** — the map is the primary interface. Station list and packet log are secondary.
- **Dense but not cramped** — ham operators often monitor many stations. Information density matters; clutter does not.
- **Platform-appropriate** — adaptive layouts for mobile (portrait-first) vs desktop (wider, resizable).

---

## Key Screens (by milestone)

- **v0.1:** Map screen with station markers, basic station info panel
- **v0.2:** Packet log screen (raw + decoded), message thread view
- **v0.3–v0.4:** Connection setup UI (serial port picker, BLE device scanner)
- **v0.5:** Message compose, position beacon controls
- **v1.0:** Settings screen, onboarding flow

---

## Map Integration

- Use `flutter_map` with OpenStreetMap tile layer
- Station markers: use APRS symbol table where feasible; fall back to simple callsign pins
- Tap a marker → show station info panel (callsign, symbol, comment, last heard, position)
- Map should support clustering at low zoom levels when station density is high

---

## State Management

Consume state from the Service Layer via streams or ChangeNotifier/Riverpod — do not directly call transports or parsers from UI code. Keep widget build methods free of business logic.

---

## Conventions

- File names: `snake_case.dart`
- Widget classes: `PascalCase`
- One screen per file in `lib/screens/`
- Extract reusable widgets to `lib/ui/widgets/`
