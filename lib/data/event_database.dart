import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/event.dart';

class EventDatabase {
  EventDatabase._(this._db);

  final Database _db;

  static Future<EventDatabase> open() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'nexta.db');
    final db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE events (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            type INTEGER NOT NULL,
            start_ms INTEGER NOT NULL,
            end_ms INTEGER NOT NULL,
            location TEXT,
            note TEXT,
            priority INTEGER NOT NULL DEFAULT 0,
            recurrence_id TEXT,
            recurrence_frequency INTEGER,
            recurrence_interval INTEGER,
            recurrence_end_mode INTEGER,
            recurrence_count INTEGER,
            recurrence_until_ms INTEGER,
            reminder_minutes INTEGER NOT NULL DEFAULT 10,
            reminder_repeat_count INTEGER NOT NULL DEFAULT 2,
            reminder_repeat_interval_minutes INTEGER NOT NULL DEFAULT 5
          )
        ''');
        await db.execute('CREATE INDEX idx_events_start ON events(start_ms)');
        await db.execute('CREATE INDEX idx_events_search_title ON events(title)');
        await db.execute('CREATE INDEX idx_events_recurrence_id ON events(recurrence_id)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE events ADD COLUMN recurrence_end_mode INTEGER');
          await db.execute('ALTER TABLE events ADD COLUMN recurrence_count INTEGER');
          await db.execute('UPDATE events SET recurrence_end_mode = 0, recurrence_count = 20 WHERE recurrence_frequency IS NOT NULL AND recurrence_frequency != 0');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_events_recurrence_id ON events(recurrence_id)');
        }
        if (oldVersion < 3) {
          final columns = await db.rawQuery('PRAGMA table_info(events)');
          final hasPriority = columns.any((row) => row['name'] == 'priority');
          if (!hasPriority) {
            await db.execute('ALTER TABLE events ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
          }
        }
      },
    );
    return EventDatabase._(db);
  }

  Future<List<NextAEvent>> getAll() async {
    final rows = await _db.query('events', orderBy: 'start_ms ASC');
    return rows.map(_fromRow).toList();
  }

  Future<List<NextAEvent>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return getAll();
    final pattern = '%$q%';
    final rows = await _db.query(
      'events',
      where: 'title LIKE ? OR location LIKE ? OR note LIKE ?',
      whereArgs: [pattern, pattern, pattern],
      orderBy: 'start_ms ASC',
      limit: 50,
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> replaceAll(List<NextAEvent> events) async {
    await _db.transaction((txn) async {
      for (final event in events) {
        await txn.insert('events', _toRow(event), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> upsert(NextAEvent event) async {
    await _db.insert('events', _toRow(event), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertAll(List<NextAEvent> events) async {
    await _db.transaction((txn) async {
      for (final event in events) {
        await txn.insert('events', _toRow(event), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> delete(String id) => _db.delete('events', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteSeries(String recurrenceId) => _db.delete('events', where: 'recurrence_id = ?', whereArgs: [recurrenceId]);

  Future<void> deleteSeriesFrom(String recurrenceId, DateTime start) => _db.delete(
        'events',
        where: 'recurrence_id = ? AND start_ms >= ?',
        whereArgs: [recurrenceId, start.millisecondsSinceEpoch],
      );

  Future<void> close() => _db.close();

  Map<String, Object?> _toRow(NextAEvent event) => {
        'id': event.id,
        'title': event.title,
        'type': event.type.index,
        'start_ms': event.start.millisecondsSinceEpoch,
        'end_ms': event.end.millisecondsSinceEpoch,
        'location': event.location,
        'note': event.note,
        'priority': event.priority.clamp(0, 2).toInt(),
        'recurrence_id': event.recurrenceId,
        'recurrence_frequency': event.recurrenceRule?.frequency.index,
        'recurrence_interval': event.recurrenceRule?.interval,
        'recurrence_end_mode': event.recurrenceRule?.endMode.index,
        'recurrence_count': event.recurrenceRule?.count,
        'recurrence_until_ms': event.recurrenceRule?.until?.millisecondsSinceEpoch,
        'reminder_minutes': event.reminderMinutes,
        'reminder_repeat_count': event.reminderRepeatCount,
        'reminder_repeat_interval_minutes': event.reminderRepeatIntervalMinutes,
      };

  NextAEvent _fromRow(Map<String, Object?> row) {
    final frequencyIndex = row['recurrence_frequency'] as int?;
    final recurrenceRule = frequencyIndex == null
        ? null
        : RecurrenceRule(
            frequency: RecurrenceFrequency.values[frequencyIndex],
            interval: (row['recurrence_interval'] as int?) ?? 1,
            endMode: RecurrenceEndMode.values[(row['recurrence_end_mode'] as int?) ?? 0],
            count: (row['recurrence_count'] as int?) ?? 20,
            until: row['recurrence_until_ms'] == null ? null : DateTime.fromMillisecondsSinceEpoch(row['recurrence_until_ms'] as int),
          );
    return NextAEvent(
      id: row['id'] as String,
      title: row['title'] as String,
      type: EventType.values[row['type'] as int],
      start: DateTime.fromMillisecondsSinceEpoch(row['start_ms'] as int),
      end: DateTime.fromMillisecondsSinceEpoch(row['end_ms'] as int),
      location: row['location'] as String?,
      note: row['note'] as String?,
      priority: ((row['priority'] as int?) ?? 0).clamp(0, 2).toInt(),
      recurrenceId: row['recurrence_id'] as String?,
      recurrenceRule: recurrenceRule,
      reminderMinutes: (row['reminder_minutes'] as int?) ?? 10,
      reminderRepeatCount: (row['reminder_repeat_count'] as int?) ?? 2,
      reminderRepeatIntervalMinutes: (row['reminder_repeat_interval_minutes'] as int?) ?? 5,
    );
  }
}
