import '../data/event_database.dart';
import '../domain/event.dart';
import 'alarm_scheduler.dart';
import 'recurrence_policy.dart';

/// Edit/delete scope for a recurrence series occurrence.
enum RecurrenceScope {
  single,
  future,
  series,
}

/// Application-layer service that applies series-aware edit and delete
/// operations while keeping the database and alarm scheduler in sync.
class RecurrenceService {
  const RecurrenceService({
    required this.database,
    required this.scheduler,
  });

  final EventDatabase database;
  final AlarmScheduler scheduler;

  // ── DELETE ──────────────────────────────────────────────────────────────────

  /// Deletes [event] according to [scope].
  ///
  /// Returns the list of event IDs that were removed so the caller can update
  /// its in-memory list.
  Future<List<String>> delete(
    NextAEvent event,
    RecurrenceScope scope,
    List<NextAEvent> allEvents,
  ) async {
    switch (scope) {
      case RecurrenceScope.single:
        await database.delete(event.id);
        await scheduler.cancelEvent(event.id);
        return [event.id];

      case RecurrenceScope.future:
        final rid = event.recurrenceId;
        if (rid == null) {
          // Fallback: treat as single.
          await database.delete(event.id);
          await scheduler.cancelEvent(event.id);
          return [event.id];
        }
        await database.deleteSeriesFrom(rid, event.start);
        final removed = allEvents
            .where((e) =>
                e.recurrenceId == rid && !e.start.isBefore(event.start))
            .map((e) => e.id)
            .toList();
        for (final id in removed) {
          await scheduler.cancelEvent(id);
        }
        return removed;

      case RecurrenceScope.series:
        final rid = event.recurrenceId;
        if (rid == null) {
          await database.delete(event.id);
          await scheduler.cancelEvent(event.id);
          return [event.id];
        }
        await database.deleteSeries(rid);
        final removed = allEvents
            .where((e) => e.recurrenceId == rid)
            .map((e) => e.id)
            .toList();
        for (final id in removed) {
          await scheduler.cancelEvent(id);
        }
        return removed;
    }
  }

  // ── EDIT ────────────────────────────────────────────────────────────────────

  /// Edits [original] occurrence using [edited] as the new data, according to
  /// [scope].
  ///
  /// Returns the net changes: [EditResult.toRemove] are IDs removed from the
  /// in-memory list; [EditResult.toAdd] are events that must be added.
  Future<EditResult> edit(
    NextAEvent original,
    NextAEvent edited,
    RecurrenceScope scope,
    List<NextAEvent> allEvents,
  ) async {
    switch (scope) {
      case RecurrenceScope.single:
        // Replace only this occurrence. It keeps its recurrenceId but its
        // recurrenceRule is cleared so it no longer spawns children.
        final replacement = _withId(edited, original.id).copyWith(
          recurrenceId: original.recurrenceId,
          recurrenceRule: null,
        );
        await database.upsert(replacement);
        await scheduler.scheduleEvent(replacement);
        return EditResult(toRemove: [original.id], toAdd: [replacement]);

      case RecurrenceScope.future:
        final rid = original.recurrenceId;
        if (rid == null) {
          // No series — delegate to single.
          return edit(original, edited, RecurrenceScope.single, allEvents);
        }
        // Delete this and all later occurrences from DB + scheduler.
        await database.deleteSeriesFrom(rid, original.start);
        final removedIds = allEvents
            .where((e) =>
                e.recurrenceId == rid && !e.start.isBefore(original.start))
            .map((e) => e.id)
            .toList();
        for (final id in removedIds) {
          await scheduler.cancelEvent(id);
        }
        // Generate new occurrences from the edited event forward.
        final newRule = edited.recurrenceRule;
        List<NextAEvent> newEvents;
        if (newRule != null && newRule.frequency != RecurrenceFrequency.none) {
          // Re-seed with the edited data but keep the same recurrenceId.
          final seed = edited.copyWith(
            id: original.id,
            recurrenceId: rid,
          );
          newEvents = generateOccurrences(seed, rule: newRule);
        } else {
          // User removed recurrence — create a standalone event.
          newEvents = [
            _withId(edited, original.id).copyWith(
              recurrenceId: rid,
              recurrenceRule: null,
            ),
          ];
        }
        await database.upsertAll(newEvents);
        for (final e in newEvents) {
          await scheduler.scheduleEvent(e);
        }
        return EditResult(toRemove: removedIds, toAdd: newEvents);

      case RecurrenceScope.series:
        final rid = original.recurrenceId;
        if (rid == null) {
          return edit(original, edited, RecurrenceScope.single, allEvents);
        }
        // Delete the whole series.
        await database.deleteSeries(rid);
        final removedIds = allEvents
            .where((e) => e.recurrenceId == rid)
            .map((e) => e.id)
            .toList();
        for (final id in removedIds) {
          await scheduler.cancelEvent(id);
        }
        // Re-generate entire series from the first occurrence's date but with
        // edited content. Find the series start.
        final seriesEvents = allEvents
            .where((e) => e.recurrenceId == rid)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        final firstStart =
            seriesEvents.isNotEmpty ? seriesEvents.first.start : original.start;
        final duration = edited.end.difference(edited.start);
        final newRule = edited.recurrenceRule ??
            original.recurrenceRule ??
            const RecurrenceRule(frequency: RecurrenceFrequency.none);
        final seed = NextAEvent(
          id: rid, // reuse original recurrenceId as seed id
          title: edited.title,
          type: edited.type,
          start: DateTime(
            firstStart.year,
            firstStart.month,
            firstStart.day,
            edited.start.hour,
            edited.start.minute,
          ),
          end: DateTime(
            firstStart.year,
            firstStart.month,
            firstStart.day,
            edited.start.hour,
            edited.start.minute,
          ).add(duration),
          location: edited.location,
          note: edited.note,
          priority: edited.priority,
          recurrenceId: rid,
          recurrenceRule: newRule,
          reminderMinutes: edited.reminderMinutes,
          reminderRepeatCount: edited.reminderRepeatCount,
          reminderRepeatIntervalMinutes: edited.reminderRepeatIntervalMinutes,
        );
        List<NextAEvent> newEvents;
        if (newRule.frequency != RecurrenceFrequency.none) {
          newEvents = generateOccurrences(seed, rule: newRule);
        } else {
          newEvents = [seed];
        }
        await database.upsertAll(newEvents);
        for (final e in newEvents) {
          await scheduler.scheduleEvent(e);
        }
        return EditResult(toRemove: removedIds, toAdd: newEvents);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  NextAEvent _withId(NextAEvent e, String id) => NextAEvent(
        id: id,
        title: e.title,
        type: e.type,
        start: e.start,
        end: e.end,
        location: e.location,
        note: e.note,
        priority: e.priority,
        recurrenceId: e.recurrenceId,
        recurrenceRule: e.recurrenceRule,
        reminderMinutes: e.reminderMinutes,
        reminderRepeatCount: e.reminderRepeatCount,
        reminderRepeatIntervalMinutes: e.reminderRepeatIntervalMinutes,
      );
}

class EditResult {
  const EditResult({required this.toRemove, required this.toAdd});
  final List<String> toRemove;
  final List<NextAEvent> toAdd;
}

// Extension so NextAEvent can be conveniently copied with changed fields.
extension NextAEventCopy on NextAEvent {
  NextAEvent copyWith({
    String? id,
    String? title,
    EventType? type,
    DateTime? start,
    DateTime? end,
    Object? location = _sentinel,
    Object? note = _sentinel,
    int? priority,
    Object? recurrenceId = _sentinel,
    Object? recurrenceRule = _sentinel,
    int? reminderMinutes,
    int? reminderRepeatCount,
    int? reminderRepeatIntervalMinutes,
  }) =>
      NextAEvent(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        start: start ?? this.start,
        end: end ?? this.end,
        location:
            location == _sentinel ? this.location : location as String?,
        note: note == _sentinel ? this.note : note as String?,
        priority: priority ?? this.priority,
        recurrenceId: recurrenceId == _sentinel
            ? this.recurrenceId
            : recurrenceId as String?,
        recurrenceRule: recurrenceRule == _sentinel
            ? this.recurrenceRule
            : recurrenceRule as RecurrenceRule?,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
        reminderRepeatCount: reminderRepeatCount ?? this.reminderRepeatCount,
        reminderRepeatIntervalMinutes: reminderRepeatIntervalMinutes ??
            this.reminderRepeatIntervalMinutes,
      );
}

const _sentinel = Object();
