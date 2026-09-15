import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/event.dart';

class WidgetBridge {
  WidgetBridge._();

  static const MethodChannel _channel = MethodChannel('com.nexta/widget');
  static Timer? _pendingEventPoller;

  static void setEventOpenHandler(ValueChanged<String>? handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'openEvent') return null;

      final eventId = call.arguments as String?;
      if (eventId != null && eventId.isNotEmpty) {
        handler?.call(eventId);
      }

      return null;
    });

    // Keep a small pending-intent poller alive while the app is running.
    // Android may deliver a widget tap through onNewIntent() while the Flutter
    // activity is being resumed. In that case the native side stores the ID;
    // polling makes the warm-start path reliable even if the MethodChannel
    // message races with Flutter's lifecycle.
    _pendingEventPoller?.cancel();
    if (handler == null) return;

    _pendingEventPoller = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final eventId = await getPendingEventId();
      if (eventId != null && eventId.isNotEmpty) {
        handler(eventId);
      }
    });
  }

  static Future<void> syncEvents(List<NextAEvent> events) async {
    final now = DateTime.now();
    final payload = events.where((event) => event.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final json = jsonEncode(payload.take(2).map(_toJson).toList());

    try {
      await _channel.invokeMethod<void>('syncEvents', {'events': json});
    } on MissingPluginException {
      // The bridge is Android-specific. Other platforms simply skip it.
    } on PlatformException {
      // Widget sync must never block normal planner operations.
    }
  }

  static Future<String?> getInitialEventId() async {
    try {
      return await _channel.invokeMethod<String>('getInitialEventId');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<String?> getPendingEventId() async {
    try {
      return await _channel.invokeMethod<String>('getPendingEventId');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Map<String, Object?> _toJson(NextAEvent event) => {
        'id': event.id,
        'title': event.title,
        'start': event.start.millisecondsSinceEpoch,
        'end': event.end.millisecondsSinceEpoch,
        'location': event.location,
        'note': event.note,
      };
}
