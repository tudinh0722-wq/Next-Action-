import '../data/event_database.dart';
import '../domain/event.dart';

/// Development-only data used to exercise alarms, notifications and widgets.
///
/// Delete this file and its single call from main.dart when testing is done.
const firstRunTestEventId = '__nexta_first_run_test_event__';

Future<void> ensureFirstRunTestEvent(EventDatabase database) async {
  final events = await database.getAll();
  if (events.any((event) => event.id == firstRunTestEventId)) return;

  final now = DateTime.now();
  final start = now.add(const Duration(minutes: 2));
  final end = start.add(const Duration(minutes: 15));

  await database.upsert(
    NextAEvent(
      id: firstRunTestEventId,
      title: '[TEST] Alarm & Widget',
      type: EventType.other,
      start: start,
      end: end,
      location: 'Development test',
      note: 'Tự tạo lần đầu để test alarm + widget',
      priority: 2,
      reminderMinutes: 1,
      reminderRepeatCount: 2,
      reminderRepeatIntervalMinutes: 1,
    ),
  );
}
