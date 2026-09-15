import 'dart:async';

/// Data carried from the native notification into the Flutter alarm UI.
class AlarmAlert {
  const AlarmAlert({
    required this.eventId,
    required this.slotIndex,
    required this.minutesBefore,
    required this.title,
    this.note,
  });

  final String eventId;
  final int slotIndex;
  final int minutesBefore;
  final String title;
  final String? note;

  static AlarmAlert? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    final parts = payload.split('|');
    if (parts.length < 5) return null;

    final slotIndex = int.tryParse(parts[1]);
    final minutesBefore = int.tryParse(parts[2]);
    if (parts[0].isEmpty || slotIndex == null || minutesBefore == null) {
      return null;
    }

    return AlarmAlert(
      eventId: parts[0],
      slotIndex: slotIndex,
      minutesBefore: minutesBefore,
      title: parts[3],
      note: parts[4].trim().isEmpty ? null : parts[4],
    );
  }
}

/// Process-wide alarm state shared by notification callbacks and the app shell.
class AlarmAlertController {
  AlarmAlertController._();

  static final StreamController<AlarmAlert?> _controller =
      StreamController<AlarmAlert?>.broadcast();

  static AlarmAlert? _pending;

  static AlarmAlert? get pending => _pending;

  static Stream<AlarmAlert?> get stream => _controller.stream;

  static void emitPayload(String? payload) {
    final alert = AlarmAlert.fromPayload(payload);
    if (alert == null) return;

    _pending = alert;
    _controller.add(alert);
  }

  /// Clears the current alarm and notifies the app shell to return to Planner.
  static void consumePending() {
    if (_pending == null) return;
    _pending = null;
    _controller.add(null);
  }
}
