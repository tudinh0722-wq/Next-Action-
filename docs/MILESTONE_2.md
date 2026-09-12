# NextA — Milestone 2

## Goal
Complete the next product-level functionality after Android reminder stabilization:

1. Make recurring events fully series-aware for edit/delete operations.
2. Replace the current AI Import placeholder with a real bulk-import flow.
3. Add integration tests for bulk import and regression tests for recurrence series behavior.

Milestone 2 must build on the existing Flutter architecture. Do not rewrite the planner or replace working foundation code without a concrete reason.

## Source of truth
- Active product: Flutter repository.
- Shared implementation: `lib/`.
- SQLite via `sqflite` remains the local source of truth.
- Legacy Android/Kotlin code is reference/history only and must not be modified for Flutter work.
- Preserve domain -> application -> data -> presentation boundaries.

## Part A — Recurrence series operations

The current project already has finite recurrence generation and `recurrenceId` metadata. The recurrence policy supports `none`, `daily`, `weekly`, `weekdays`, and `monthly`, bounded by count or end date.

Implement and verify true series-aware behavior:

### Edit
When editing an occurrence that belongs to a recurrence series, provide the appropriate scope:
- This occurrence only
- This and following occurrences
- Entire series

The chosen scope must produce correct persisted events and preserve recurrence metadata.

### Delete
When deleting an occurrence in a recurrence series, provide the appropriate scope:
- This occurrence only
- This and following occurrences
- Entire series

Deletion must also clean up reminders for deleted events and must not leave orphaned scheduled alarms/notifications.

### Edge cases
Verify at minimum:
- Editing/deleting the first occurrence.
- Editing/deleting a middle occurrence.
- Editing/deleting the final occurrence.
- Series with count limit.
- Series with end-date limit.
- Daily, weekly, weekdays and monthly recurrence.
- Editing date/time while preserving the intended series semantics.
- No accidental duplication of occurrences.
- No accidental modification of unrelated events.

Do not redesign Calendar or Agenda to accomplish this. Existing UI is a locked baseline unless explicitly requested.

## Part B — AI Import

Replace the current `AI Import` placeholder in the Add Event flow with a real bulk-import pipeline.

Required flow:

`Input -> Parse -> Validate -> Preview -> Confirm -> Persist -> Schedule reminders`

### Input
Support a practical text-based bulk event input using the existing event model. Do not invent a new storage model merely for import.

### Parse
Create a platform-independent application-layer parser/import service. Keep parsing logic out of widgets.

The importer should extract, where available:
- title
- type
- start date/time
- end date/time
- location
- note
- priority
- reminder configuration
- recurrence information

### Validation
Reject or flag invalid records, including:
- Missing title.
- Missing/invalid start date-time.
- End not after start.
- Invalid recurrence data.
- Invalid reminder values.

The import must never silently create malformed events.

### Preview
Before persistence, show the user a preview list containing:
- Valid events ready to import.
- Invalid events with understandable validation errors.

The user must explicitly confirm before persistence.

### Persistence
On confirmation:
- Persist valid events through the existing SQLite/data layer.
- Preserve event IDs and recurrence relationships correctly.
- Schedule reminders using the existing `AlarmScheduler`/application boundary.
- Do not duplicate events if the import flow is rebuilt/retried accidentally.

### Failure handling
A bad record must not corrupt valid records. Prefer per-record validation and a clear import result.

## Part C — Tests

Add/extend tests for:

### Recurrence
- Series generation remains correct after edit/delete operations.
- Scope operations do not affect unrelated events.
- Reminder cleanup/rescheduling is correct after series changes.

### AI Import
- Parsing valid records.
- Parsing multiple records.
- Validation failures.
- Mixed valid/invalid input.
- Persistence of confirmed records.
- No persistence before confirmation.
- Reminder scheduling after successful import.
- Re-import/idempotency behavior where applicable.

Do not claim tests pass unless they are actually run.

## UX constraints
- Keep the existing Samsung Calendar-inspired Add Event hierarchy.
- Do not redesign Calendar or Agenda.
- Keep Material 3 semantic/dynamic colors.
- Keep existing Vietnamese UI terminology unless a terminology change is necessary for correctness.
- The current Add Event screen is `EventEditorSheetV2` in `lib/presentation/widgets/event_editor_sheet_v2.dart`.
- Do not use image generation or introduce decorative assets for this milestone.

## Architecture constraints
- Domain semantics remain platform-independent.
- Recurrence and import logic belong in application/domain layers, not directly in widgets.
- SQLite remains the Flutter local source of truth.
- Android-specific alarm scheduling stays behind the existing platform/application boundary.
- Do not introduce Room.
- Do not modify the old Kotlin application.

## Working procedure
1. Inspect the actual current repository before coding.
2. Read `AGENTS.md`, `docs/PROJECT_CONTEXT.md`, `docs/requirements.md`, `docs/plan.md`, and `docs/task.md`.
3. Inspect existing recurrence, event database, planner delete/edit flow, Add Event editor, and alarm scheduler before changing anything.
4. Reuse existing code where possible.
5. Make the smallest coherent implementation that satisfies this milestone.
6. Run `dart format`, `flutter analyze`, and relevant tests.
7. Build the debug APK if Android code is changed.
8. Report only results that were actually verified.
9. Update `docs/task.md`, `docs/changelog.md`, and `docs/plan.md` after meaningful completion.

## Definition of Done
Milestone 2 is complete only when:

- [ ] Recurrence edit/delete scopes work correctly.
- [ ] Recurrence edge cases are covered by tests.
- [ ] AI Import is no longer a placeholder.
- [ ] AI Import supports parse -> validate -> preview -> confirm -> persist.
- [ ] Invalid records are clearly reported and do not corrupt valid records.
- [ ] Imported events use the existing SQLite model.
- [ ] Imported reminders use the existing scheduler.
- [ ] Integration/regression tests pass.
- [ ] `flutter analyze` passes with no new errors.
- [ ] Documentation is updated.
- [ ] No locked Calendar/Agenda redesign was introduced.

## Important
Do not expand scope into Android Home Widget, Focus/Lock Screen, iOS adapters, or broad responsive redesign during Milestone 2. Those belong to later platform work unless explicitly requested.
