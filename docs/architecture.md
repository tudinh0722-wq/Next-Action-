# NextA Architecture

## Direction
NextA is Flutter-first and targets Android and iOS. The legacy Android/Kotlin application is reference material only.

## Layers
```text
Flutter presentation
    -> application/use cases
        -> domain policies/models
        -> repositories
            -> SQLite local data

Platform adapters
    -> Android/iOS OS APIs
```

### Domain
Pure Dart event models and policies. No Flutter or Android/iOS dependencies.

### Application
Recurrence generation, countdown evaluation, event selection, import/validation orchestration and coordination of platform refreshes.

### Data
`sqflite` local persistence. The database is the single local source of truth for events.

### Presentation
Planner/calendar, agenda, event editor and search. UI owns transient state, not persistence or scheduling.

## Event model
Events are concrete dated occurrences. Recurring schedules expand into finite concrete occurrences sharing a `recurrenceId` and carrying recurrence metadata. Avoid a separate recurrence-rule table unless explicitly approved.

## Countdown
Shared, platform-independent policy. Horizon is 14 days. Events under 24 hours use hours/minutes; durations of 24 hours or more use days plus remaining hours. Refresh on meaningful minute/event boundaries rather than creating per-event/per-second timers.

## Platform surfaces
1. Main Flutter app.
2. Android Home Screen widget using `RemoteViews`.
3. Android Focus/Lock Screen surface where the OS/device capability exists.
4. Android notification fallback.
5. Future iOS WidgetKit/notification adapters.

A Home Screen widget does not imply Lock Screen availability. Platform capability must be detected rather than assumed.
