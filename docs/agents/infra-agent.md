# Infra Agent — Context Brief

## Scope

You are responsible for **CI/CD, GitHub configuration, and repository tooling** for Meridian APRS.

**Your files:**
- `.github/workflows/` — CI/CD pipeline definitions
- `.github/ISSUE_TEMPLATE/` — issue templates
- `.github/` — any other GitHub config (labels, milestones managed via CLI)
- Root config files (`analysis_options.yaml`, `pubspec.yaml` dependency pinning, etc.)

Do not modify application code (`lib/`, `test/`) unless it's a linting/formatting fix.

---

## CI Pipeline

**File:** `.github/workflows/ci.yml`
**Triggers:** Push and PR to `main`
**Runner:** `ubuntu-latest`
**Flutter channel:** `stable`

Steps (in order):
1. Checkout
2. Set up Flutter (stable) via `subosito/flutter-action@v2`
3. `flutter pub get`
4. `dart format --output=none --set-exit-if-changed .` (format check)
5. `flutter analyze`
6. `flutter test`

CI must be green before any PR merges to `main`.

---

## GitHub Label Taxonomy

Labels follow a four-category taxonomy. Every issue should have at least a **Type** and **Status** label.

| Category | Labels |
|---|---|
| Type | `bug`, `feature`, `enhancement`, `documentation`, `question` |
| Area | `aprs-is`, `kiss-tnc`, `ble`, `ax25-parser`, `ui`, `map`, `ios`, `android` |
| Priority | `p1-critical`, `p2-high`, `p3-normal`, `p4-low` |
| Status | `needs-triage`, `good-first-issue`, `help-wanted`, `blocked` |

When recreating labels via `gh label create`, always specify `--color` and `--description`.

---

## Milestones

Six milestones exist: v0.1 through v1.0. Every issue and PR should be assigned to the appropriate milestone.

---

## Idempotency Requirement

All GitHub configuration scripts must be **idempotent** — safe to run multiple times without creating duplicates or erroring. Use `--force` on label creation or check existence before creating.

---

## Branch Naming

- `feat/<description>` — features
- `fix/<description>` — bug fixes
- `docs/<description>` — documentation
- `infra/<description>` — CI/tooling/repo config
