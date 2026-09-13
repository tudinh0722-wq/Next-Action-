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
          await database.delete(event.id);
          await scheduler.cancelEvent(event.id);
          return [event.id];
        }

        await database.deleteSeriesFrom(rid, event.start);

        final removed = allEvents
            .where(
              (e) =>
                  e.recurrenceId == rid &&
                  !e.start.isBefore(event.start),
            )
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

  Future<EditResult> edit(
    NextAEvent original,
    NextAEvent edited,
    RecurrenceScope scope,
    List<NextAEvent> allEvents,
  ) async {
    switch (scope) {
      case RecurrenceScope.single:
        // A non-recurring event can be converted into a recurring series.
        // The editor returns scope=single for it, because there is no existing
        // series to ask about. In that case the recurrence rule must be
        // expanded here instead of being cleared as a single occurrence.
        final newRule = edited.recurrenceRule;
        final creatingSeries =
            original.recurrenceId == null &&
            newRule != null &&
            newRule.frequency != RecurrenceFrequency.none;

        if (creatingSeries) {
          final seed = _withId(edited, original.id).copyWith(
            recurrenceId: original.id,
            recurrenceRule: newRule,
          );
          final newEvents = generateOccurrences(seed, rule: newRule);

          await database.upsertAll(newEvents);

          for (final event in newEvents) {
            await scheduler.scheduleEvent(event);
          }

          return EditResult(
            toRemove: [original.id],
            toAdd: newEvents,
          );
        }

        // Editing one occurrence of an existing series must not regenerate
        // the whole series. Keep its recurrenceId but clear the rule on the
        // replacement occurrence so it remains a one-off exception.
        final replacement = _withId(edited, original.id).copyWith(
          recurrenceId: original.recurrenceId,
          recurrenceRule: null,
        );

        await database.upsert(replacement);
        await scheduler.scheduleEvent(replacement);

        return EditResult(
          toRemove: [original.id],
          toAdd: [replacement],
        );

      case RecurrenceScope.future:
        final rid = original.recurrenceId;
        if (rid == null) {
          return edit(
            original,
            edited,
            RecurrenceScope.single,
            allEvents,
          );
        }

        await database.deleteSeriesFrom(rid, original.start);

        final removedIds = allEvents
            .where(
              (e) =>
                  e.recurrenceId == rid &&
                  !e.start.isBefore(original.start),
            )
            .map((e) => e.id)
            .toList();

        for (final id in removedIds) {
          await scheduler.cancelEvent(id);
        }

        final newRule = edited.recurrenceRule;
        List<NextAEvent> newEvents;

        if (newRule != null &&
            newRule.frequency != RecurrenceFrequency.none) {
          final seed = edited.copyWith(
            id: original.id,
            recurrenceId: rid,
          );
          newEvents = generateOccurrences(seed, rule: newRule);
        } else {
          newEvents = [
            _withId(edited, original.id).copyWith(
              recurrenceId: rid,
              recurrenceRule: null,
            ),
          ];
        }

        await database.upsertAll(newEvents);

        for (final event in newEvents) {
          await scheduler.scheduleEvent(event);
        }

        return EditResult(
          toRemove: removedIds,
          toAdd: newEvents,
        );

      case RecurrenceScope.series:
        final rid = original.recurrenceId;
        if (rid == null) {
          return edit(
            original,
            edited,
            RecurrenceScope.single,
            allEvents,
          );
        }

        await database.deleteSeries(rid);

        final removedIds = allEvents
            .where((e) => e.recurrenceId == rid)
            .map((e) => e.id)
            .toList();

        for (final id in removedIds) {
          await scheduler.cancelEvent(id);
        }

        final seriesEvents = allEvents
            .where((e) => e.recurrenceId == rid)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

        final firstStart = seriesEvents.isNotEmpty
            ? seriesEvents.first.start
            : original.start;
        final duration = edited.end.difference(edited.start);
        final newRule = edited.recurrenceRule ??
            original.recurrenceRule ??
            const RecurrenceRule(
              frequency: RecurrenceFrequency.none,
            );

        final seedStart = DateTime(
          firstStart.year,
          firstStart.month,
          firstStart.day,
          edited.start.hour,
          edited.start.minute,
        );

        final seed = NextAEvent(
          id: rid,
          title: edited.title,
          type: edited.type,
          start: seedStart,
          end: seedStart.add(duration),
          location: edited.location,
          note: edited.note,
          priority: edited.priority,
          recurrenceId: rid,
          recurrenceRule: newRule,
          reminderMinutes: edited.reminderMinutes,
          reminderRepeatCount: edited.reminderRepeatCount,
          reminderRepeatIntervalMinutes:
              edited.reminderRepeatIntervalMinutes,
        );

        final newEvents = newRule.frequency != RecurrenceFrequency.none
            ? generateOccurrences(seed, rule: newRule)
            : [seed];

        await database.upsertAll(newEvents);

        for (final event in newEvents) {
          await scheduler.scheduleEvent(event);
        }

        return EditResult(
          toRemove: removedIds,
          toAdd: newEvents,
        );
    }
  }

  NextAEvent _withId(NextAEvent event, String id) {
    return NextAEvent(
      id: id,
      title: event.title,
      type: event.type,
      start: event.start,
      end: event.end,
      location: event.location,
      note: event.note,
      priority: event.priority,
      recurrenceId: event.recurrenceId,
      recurrenceRule: event.recurrenceRule,
      reminderMinutes: event.reminderMinutes,
      reminderRepeatCount: event.reminderRepeatCount,
      reminderRepeatIntervalMinutes:
          event.reminderRepeatIntervalMinutes,
    );
  }
}

class EditResult {
  const EditResult({
    required this.toRemove,
    required this.toAdd,
  });

  final List<String> toRemove;
  final List<NextAEvent> toAdd;
}

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
  }) {
    return NextAEvent(
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
      reminderRepeatCount:
          reminderRepeatCount ?? this.reminderRepeatCount,
      reminderRepeatIntervalMinutes:
          reminderRepeatIntervalMinutes ??
              this.reminderRepeatIntervalMinutes,
    );
  }
}

const _sentinel = Object();
