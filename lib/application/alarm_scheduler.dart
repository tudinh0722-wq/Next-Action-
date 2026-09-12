import 'dart:async';

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
/// Android uses exact, while-idle scheduling and dedicated alarm notification
/// channels. The channel audio attributes use the Android alarm stream so a
/// reminder is not silently routed to a muted notification channel.
class AlarmScheduler {
  AlarmScheduler._(this._plugin, this._tts);

  final FlutterLocalNotificationsPlugin _plugin;
  final TtsService _tts;

  static const _defaultChannelId = 'nexta_reminder_v3_default';
  static const _highChannelId = 'nexta_reminder_v3_high';
  static const _maxChannelId = 'nexta_reminder_v3_max';
  static const _channelName = 'NextA - Nhắc sự kiện';
  static const _channelDescription = 'Nhắc trước khi sự kiện bắt đầu';

  static AlarmScheduler? _instance;
  static bool _timezoneReady = false;
  static bool _exactAlarmPermissionPrompted = false;

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

    await _configureAndroidChannels(plugin);

    _instance = AlarmScheduler._(plugin, tts);
    await _instance!._requestPermissions();
    return _instance!;
  }

  static Future<void> _configureAndroidChannels(
      FlutterLocalNotificationsPlugin plugin) async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    // Use a new channel generation deliberately. Android persists channel
    // sound/importance settings, so changing Dart details cannot repair an
    // already-created channel that the user/system configured as silent.
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _highChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _maxChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
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

    // Do not force the user into Android Settings during app startup. Exact
    // alarm access is requested lazily when an event actually needs an alarm.
    final hasExact =
        await androidImpl.canScheduleExactNotifications() ?? false;
    if (!hasExact) {
      debugPrint('NextA exact alarm permission is not currently granted.');
    }
  }

  Future<bool> _ensureExactAlarmPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;

    final granted =
        await androidImpl.canScheduleExactNotifications() ?? false;
    if (granted) return true;

    if (!_exactAlarmPermissionPrompted) {
      _exactAlarmPermissionPrompted = true;
      try {
        await androidImpl.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('NextA exact alarm permission request failed: $e');
      }
    }

    // Give the user time to return from the system permission screen. This is
    // only used when scheduling an actual reminder, never during app startup.
    const maxWait = Duration(seconds: 45);
    const interval = Duration(seconds: 1);
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      final nowGranted =
          await androidImpl.canScheduleExactNotifications() ?? false;
      if (nowGranted) return true;
    }

    debugPrint('NextA exact alarm permission was not granted.');
    return false;
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

    final now = DateTime.now();
    final firstAlarm =
        event.start.subtract(Duration(minutes: event.reminderMinutes));
    if (!firstAlarm.isAfter(now)) return;

    // Keep already-scheduled alarms intact if exact-alarm access is unavailable.
    if (!await _ensureExactAlarmPermission()) return;

    await cancelEvent(event.id);

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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
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
            ? '$minutesBefore phút nữa'
            : '${minutesBefore ~/ 60}h${minutesBefore % 60 > 0 ? '${minutesBefore % 60}p' : ''} nữa')
        : 'Đang diễn ra';
    final context = parts.isEmpty ? '' : '${parts.join(' · ')} · ';
    return '$context$timeStr ($reminder)';
  }

  NotificationDetails _details(int priority) {
    final channelId = priority >= 2
        ? _maxChannelId
        : priority == 1
            ? _highChannelId
            : _defaultChannelId;
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
        channelId,
        _channelName,
        channelDescription: _channelDescription,
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
