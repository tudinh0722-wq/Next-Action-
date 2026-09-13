import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/event.dart';

class WidgetBridge {
  WidgetBridge._();

  static const MethodChannel _channel = MethodChannel('com.nexta/widget');

  static Future<void> syncEvents(List<NextAEvent> events) async {
    final payload = events
        .where((event) => event.end.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final json = jsonEncode(
      payload.take(2).map(_toJson).toList(),
    );

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

  static Map<String, Object?> _toJson(NextAEvent event) => {
        'id': event.id,
        'title': event.title,
        'start': event.start.millisecondsSinceEpoch,
        'end': event.end.millisecondsSinceEpoch,
        'location': event.location,
      };
}
