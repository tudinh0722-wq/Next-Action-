enum EventType {
  classEvent,
  exam,
  assignment,
  meeting,
  personal,
  other,
}

class NextAEvent {
  const NextAEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    required this.end,
    this.location,
    this.note,
    this.priority = 0,
    this.recurrenceId,
    this.recurrenceRule,
    this.reminderMinutes = 10,
    this.reminderRepeatCount = 2,
    this.reminderRepeatIntervalMinutes = 5,
  });

  final String id;
  final String title;
  final EventType type;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? note;
  final int priority;
  final String? recurrenceId;
  final RecurrenceRule? recurrenceRule;
  final int reminderMinutes;
  final int reminderRepeatCount;
  final int reminderRepeatIntervalMinutes;
}

enum RecurrenceEndMode { count, until }

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.endMode = RecurrenceEndMode.count,
    this.count = 20,
    this.until,
  })  : assert(interval > 0),
        assert(frequency == RecurrenceFrequency.none || endMode == RecurrenceEndMode.count ? count != null : true);

  final RecurrenceFrequency frequency;
  final int interval;
  final RecurrenceEndMode endMode;
  final int? count;
  final DateTime? until;
}

enum RecurrenceFrequency {
  none,
  daily,
  weekly,
  weekdays,
  monthly,
}
