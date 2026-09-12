# NextA Flutter AI Handoff Contract

## Mission
Maintain the Flutter implementation as the active NextA product. The legacy Android/Kotlin project is reference only.

## MUST
- Implement product features in Flutter `lib/` and its required platform adapters.
- Preserve the layered architecture and shared event semantics.
- Read `AGENTS.md` and relevant `docs/` files before substantial changes.
- Preserve the locked Calendar and Agenda visual baseline unless the user explicitly reopens it.
- Use Material 3 semantic/system colors where appropriate.
- Keep countdown and recurrence policies independent from UI surfaces.
- Update task/changelog/plan documentation after meaningful changes.

## MUST NOT
- Do not modify or use the legacy Kotlin app as the implementation target for Flutter features.
- Do not replace Flutter SQLite with Room.
- Do not introduce Jetpack Glance unless explicitly requested.
- Do not assume Home Screen widgets work on every Lock Screen.
- Do not use OEM/device-brand checks when capability checks are possible.
- Do not create per-event/per-second countdown timers.
- Do not claim builds/tests/device behavior without actual verification.

## Current product baseline
Planner, Calendar, Agenda, event editor, SQLite persistence, search, countdown, priority, reminder configuration and finite recurrence are established. Remaining work is tracked in `docs/task.md` and `docs/plan.md`.
