import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'application/alarm_scheduler.dart';
import 'application/tts_service.dart';
import 'data/event_database.dart';
import 'domain/event.dart';
import 'presentation/planner_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tts = await TtsService.init();
  final scheduler = await AlarmScheduler.init(tts);

  final database = await EventDatabase.open();
  var events = await database.getAll();
  if (events.isEmpty) {
    events = _buildDemoEvents();
    await database.replaceAll(events);
  }

  // Debug builds always get one fresh, deterministic alarm test event.
  // This is intentionally in Flutter, not the legacy Kotlin app.
  if (kDebugMode) {
    final testEvent = _buildDebugAlarmTestEvent();
    await database.upsert(testEvent);
    events = await database.getAll();
  }

  // Wait for scheduling so the first debug build cannot open with an
  // apparently-created test event whose alarms have not been registered yet.
  await scheduler.scheduleAll(events);

  runApp(NextAApp(
    database: database,
    scheduler: scheduler,
    tts: tts,
    initialEvents: events,
  ));
}

NextAEvent _buildDebugAlarmTestEvent() {
  final start = DateTime.now()
      .add(const Duration(minutes: 5))
      .copyWith(second: 0, millisecond: 0, microsecond: 0);

  return NextAEvent(
    id: '__nexta_debug_alarm_test__',
    title: 'TEST BÁO THỨC · 5 phút',
    type: EventType.other,
    start: start,
    end: start.add(const Duration(minutes: 1)),
    location: 'NextA alarm test',
    note: 'Báo trước 4 phút · lặp 2 lần · cách nhau 1 phút',
    priority: 2,
    reminderMinutes: 4,
    reminderRepeatCount: 2,
    reminderRepeatIntervalMinutes: 1,
  );
}

class NextAApp extends StatefulWidget {
  const NextAApp({
    super.key,
    required this.database,
    required this.scheduler,
    required this.tts,
    required this.initialEvents,
  });

  final EventDatabase database;
  final AlarmScheduler scheduler;
  final TtsService tts;
  final List<NextAEvent> initialEvents;

  @override
  State<NextAApp> createState() => _NextAAppState();
}

class _NextAAppState extends State<NextAApp> {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = const Color(0xFF1A73E8);

  ThemeData _theme(ColorScheme scheme) => ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        fontFamily: 'Roboto',
      );

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: _seedColor);
        final dark = darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.dark,
            );
        return MaterialApp(
          title: 'NextA',
          debugShowCheckedModeBanner: false,
          theme: _theme(light),
          darkTheme: _theme(dark),
          themeMode: _themeMode,
          home: PlannerScreen(
            events: widget.initialEvents,
            database: widget.database,
            scheduler: widget.scheduler,
            tts: widget.tts,
            themeMode: _themeMode,
            seedColor: _seedColor,
            onThemeChanged: (mode) => setState(() => _themeMode = mode),
            onSeedColorChanged: (color) =>
                setState(() => _seedColor = color),
          ),
        );
      },
    );
  }
}

// ── Demo data factory ──────────────────────────────────────────────────────────────
// DateTime is not const, so demo events must be created at runtime.

List<NextAEvent> _buildDemoEvents() {
  const r10 = (reminderMinutes: 10, repeatCount: 2, intervalMinutes: 5);
  const rTmdt = (reminderMinutes: 30, repeatCount: 2, intervalMinutes: 4);

  NextAEvent base({
    required String id,
    required String title,
    required EventType type,
    required DateTime start,
    required DateTime end,
    String? location,
    String? note,
    int priority = 0,
    required ({int reminderMinutes, int repeatCount, int intervalMinutes}) r,
  }) =>
      NextAEvent(
        id: id,
        title: title,
        type: type,
        start: start,
        end: end,
        location: location,
        note: note,
        priority: priority,
        reminderMinutes: r.reminderMinutes,
        reminderRepeatCount: r.repeatCount,
        reminderRepeatIntervalMinutes: r.intervalMinutes,
      );

  return [
    base(id: 'math', title: 'Giải tích', type: EventType.classEvent,
        start: DateTime(2026, 9, 10, 7, 30), end: DateTime(2026, 9, 10, 9),
        location: 'P. A204', r: r10),
    base(id: 'database', title: 'Cơ sở dữ liệu', type: EventType.classEvent,
        start: DateTime(2026, 9, 10, 9, 15), end: DateTime(2026, 9, 10, 11),
        location: 'P. B302', priority: 1, r: r10),
    base(id: 'assignment', title: 'Nộp bài lập trình', type: EventType.assignment,
        start: DateTime(2026, 9, 10, 23), end: DateTime(2026, 9, 10, 23, 30),
        priority: 2, r: r10),
    base(id: 'english', title: 'English presentation', type: EventType.classEvent,
        start: DateTime(2026, 9, 11, 8), end: DateTime(2026, 9, 11, 9, 30),
        r: r10),
    base(id: 'exam', title: 'Kiểm tra giữa kỳ', type: EventType.exam,
        start: DateTime(2026, 9, 14, 13, 30), end: DateTime(2026, 9, 14, 15),
        location: 'Hội trường A', priority: 2, r: r10),
    base(id: 'meeting', title: 'Họp nhóm NextA', type: EventType.meeting,
        start: DateTime(2026, 9, 16, 18, 30), end: DateTime(2026, 9, 16, 19, 30),
        r: r10),
    base(id: 'personal', title: 'Tập gym', type: EventType.personal,
        start: DateTime(2026, 9, 18, 17), end: DateTime(2026, 9, 18, 18),
        r: r10),
    base(id: 'tmdt_20260917', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 9, 17, 9, 30), end: DateTime(2026, 9, 17, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20260924', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 9, 24, 9, 30), end: DateTime(2026, 9, 24, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261001', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 10, 1, 9, 30), end: DateTime(2026, 10, 1, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261008', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 10, 8, 9, 30), end: DateTime(2026, 10, 8, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261015', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 10, 15, 9, 30), end: DateTime(2026, 10, 15, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261022', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 10, 22, 9, 30), end: DateTime(2026, 10, 22, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261029', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 10, 29, 9, 30), end: DateTime(2026, 10, 29, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261103', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 11, 3, 15, 10), end: DateTime(2026, 11, 3, 17, 45),
        location: 'P402-A9', note: 'Lý thuyết', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261110', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 11, 10, 15, 10), end: DateTime(2026, 11, 10, 17, 45),
        location: 'P402-A9', note: 'Lý thuyết', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261119', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 11, 19, 9, 30), end: DateTime(2026, 11, 19, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261201', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 12, 1, 15, 10), end: DateTime(2026, 12, 1, 17, 45),
        location: 'P402-A9', note: 'Lý thuyết', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261208', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 12, 8, 15, 10), end: DateTime(2026, 12, 8, 17, 45),
        location: 'P402-A9', note: 'Lý thuyết', priority: 1, r: rTmdt),
    base(id: 'tmdt_20261231', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2026, 12, 31, 9, 30), end: DateTime(2026, 12, 31, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
    base(id: 'tmdt_20270107', title: 'Phát triển ứng dụng TMĐT', type: EventType.classEvent,
        start: DateTime(2027, 1, 7, 9, 30), end: DateTime(2027, 1, 7, 12),
        location: 'P1305-A1', note: 'Thực hành', priority: 1, r: rTmdt),
  ];
}
