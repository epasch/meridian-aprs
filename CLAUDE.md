# Meridian APRS — Project Brief for Claude Code Agents

**Tagline:** APRS for the Modern Ham
**Repo:** https://github.com/epasch/meridian-aprs
**Domains:** meridianaprs.com / meridianaprs.app
**License:** GPL v3

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (stable channel) |
| Map | flutter_map + OpenStreetMap tiles |
| BLE | flutter_blue_plus |
| Serial/USB | flutter_libserialport |
| APRS-IS | Direct TCP to `rotate.aprs2.net:14580` (WebSocket proxy on web) |
| Packet parsing | Pure Dart (no FFI for core logic) |

---

## Architecture Layers

```
UI Layer          →  lib/ui/, lib/screens/
Service Layer     →  lib/services/
Packet Core       →  lib/core/packet/, lib/core/ax25/
Transport Core    →  lib/core/transport/
Platform Channels →  platform-specific code (android/, ios/, etc.)
```

Each layer depends only on layers below it. The Packet Core has no platform dependencies — it is pure Dart and must remain so.

**Transport strategy by platform:**
- Mobile (iOS/Android): APRS-IS TCP, KISS/BLE
- Desktop (Linux/macOS/Windows): APRS-IS TCP, KISS/USB serial
- Web: APRS-IS via WebSocket proxy (direct TCP not available in browser)

See `docs/ARCHITECTURE.md` for full detail.

---

## Milestone Roadmap

| Milestone | Focus |
|---|---|
| v0.1 — Foundation | Flutter scaffold, map rendering, APRS-IS connection, basic station display |
| v0.2 — Packets | AX.25/APRS parser, packet log view, message decoding |
| v0.3 — TNC | KISS over USB serial, desktop platforms first |
| v0.4 — BLE | KISS over BLE, mobile platforms |
| v0.5 — Beaconing | Transmit path, position beaconing, message sending |
| v1.0 — Polish | UI refinement, settings, documentation, onboarding |

**Current status: v0.1 Foundation in progress.**

See `docs/ROADMAP.md` for per-milestone task breakdowns.

---

## Reference Projects

These are used as **logic references only**. Do not copy code from them.

| Project | Language | Notes |
|---|---|---|
| Dire Wolf | C | TNC, AX.25, APRS decoding reference |
| APRSDroid | Kotlin/Java | Android APRS client, connection model reference |
| aprslib | Python | Clean APRS parser — logic reference |
| Xastir | C | Feature-complete APRS client, comprehensive packet type coverage |

---

## GitHub Workflow Conventions

**Branch naming:**
- `feat/<short-description>` — new features
- `fix/<short-description>` — bug fixes
- `docs/<short-description>` — documentation only
- `infra/<short-description>` — CI, tooling, repo config

**Labels:** Use the full label taxonomy (Type + Area + Priority + Status). Every issue and PR should have at least one label from each of Type and Status.

**Milestones:** Assign every issue and PR to the appropriate milestone.

---

## Agent Scopes

Each sub-agent has a focused context file in `docs/agents/`:

- `packet-agent.md` — AX.25/APRS parsing
- `transport-agent.md` — APRS-IS, KISS/USB, KISS/BLE transports
- `ui-agent.md` — screens, widgets, map integration
- `infra-agent.md` — CI/CD, GitHub config, tooling

---

## Docs Maintenance

Keep these files current as the project evolves:

- `docs/ARCHITECTURE.md` — update when layers or platform strategy changes
- `docs/DECISIONS.md` — add an ADR for every significant architectural decision
- `docs/ROADMAP.md` — mark tasks complete, add tasks as scope clarifies

---

## Rules for All Agents

- No credentials, API keys, or sensitive info in any committed file
- No copying code from reference projects — logic reference only
- Pure Dart for all packet core logic (no FFI in `lib/core/`)
- Follow existing Flutter/Dart conventions in the codebase
- Run `flutter analyze` and `flutter test` before considering any task done
