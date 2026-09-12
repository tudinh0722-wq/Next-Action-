# NextA Changelog

## Flutter v2 migration and foundation
- Moved the active product direction to Flutter for shared Android/iOS planner UI.
- Kept the legacy Android/Kotlin implementation as reference only.
- Established layered domain/application/data/presentation boundaries.
- Added month-first Calendar, Agenda, event CRUD, search and SQLite persistence.
- Added Material 3 semantic/dynamic theming direction.
- Added shared countdown policy with a 14-day horizon and boundary-based refresh.
- Added Samsung Calendar-inspired event editor with priority and explicit date/time fields.
- Added numeric reminder offset plus repeated reminders: default 2 additional reminders, 5-minute interval.
- Added finite recurrence generation and recurrence metadata.
- Added recurrence unit tests covering daily/weekly/monthly behavior and finite limits.

## Milestone 1 — Android reminder stabilization
- Added dedicated v3 Android reminder channels for default/high/max priority levels.
- Configured reminder channels to use the Android alarm audio stream, system sound and vibration.
- Kept exact, while-idle scheduling for reminder delivery.
- Switched exact-alarm permission handling to `requestExactAlarmsPermission()` and moved it out of blocking startup initialization.
- Restored correctly encoded Vietnamese notification text.
- Preserved scheduled-notification boot restoration.
- Added a deterministic debug alarm event: 5-minute countdown, first reminder at 4 minutes before, then two repeats one minute apart.

## Current platform work
- Android reminder stabilization is implemented and requires real-device validation, especially locked-screen/background delivery and Samsung sound/volume behavior.
- Home Widget and Focus/Lock Screen remain separate platform surfaces rather than being coupled to planner UI.
