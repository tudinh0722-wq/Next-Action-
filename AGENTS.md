# NextA AI Implementation Contract

## Source of truth
- This repository is the active Flutter product.
- `lib/` is the shared Flutter implementation.
- `android/` and `ios/` are Flutter platform wrappers/adapters, not separate app implementations.
- The old `NextA` Android/Kotlin project is reference/history only and must not be modified for Flutter work.

## Rules
- Preserve the layered Flutter architecture: domain -> application -> data -> presentation.
- Keep event, recurrence and countdown semantics platform-independent.
- SQLite (`sqflite`) is the Flutter local source of truth; do not introduce Room.
- Android platform features such as alarms, RemoteViews widgets and lock-screen integrations belong behind platform boundaries.
- Home Screen widgets use Android `RemoteViews`; do not introduce Jetpack Glance unless explicitly requested.
- Prefer capability detection over OEM/device-brand checks.
- Prefer Material 3 semantic/dynamic colors over hard-coded system colors.
- Do not add per-event or per-second countdown timers.
- Do not redesign the Calendar or Agenda UI unless the user explicitly requests it.
- Keep the Samsung Calendar-inspired interaction hierarchy, but use NextA's own implementation/assets.
- Do not claim tests, builds or device behavior as verified unless actually run.

## Documentation
After meaningful work, update the relevant files under `docs/`: `task.md`, `changelog.md`, `plan.md`, `architecture.md`, or `requirements.md`.
