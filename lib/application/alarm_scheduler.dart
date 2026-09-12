import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/event.dart';
import 'tts_service.dart';

// Payload format: "eventId|slotIndex|minutesBefore|title|note"

/// Schedules local notification alarms for [NextAEvent].
///
/// The scheduler deliberately uses the device IANA timezone and
/// `zonedSchedule`, so an event's wall-clock time is preserved correctly.
class AlarmScheduler {
  AlarmScheduler._(this._plugin, this._tts);

  final FlutterLocalNotificationsPlugin _plugin;
  final TtsService _tts;

  static AlarmScheduler? _instance;
  static bool _timezoneReady = false;

  static Future<AlarmScheduler> init(TtsService tts) async {
    if (_instance != null) return _instance!;

    _initTimezone();

    final plugin = FlutterLocalNotificationsPlugin();

    void onResponse(NotificationResponse r) => _handleResponse(tts, r);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundTap,
    );

    _instance = AlarmScheduler._(plugin, tts);
    await _instance!._requestPermissions();
    return _instance!;
  }

  static void _initTimezone() {
    if (_timezoneReady) return;
    tz.initializeTimeZones();
    _timezoneReady = true;
  }

  /// Refreshes the timezone from the OS before scheduling. This matters when
  /// the user travels or changes the device timezone while the app is open.
  static Future<void> _syncTimezone() async {
    _initTimezone();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      // The bundled database still has a safe default. Do not prevent the
      // planner from opening just because a platform timezone lookup failed.
      debugPrint('NextA alarm timezone lookup failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    await androidImpl.requestNotificationsPermission();

    final hasExact =
        await androidImpl.canScheduleExactNotifications() ?? false;
    if (hasExact) return;

    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();

    const maxWait = Duration(seconds: 30);
    const interval = Duration(seconds: 1);
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      final granted =
          await androidImpl.canScheduleExactNotifications() ?? false;
      if (granted) break;
    }
  }

  static Future<void> _handleResponse(
      TtsService tts, NotificationResponse r) async {
    final parts = (r.payload ?? '').split('|');
    if (parts.length < 5) return;
    final slotIndex = int.tryParse(parts[1]) ?? 0;
    final minutesBefore = int.tryParse(parts[2]) ?? 0;
    final title = parts[3];
    final note = parts[4].isNotEmpty ? parts[4] : null;

    final preText = TtsService.buildAnnouncement(
      title: title,
      note: note,
      minutesBefore: minutesBefore,
      isRepeat: slotIndex > 0,
    );
    await tts.speak(preText);

    if (slotIndex == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final postText = TtsService.buildAnnouncement(
        title: title,
        note: note,
        isRepeat: true,
      );
      await tts.speak(postText);
    }
  }

  @pragma('vm:entry-point')
  static void _backgroundTap(NotificationResponse r) {
    // TTS is intentionally not started from a notification background isolate.
  }

  Future<void> scheduleEvent(NextAEvent event) async {
    if (event.reminderMinutes <= 0) return;

    await _syncTimezone();
    await cancelEvent(event.id);

    final now = DateTime.now();
    final firstAlarm =
        event.start.subtract(Duration(minutes: event.reminderMinutes));
    if (!firstAlarm.isAfter(now)) return;

    final totalSlots = 1 + event.reminderRepeatCount.clamp(0, 10);
    for (var slot = 0; slot < totalSlots; slot++) {
      final alarmTime = firstAlarm.add(Duration(
        minutes: slot * event.reminderRepeatIntervalMinutes,
      ));
      if (!alarmTime.isAfter(now)) continue;

      final minutesBefore = event.reminderMinutes -
          slot * event.reminderRepeatIntervalMinutes;
      final payload =
          '${event.id}|$slot|$minutesBefore|${event.title}|${event.note ?? ''}';

      final scheduledDate = tz.TZDateTime(
        tz.local,
        alarmTime.year,
        alarmTime.month,
        alarmTime.day,
        alarmTime.hour,
        alarmTime.minute,
        alarmTime.second,
      );

      await _plugin.zonedSchedule(
        _notifId(event.id, slot),
        event.title,
        _notifBody(event, slot),
        scheduledDate,
        _details(event.priority),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  Future<void> cancelEvent(String eventId) async {
    const maxSlots = 11;
    for (var slot = 0; slot < maxSlots; slot++) {
      await _plugin.cancel(_notifId(eventId, slot));
    }
  }

  Future<void> scheduleAll(List<NextAEvent> events) async {
    for (final event in events) {
      try {
        await scheduleEvent(event);
      } catch (e, stack) {
        debugPrint('NextA alarm schedule failed for ${event.id}: $e');
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  int _notifId(String eventId, int slot) =>
      ('$eventId:$slot').hashCode.abs() & 0x7FFFFFFF;

  String _notifBody(NextAEvent event, int slot) {
    final minutesBefore =
        event.reminderMinutes - slot * event.reminderRepeatIntervalMinutes;
    final parts = <String>[];
    if (event.location != null && event.location!.isNotEmpty) {
      parts.add(event.location!);
    }
    if (event.note != null && event.note!.isNotEmpty) {
      parts.add(event.note!);
    }
    final timeStr =
        '${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')}';
    final reminder = minutesBefore > 0
        ? (minutesBefore < 60
            ? '$minutesBefore phÃºt ná»¯a'
            : '${minutesBefore ~/ 60}h${minutesBefore % 60 > 0 ? '${minutesBefore % 60}p' : ''} ná»¯a')
        : 'Äang diá»…n ra';
    final context = parts.isEmpty ? '' : '${parts.join(' Â· ')} Â· ';
    return '$context$timeStr ($reminder)';
  }

  NotificationDetails _details(int priority) {
    final importance = priority >= 2
        ? Importance.max
        : priority == 1
            ? Importance.high
            : Importance.defaultImportance;
    final notifPriority = priority >= 2
        ? Priority.max
        : priority == 1
            ? Priority.high
            : Priority.defaultPriority;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        'nexta_reminder_v2',
        'Nháº¯c nhá»Ÿ sá»± kiá»‡n',
        channelDescription:
            'ThÃ´ng bÃ¡o nháº¯c nhá»Ÿ trÆ°á»›c khi sá»± kiá»‡n báº¯t Ä‘áº§u',
        importance: importance,
        priority: notifPriority,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );
  }
}

