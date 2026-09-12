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
- Android debug APK has been built and the app has been run on the user's Samsung S23.
- Milestone 1 Android reminder stabilization is implemented in the repository and is now awaiting device validation.
- Reminder scheduling uses dedicated Android alarm notification channels with system sound enabled and alarm audio attributes.
- Exact-alarm permission is requested only when an actual future reminder needs to be scheduled, rather than blocking app startup.
- Debug builds keep a deterministic 5-minute alarm test event for repeat/sound validation.

## Current objective
Validate Android reminder delivery on the Samsung S23 using the system notification/alarm sound while preserving exact scheduling, timezone handling, repeat behavior, edit/delete rescheduling, reboot restoration and background/locked-screen behavior. Then complete recurrence series operations, AI bulk import, platform-surface verification and cross-device verification.

## Milestone 1 implementation
- Replaced the persistent `nexta_reminder_v2` channel usage with v3 alarm channels so previously-created silent channel state cannot mask the new configuration.
- Added default/high/max channels with `AudioAttributesUsage.alarm`, sound enabled and vibration enabled.
- Kept `AndroidScheduleMode.exactAllowWhileIdle` for exact, idle-resistant scheduling.
- Switched exact-alarm permission handling to the plugin's `requestExactAlarmsPermission()` API and made it non-blocking during initial app launch.
- Corrected notification text encoding in the scheduler.
- Preserved boot receiver configuration for scheduled notification restoration.

## Boundaries
- Do not modify the old Kotlin app for Flutter work.
- Do not redesign locked Calendar/Agenda UI without explicit request.
- Keep platform-specific behavior isolated from shared event semantics.
