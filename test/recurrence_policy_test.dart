import 'package:flutter_test/flutter_test.dart';

import 'package:nexta/application/recurrence_policy.dart';
import 'package:nexta/domain/event.dart';

void main() {
  final seed = NextAEvent(
    id: 'event-1',
    title: 'Láº­p trÃ¬nh',
    type: EventType.classEvent,
    start: DateTime(2026, 9, 7, 8),
    end: DateTime(2026, 9, 7, 10),
  );

  test('daily recurrence creates concrete occurrences with shared series id', () {
    final occurrences = generateOccurrences(
      seed,
      rule: RecurrenceRule(
        frequency: RecurrenceFrequency.daily,
        interval: 1,
        until: DateTime(2026, 9, 9, 23, 59),
      ),
    );

    expect(occurrences.map((event) => event.start.day), [7, 8, 9]);
    expect(occurrences.map((event) => event.recurrenceId), ['event-1', 'event-1', 'event-1']);
    expect(occurrences[1].end.difference(occurrences[1].start), const Duration(hours: 2));
  });

  test('weekly recurrence advances by complete weeks', () {
    final occurrences = generateOccurrences(
      seed,
      rule: RecurrenceRule(
        frequency: RecurrenceFrequency.weekly,
        interval: 1,
        until: DateTime(2026, 9, 28, 23, 59),
      ),
    );

    expect(occurrences.map((event) => event.start.day), [7, 14, 21, 28]);
  });

  test('monthly recurrence clamps invalid month days', () {
    final monthEndSeed = NextAEvent(
      id: 'month-end',
      title: 'Há»c',
      type: EventType.classEvent,
      start: DateTime(2026, 1, 31, 8),
      end: DateTime(2026, 1, 31, 9),
    );

    final occurrences = generateOccurrences(
      monthEndSeed,
      rule: RecurrenceRule(
        frequency: RecurrenceFrequency.monthly,
        interval: 1,
        until: DateTime(2026, 4, 30),
      ),
    );

    expect(
      occurrences.map((event) => '${event.start.year}-${event.start.month}-${event.start.day}'),
      ['2026-1-31', '2026-2-28', '2026-3-28', '2026-4-28'],
    );
  });
}


