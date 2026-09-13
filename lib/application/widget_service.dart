import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/event.dart';

/// Sends the next 2 upcoming events to the Android home-screen widget via
/// the "com.nexta/widget_update" MethodChannel.
///
/// Call [push] after any change to the in-memory event list so the widget
/// always reflects the most recent state.
class WidgetService {
  WidgetService._();

  static const _channel = MethodChannel('com.nexta/widget_update');

  /// Picks the 2 events that start soonest after now (or are currently
  /// ongoing) and sends them to the widget.  Safe to call on non-Android
  /// platforms — the channel invoke is swallowed silently.
  static Future<void> push(List<NextAEvent> events) async {
    final now = DateTime.now();

    // Sort by start time, keep ongoing + future only.
    final upcoming = events
        .where((e) => e.end.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final slot0 = upcoming.isNotEmpty ? upcoming[0] : null;
    final slot1 = upcoming.length > 1 ? upcoming[1] : null;

    try {
      await _channel.invokeMethod<void>('update', {
        // Slot 0
        'slot0_title':     slot0?.title     ?? '',
        'slot0_time':      slot0 != null ? _formatTime(slot0) : '',
        'slot0_location':  slot0?.location  ?? '',
        'slot0_countdown': slot0 != null ? _formatCountdown(slot0, now) : '',
        'slot0_priority':  slot0?.priority  ?? 0,
        // Slot 1
        'slot1_title':     slot1?.title     ?? '',
        'slot1_time':      slot1 != null ? _formatTime(slot1) : '',
        'slot1_location':  slot1?.location  ?? '',
        'slot1_countdown': slot1 != null ? _formatCountdown(slot1, now) : '',
        'slot1_priority':  slot1?.priority  ?? 0,
      });
    } on MissingPluginException {
      // Running on non-Android (tests, desktop) — ignore.
    } catch (e) {
      debugPrint('NextA WidgetService.push failed: $e');
    }
  }

  static String _formatTime(NextAEvent e) {
    final s = e.start;
    final end = e.end;
    return '${_hm(s)} – ${_hm(end)}';
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _formatCountdown(NextAEvent e, DateTime now) {
    final ongoing = !now.isBefore(e.start) && now.isBefore(e.end);
    final target  = ongoing ? e.end : e.start;
    final diff    = target.difference(now);

    if (diff.isNegative) return '';

    final label = ongoing ? 'còn' : 'sau';
    if (diff.inMinutes < 1)  return '$label < 1 phút';
    if (diff.inMinutes < 60) return '$label ${diff.inMinutes} phút';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return m == 0 ? '$label ${h}h' : '$label ${h}h${m}p';
  }
}
