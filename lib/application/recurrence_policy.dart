import '../domain/event.dart';

/// Expands one event into a finite set of concrete occurrences.
/// The recurrence rule is always bounded by count or until, with a hard
/// safety cap as a final guard against malformed data.
List<NextAEvent> generateOccurrences(
  NextAEvent seed, {
  required RecurrenceRule rule,
  int maxOccurrences = 366,
}) {
  if (rule.frequency == RecurrenceFrequency.none || maxOccurrences <= 1) {
    return [seed];
  }

  final recurrenceId = seed.recurrenceId ?? seed.id;
  final occurrences = <NextAEvent>[
    NextAEvent(
      id: seed.id,
      title: seed.title,
      type: seed.type,
      start: seed.start,
      end: seed.end,
      location: seed.location,
      note: seed.note,
      priority: seed.priority,
      recurrenceId: recurrenceId,
      recurrenceRule: rule,
      reminderMinutes: seed.reminderMinutes,
      reminderRepeatCount: seed.reminderRepeatCount,
      reminderRepeatIntervalMinutes: seed.reminderRepeatIntervalMinutes,
    ),
  ];
  var nextStart = seed.start;
  var index = 1;
  final targetCount = rule.endMode == RecurrenceEndMode.count ? (rule.count ?? 20) : null;
  final duration = seed.end.difference(seed.start);

  while (occurrences.length < maxOccurrences) {
    if (targetCount != null && occurrences.length >= targetCount) break;
    nextStart = _nextStart(seed.start, nextStart, index, rule);
    if (rule.until != null && nextStart.isAfter(rule.until!)) break;

    occurrences.add(
      NextAEvent(
        id: '${seed.id}-$index',
        title: seed.title,
        type: seed.type,
        start: nextStart,
        end: nextStart.add(duration),
        location: seed.location,
        note: seed.note,
        priority: seed.priority,
        recurrenceId: recurrenceId,
        recurrenceRule: rule,
        reminderMinutes: seed.reminderMinutes,
        reminderRepeatCount: seed.reminderRepeatCount,
        reminderRepeatIntervalMinutes: seed.reminderRepeatIntervalMinutes,
      ),
    );
    index++;
  }

  return occurrences;
}

DateTime _nextStart(
  DateTime seedStart,
  DateTime current,
  int index,
  RecurrenceRule rule,
) {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      return current.add(Duration(days: rule.interval));
    case RecurrenceFrequency.weekly:
      return current.add(Duration(days: 7 * rule.interval));
    case RecurrenceFrequency.weekdays:
      var candidate = current;
      var remaining = rule.interval;
      while (remaining > 0) {
        candidate = candidate.add(const Duration(days: 1));
        if (candidate.weekday <= DateTime.friday) remaining--;
      }
      return candidate;
    case RecurrenceFrequency.monthly:
      final targetMonth = DateTime(seedStart.year, seedStart.month + (rule.interval * index), 1);
      final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
      final day = current.day.clamp(1, lastDay);
      return DateTime(
        targetMonth.year,
        targetMonth.month,
        day,
        seedStart.hour,
        seedStart.minute,
        seedStart.second,
        seedStart.millisecond,
        seedStart.microsecond,
      );
    case RecurrenceFrequency.none:
      return current;
  }
}


