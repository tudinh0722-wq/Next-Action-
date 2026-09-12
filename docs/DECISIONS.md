# NextA Decision Log

## Flutter-first
Flutter is the product implementation so Android and iOS can share the planner UI. The legacy Kotlin app remains reference only.

## Platform adapters
Android/iOS-specific widgets, alarms, notifications and lock-screen surfaces are isolated from shared planner semantics.

## Material 3
Use Material 3 semantic roles and dynamic/system colors where practical. Pastel colors communicate event surfaces/priority without sacrificing text contrast.

## Calendar markers
Event indicators are stacked vertically, equal width, with a maximum of two visible bars per day. Priority changes color, not geometry.

## Agenda countdown
Start/end time and countdown occupy a stable right-side block so countdown remains scannable regardless of title/location length.

## Month/week collapse
Animate a viewport/clip around the calendar content rather than forcing a five-row month grid to physically shrink into week height.

## Animation
Use real Flutter animation primitives; do not simulate motion with delayed rebuilds.

## Recurrence
Generate finite concrete occurrences sharing a `recurrenceId`; do not create a separate recurrence-rule table unless explicitly requested.
