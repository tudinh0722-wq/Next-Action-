import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around [FlutterTts] with Vietnamese defaults.
/// Exposes a single [speak] method used by the alarm flow.
class TtsService {
  TtsService._();

  static TtsService? _instance;
  late final FlutterTts _tts;
  bool _ready = false;

  static Future<TtsService> init() async {
    if (_instance != null) return _instance!;
    final svc = TtsService._();
    await svc._setup();
    _instance = svc;
    return svc;
  }

  Future<void> _setup() async {
    _tts = FlutterTts();
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(0.48);  // comfortable Vietnamese reading speed
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Prefer offline engine on Android when available.
    await _tts.setSharedInstance(true);
    _ready = true;
  }

  /// Speak [text] immediately, interrupting any in-progress speech.
  Future<void> speak(String text) async {
    if (!_ready || text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stop any ongoing speech.
  Future<void> stop() async {
    if (!_ready) return;
    await _tts.stop();
  }

  /// Build the announcement text for an alarm slot.
  ///
  /// Structure: [pre-announcement] pause [title] pause [note if any]
  ///
  /// Example:
  ///   "Nhắc nhở: Phát triển ứng dụng TMĐT. Thực hành."
  static String buildAnnouncement({
    required String title,
    String? note,
    int minutesBefore = 0,
    bool isRepeat = false,
  }) {
    final buffer = StringBuffer();

    if (isRepeat) {
      buffer.write('Nhắc lại. ');
    } else if (minutesBefore > 0) {
      final timeStr = minutesBefore < 60
          ? '$minutesBefore phút nữa'
          : '${minutesBefore ~/ 60} tiếng ${minutesBefore % 60 > 0 ? '${minutesBefore % 60} phút ' : ''}nữa';
      buffer.write('Còn $timeStr. ');
    }

    buffer.write('$title.');

    if (note != null && note.trim().isNotEmpty) {
      buffer.write(' ${note.trim()}.');
    }

    return buffer.toString();
  }
}
