# NextA Product Requirements

## Event management
- Create/edit/delete events with title, type, explicit start/end date-time, location, note and priority.
- No All-day mode.
- End must be after start.
- Persist locally in Flutter SQLite.
- Search title, location and note; selecting a result navigates to its date.

## Reminder
- Reminder is configured with a numeric offset rather than fixed presets.
- Default: 10 minutes before the event.
- If not acknowledged, repeat 2 additional times by default.
- Default interval between reminders: 5 minutes.
- User can set offset, repeat count and interval directly.
- `reminderMinutes = 0` represents a disabled reminder.

## Recurrence
- Supported frequencies: none, daily, weekly, weekdays and monthly.
- Recurrences are finite by count or end date.
- Default count: 10 occurrences.
- Generated concrete occurrences share a `recurrenceId`.
- A hard safety cap prevents unbounded generation.

## Countdown
- Upcoming event counts to start; active event counts to end.
- Show countdown only within 14 days.
- Under 24 hours: hours/minutes.
- 24 hours or more: days plus remaining hours.
- Use shared minute-boundary refreshes, not per-event/per-second timers.

## Calendar and Agenda
- Calendar and Agenda form a locked visual baseline unless the user explicitly requests changes.
- Calendar markers: maximum two, vertically stacked, equal width.
- Agenda uses a stable right-side time/countdown block.

## Platform surfaces
- Android Home Widget: traditional `RemoteViews`, up to two relevant events.
- Focus/Lock Screen: capability-dependent Now/Next surface with notification fallback.
- Cross-device behavior must prefer capability detection over OEM-specific assumptions.
