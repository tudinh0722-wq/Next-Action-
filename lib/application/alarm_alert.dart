import 'dart:async';

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
    return AlarmAlert(
      eventId: parts[0],
      slotIndex: int.tryParse(parts[1]) ?? 0,
      minutesBefore: int.tryParse(parts[2]) ?? 0,
      title: parts[3],
      note: parts[4].isEmpty ? null : parts[4],
    );
  }
}

class AlarmAlertController {
  AlarmAlertController._();

  static final StreamController<AlarmAlert> _controller =
      StreamController<AlarmAlert>.broadcast();

  static AlarmAlert? _pending;

  static AlarmAlert? get pending => _pending;

  static Stream<AlarmAlert> get stream => _controller.stream;

  static void emitPayload(String? payload) {
    final alert = AlarmAlert.fromPayload(payload);
    if (alert == null) return;
    _pending = alert;
    _controller.add(alert);
  }

  static void consumePending() {
    _pending = null;
  }
}
