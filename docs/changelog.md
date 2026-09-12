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

## Current platform work
- Added Flutter Android alarm scheduling with device-timezone-aware `zonedSchedule` and exact-alarm support.
- Android reminder sound is intended to use the system notification/alarm sound; channel configuration must be treated as persistent Android state.
- Home Widget and Focus/Lock Screen remain separate platform surfaces rather than being coupled to planner UI.
