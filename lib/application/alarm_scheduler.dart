import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/event.dart';
import 'alarm_alert.dart';
import 'tts_service.dart';

// Payload format: "eventId|slotIndex|minutesBefore|title|note"

/// Schedules local notification alarms and native Android TTS alarms for
/// [NextAEvent].
///
/// Android uses exact, while-idle scheduling. The notification is handled by
/// flutter_local_notifications, while speech is scheduled through a small
/// native Kotlin receiver so it can run when Flutter is in the background or
/// not running at all.
class AlarmScheduler {
  AlarmScheduler._(this._plugin, this._tts);

  final FlutterLocalNotificationsPlugin _plugin;
  final TtsService _tts;

  static const _defaultChannelId = 'nexta_reminder_v4_default';
  static const _highChannelId = 'nexta_reminder_v4_high';
  static const _maxChannelId = 'nexta_reminder_v4_max';
  static const _channelName = 'NextA - Nhắc sự kiện';
  static const _channelDescription = 'Nhắc trước khi sự kiện bắt đầu';
  static const AndroidNotificationSound _alarmSound =
      UriAndroidNotificationSound('content://settings/system/alarm_alert');

  static const MethodChannel _nativeTtsChannel =
      MethodChannel('com.nexta/alarm_tts');

  static AlarmScheduler? _instance;
  static bool _timezoneReady = false;
  static bool _exactAlarmPermissionPrompted = false;

  static Future<AlarmScheduler> init(TtsService tts) async {
    if (_instance != null) return _instance!;

    _initTimezone();

    final plugin = FlutterLocalNotificationsPlugin();

    void onResponse(NotificationResponse r) {
      // Full-screen notifications are reported through the same response
      // callback. Show the dedicated acknowledgement screen without opening
      // the planner.
      AlarmAlertController.emitPayload(r.payload);
    }

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

    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      AlarmAlertController.emitPayload(launchDetails?.notificationResponse?.payload);
    }

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

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.defaultImportance,
        playSound: true,
        sound: _alarmSound,
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
        sound: _alarmSound,
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
        sound: _alarmSound,
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

  static Future<void> _syncTimezone() async {
    _initTimezone();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('NextA alarm timezone lookup failed: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;

    await androidImpl.requestNotificationsPermission();

    // Android 14+ can keep USE_FULL_SCREEN_INTENT disabled even when it is
    // declared in AndroidManifest. Without this permission a full-screen
    // alarm falls back to a heads-up notification, which is exactly the
    // symptom where the user must tap the notification to reach AlarmScreen.
    try {
      final fullScreenGranted =
          await androidImpl.requestFullScreenIntentPermission() ?? false;
      debugPrint('NextA full-screen alarm permission: $fullScreenGranted');
    } catch (e) {
      debugPrint('NextA full-screen alarm permission request failed: $e');
    }

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

    if (_exactAlarmPermissionPrompted) {
      debugPrint('NextA exact alarm permission is still not granted.');
      return false;
    }

    _exactAlarmPermissionPrompted = true;
    try {
      await androidImpl.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('NextA exact alarm permission request failed: $e');
      return false;
    }

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

  @pragma('vm:entry-point')
  static void _backgroundTap(NotificationResponse r) {
    // Full-screen/tap handling is kept in the foreground activity callback.
  }

  Future<void> scheduleEvent(NextAEvent event) async {
    if (event.reminderMinutes <= 0) return;

    await _syncTimezone();

    final now = DateTime.now();
    final firstAlarm =
        event.start.subtract(Duration(minutes: event.reminderMinutes));
    if (!firstAlarm.isAfter(now)) return;

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

      await _scheduleNativeTts(event, slot, minutesBefore, alarmTime);
    }
  }

  Future<void> _scheduleNativeTts(
    NextAEvent event,
    int slot,
    int minutesBefore,
    DateTime alarmTime,
  ) async {
    final text = _buildNativeAnnouncement(
      event,
      slot: slot,
      minutesBefore: minutesBefore,
    );
    try {
      await _nativeTtsChannel.invokeMethod<void>('schedule', {
        'requestKey': '${event.id}:$slot',
        'atMillis': alarmTime.millisecondsSinceEpoch,
        'text': text,
      });
    } catch (e) {
      debugPrint('NextA native TTS schedule failed: $e');
    }
  }

  String _buildNativeAnnouncement(
    NextAEvent event, {
    required int slot,
    required int minutesBefore,
  }) {
    final buffer = StringBuffer();

    if (slot > 0) {
      buffer.write('Nhắc lại. ');
    } else if (minutesBefore > 0) {
      if (minutesBefore < 60) {
        buffer.write('Còn $minutesBefore phút nữa. ');
      } else {
        final hours = minutesBefore ~/ 60;
        final minutes = minutesBefore % 60;
        buffer.write('Còn $hours tiếng');
        if (minutes > 0) buffer.write(' $minutes phút');
        buffer.write(' nữa. ');
      }
    }

    buffer.write('${event.title}.');
    if (event.location != null && event.location!.trim().isNotEmpty) {
      buffer.write(' Địa điểm: ${event.location!.trim()}.');
    }
    if (event.note != null && event.note!.trim().isNotEmpty) {
      buffer.write(' ${event.note!.trim()}.');
    }

    final result = buffer.toString().trim();
    return result.length <= 320 ? result : '${result.substring(0, 317)}...';
  }

  Future<void> cancelEvent(String eventId) async {
    const maxSlots = 11;
    for (var slot = 0; slot < maxSlots; slot++) {
      await _plugin.cancel(_notifId(eventId, slot));
      try {
        await _nativeTtsChannel.invokeMethod<void>('cancel', {
          'requestKey': '$eventId:$slot',
        });
      } catch (e) {
        debugPrint('NextA native TTS cancel failed: $e');
      }
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
        sound: _alarmSound,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      ),
    );
  }
}
