# Milestone 4 — Reminder & Alarm Experience 2.0

## Baseline
Milestone 4 is built directly from the verified Milestone 3 widget baseline. No second feature branch or alternate widget protocol is used.

## Architecture

```text
SQLite EventDatabase
       │
       ├── PlannerScreen
       │
       ├── AlarmScheduler
       │      ├── flutter_local_notifications
       │      └── native AlarmManager → AlarmTtsReceiver
       │
       └── WidgetBridge → MainActivity → NextAWidgetProvider
```

SQLite remains the source of truth. Android adapters receive snapshots and never own event data.

## Alarm lifecycle

1. `AlarmScheduler.scheduleAll()` restores future reminders at startup.
2. Each reminder creates a deterministic notification slot and native TTS alarm.
3. The notification payload is parsed into `AlarmAlert`.
4. `AlarmAlertController` exposes the current alert through one nullable stream.
5. `AlarmScreen` is displayed while an alert is pending.
6. `XÁC NHẬN` cancels the remaining reminder slots for that concrete event and clears the alert.
7. If the user does nothing, `AlarmScreen` auto-dismisses after five minutes.
8. Recurring occurrences have different event IDs, so acknowledging one occurrence does not cancel another occurrence.

## Widget lifecycle

- `WidgetBridge.syncEvents()` mirrors **all upcoming events**, not only the two visible rows.
- `NextAWidgetProvider` filters, sorts and renders the next two events.
- The provider refreshes every minute while at least one widget exists.
- Widget taps use `nexta://event/<id>` and `MainActivity` preserves the pending ID across warm/cold starts.
- No widget-specific database exists.

## Refactor rules

- Do not add a second widget implementation.
- Do not create a second reminder scheduler.
- Keep Calendar and Agenda presentation unchanged.
- Keep Android-specific behavior behind the existing bridge/scheduler boundaries.
- Do not add development test data to production startup.
- Keep temporary/manual test data in separate development files only when explicitly enabled.

## Verification

The repository changes in this milestone were edited directly on `milestone-4-reminder-experience`. Flutter/Android build execution is not available in this environment, so build and device-runtime results must be verified on the development machine before marking the milestone fully tested.
