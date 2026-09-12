# NextA Current Task

## Status
IN PROGRESS

## Source of truth
This repository is the active Flutter product. Legacy Kotlin is reference only.

## Current state
- Flutter planner/calendar and agenda baseline established.
- Event editor, SQLite persistence and search established.
- Countdown policy established with 14-day horizon.
- Priority, reminder configuration/repeat metadata and finite recurrence established.
- Recurrence policy tests pass in the current local Flutter project.
- Android debug APK has been built and the app has been run on the user's Samsung S23; the reported remaining issue is automatic alarm sound playback.

## Current objective
Stabilize Android reminder delivery using the Android system notification/alarm sound while preserving exact scheduling, timezone handling and repeat behavior. Then complete recurrence series operations, AI bulk import, platform-surface verification and cross-device verification.

## Boundaries
- Do not modify the old Kotlin app for Flutter work.
- Do not redesign locked Calendar/Agenda UI without explicit request.
- Keep platform-specific behavior isolated from shared event semantics.
