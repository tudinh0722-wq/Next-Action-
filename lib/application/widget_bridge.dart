import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/event.dart';

/// Android home-screen widget bridge.
///
/// Flutter remains the source of truth. The bridge only mirrors upcoming
/// events to Android; the native provider decides which two events to render.
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

    _pendingEventPoller?.cancel();
    if (handler == null) return;

    // Android can deliver a warm-start intent while Flutter is resuming.
    // Native MainActivity holds the ID until Flutter consumes it.
    _pendingEventPoller = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async {
        final eventId = await getPendingEventId();
        if (eventId != null && eventId.isNotEmpty) {
          handler(eventId);
        }
      },
    );
  }

  /// Mirror all upcoming events, not only the two currently visible ones.
  /// The native provider filters/sorts the cache and renders its top two.
  static Future<void> syncEvents(List<NextAEvent> events) async {
    final now = DateTime.now();
    final upcoming = events.where((event) => event.end.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    try {
      await _channel.invokeMethod<void>('syncEvents', {
        'events': jsonEncode(upcoming.map(_toJson).toList()),
      });
    } on MissingPluginException {
      // Android-only integration.
    } on PlatformException catch (error) {
      debugPrint('NextA widget sync failed: ${error.code}: ${error.message}');
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
        'priority': event.priority,
      };
}
