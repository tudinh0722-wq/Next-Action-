# NextA Project Context

NextA is a planner/calendar application. The active product is this Flutter repository. The original Android/Kotlin implementation in the old repository is historical/reference material and is not the implementation target.

## Current Flutter foundation
- Month-first planner/calendar with month/week collapse and directional navigation.
- Selected-day agenda.
- Event create/edit/delete/search.
- SQLite persistence.
- Material 3 theming and semantic/dynamic color direction.
- Minute-aligned countdown with a 14-day horizon.
- Samsung Calendar-inspired Add Event hierarchy implemented independently.
- Priority persistence and shared visual severity.
- Numeric reminder configuration with repeat metadata.
- Finite recurrence generation and recurrence UI.

## UI contract
Calendar and Agenda are considered complete/locked. Do not redesign, resize, restyle or structurally refactor their presentation without an explicit user request. Functional fixes must preserve the established appearance.

Add Event contains title/priority, explicit start/end date-time, address, note, reminder, reminder repeat, recurrence and save/exit actions. Reminder defaults are 10 minutes before, followed by 2 additional reminders 5 minutes apart.

## Platform direction
Keep the planner platform-neutral. Android alarms, RemoteViews widgets and lock-screen/notification surfaces are platform adapters. iOS WidgetKit/notifications are future platform adapters.

## Working rule
Inspect the actual source before making assumptions. Run formatter/analyzer/tests when relevant and report only verified results. Keep documentation as the maintained handoff for future AI agents.
