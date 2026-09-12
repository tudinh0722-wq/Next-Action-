import '../data/event_database.dart';
import '../domain/event.dart';
import 'alarm_scheduler.dart';
import 'recurrence_policy.dart';

// ── Public result types ───────────────────────────────────────────────────────

/// A single parsed record, either valid or carrying validation errors.
class ImportRecord {
  const ImportRecord._({
    required this.raw,
    required this.index,
    this.event,
    required this.errors,
  });

  /// Raw text block that produced this record.
  final String raw;

  /// 0-based position in the source text.
  final int index;

  /// Non-null when validation passed.
  final NextAEvent? event;

  /// Human-readable validation errors; empty when valid.
  final List<String> errors;

  bool get isValid => errors.isEmpty && event != null;
}

/// Summary returned after a confirmed import.
class ImportSummary {
  const ImportSummary({required this.imported, required this.skipped});
  final int imported;
  final int skipped;
}

// ── Parser contract ───────────────────────────────────────────────────────────
// Format (each record separated by blank line or "---"):
//
//   TÊN: Thiết kế phần mềm
//   NGÀY: 2026-09-17            (or DD/MM/YYYY)
//   BẮT ĐẦU: 09:30             (HH:mm, 12h with AM/PM also accepted)
//   KẾT THÚC: 12:00
//   ĐỊA ĐIỂM: P1305-A1         (optional)
//   GHI CHÚ: Thực hành         (optional)
//   ƯU TIÊN: 1                  (0 low, 1 medium, 2 high — optional)
//   BÁO TRƯỚC: 10              (minutes — optional, default 10)
//   LẶP LẠI: weekly / daily / weekdays / monthly / none  (optional)
//   LẶP LẠI_SỐ: 10            (count — optional, default 10)
// ─────────────────────────────────────────────────────────────────────────────

class BulkImportService {
  const BulkImportService({
    required this.database,
    required this.scheduler,
  });

  final EventDatabase database;
  final AlarmScheduler scheduler;

  // ── Parse ─────────────────────────────────────────────────────────────────

  /// Parses [text] into a list of [ImportRecord]s without touching the DB.
  List<ImportRecord> parse(String text) {
    final blocks = _splitBlocks(text);
    final records = <ImportRecord>[];
    for (var i = 0; i < blocks.length; i++) {
      records.add(_parseBlock(blocks[i], i));
    }
    return records;
  }

  // ── Persist ───────────────────────────────────────────────────────────────

  /// Persists only the valid records from [records] and schedules their
  /// reminders. Returns a summary.
  Future<ImportSummary> confirm(List<ImportRecord> records) async {
    final valid = records.where((r) => r.isValid).toList();
    int imported = 0;

    for (final record in valid) {
      final event = record.event!;
      final rule = event.recurrenceRule;
      List<NextAEvent> toInsert;
      if (rule != null && rule.frequency != RecurrenceFrequency.none) {
        toInsert = generateOccurrences(event, rule: rule);
      } else {
        toInsert = [event];
      }
      await database.upsertAll(toInsert);
      for (final e in toInsert) {
        await scheduler.scheduleEvent(e);
      }
      imported += toInsert.length;
    }

    return ImportSummary(
      imported: imported,
      skipped: records.length - valid.length,
    );
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  List<String> _splitBlocks(String text) {
    // Split on blank lines or explicit "---" separators.
    final raw = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = raw
        .split(RegExp(r'\n\s*\n|\n---+\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    return blocks;
  }

  ImportRecord _parseBlock(String block, int index) {
    final fields = <String, String>{};
    for (final line in block.split('\n')) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon).trim().toUpperCase();
      final value = line.substring(colon + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        fields[key] = value;
      }
    }

    final errors = <String>[];

    // Title
    final title = fields['TÊN'] ?? fields['TEN'] ?? '';
    if (title.isEmpty) errors.add('Thiếu tên sự kiện (TÊN:)');

    // Date
    final dateStr = fields['NGÀY'] ?? fields['NGAY'] ?? '';
    DateTime? date = _parseDate(dateStr);
    if (date == null) {
      errors.add('Thiếu hoặc sai định dạng ngày (NGÀY: YYYY-MM-DD hoặc DD/MM/YYYY)');
    }

    // Start time
    final startStr = fields['BẮT ĐẦU'] ?? fields['BAT DAU'] ?? fields['BẮT_ĐẦU'] ?? '';
    final startTime = _parseTime(startStr);
    if (startTime == null) {
      errors.add('Thiếu hoặc sai giờ bắt đầu (BẮT ĐẦU: HH:mm)');
    }

    // End time
    final endStr = fields['KẾT THÚC'] ?? fields['KET THUC'] ?? fields['KẾT_THÚC'] ?? '';
    final endTime = _parseTime(endStr);
    if (endTime == null) {
      errors.add('Thiếu hoặc sai giờ kết thúc (KẾT THÚC: HH:mm)');
    }

    if (errors.isNotEmpty) {
      return ImportRecord._(raw: block, index: index, errors: errors);
    }

    final startDt = DateTime(
        date!.year, date.month, date.day, startTime!.$1, startTime.$2);
    final endDt =
        DateTime(date.year, date.month, date.day, endTime!.$1, endTime.$2);

    if (!endDt.isAfter(startDt)) {
      errors.add('Giờ kết thúc phải sau giờ bắt đầu');
    }

    if (errors.isNotEmpty) {
      return ImportRecord._(raw: block, index: index, errors: errors);
    }

    // Optional fields
    final locationRaw = fields['ĐỊA ĐIỂM'] ?? fields['DIA DIEM'] ?? fields['ĐỊA_ĐIỂM'];
    final location = (locationRaw?.isEmpty ?? true) ? null : locationRaw;
    final noteRaw = fields['GHI CHÚ'] ?? fields['GHI_CHÚ'] ?? fields['GHI CHU'];
    final note = (noteRaw?.isEmpty ?? true) ? null : noteRaw;
    final priority = int.tryParse(fields['ƯU TIÊN'] ?? fields['UU TIEN'] ?? '') ?? 0;
    final reminderMinutes =
        int.tryParse(fields['BÁO TRƯỚC'] ?? fields['BAO TRUOC'] ?? '') ?? 10;

    // Validate priority
    if (priority < 0 || priority > 2) {
      errors.add('Ưu tiên phải là 0, 1 hoặc 2');
    }
    if (reminderMinutes < 0 || reminderMinutes > 10080) {
      errors.add('Báo trước phải trong khoảng 0–10080 phút');
    }
    if (errors.isNotEmpty) {
      return ImportRecord._(raw: block, index: index, errors: errors);
    }

    // Recurrence
    final recurrenceStr =
        (fields['LẶP LẠI'] ?? fields['LAP LAI'] ?? 'none').toLowerCase().trim();
    RecurrenceFrequency frequency;
    switch (recurrenceStr) {
      case 'daily':
      case 'hàng ngày':
      case 'hang ngay':
        frequency = RecurrenceFrequency.daily;
        break;
      case 'weekly':
      case 'hàng tuần':
      case 'hang tuan':
        frequency = RecurrenceFrequency.weekly;
        break;
      case 'weekdays':
      case 'ngày trong tuần':
        frequency = RecurrenceFrequency.weekdays;
        break;
      case 'monthly':
      case 'hàng tháng':
      case 'hang thang':
        frequency = RecurrenceFrequency.monthly;
        break;
      default:
        frequency = RecurrenceFrequency.none;
    }

    final recurrenceCount =
        int.tryParse(fields['LẶP LẠI_SỐ'] ?? fields['LAP LAI SO'] ?? '') ?? 10;
    if (frequency != RecurrenceFrequency.none &&
        (recurrenceCount < 1 || recurrenceCount > 366)) {
      errors.add('Số lần lặp lại phải trong khoảng 1–366');
      return ImportRecord._(raw: block, index: index, errors: errors);
    }

    RecurrenceRule? rule;
    if (frequency != RecurrenceFrequency.none) {
      rule = RecurrenceRule(
        frequency: frequency,
        endMode: RecurrenceEndMode.count,
        count: recurrenceCount,
      );
    }

    final id = '${startDt.millisecondsSinceEpoch}_${title.hashCode.abs()}';
    final event = NextAEvent(
      id: id,
      title: title,
      type: EventType.classEvent,
      start: startDt,
      end: endDt,
      location: location,
      note: note,
      priority: priority.clamp(0, 2).toInt(),
      recurrenceId: rule != null ? id : null,
      recurrenceRule: rule,
      reminderMinutes: reminderMinutes,
      reminderRepeatCount: 2,
      reminderRepeatIntervalMinutes: 5,
    );

    return ImportRecord._(raw: block, index: index, event: event, errors: const []);
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    // ISO: 2026-09-17
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (iso != null) {
      final y = int.parse(iso.group(1)!);
      final m = int.parse(iso.group(2)!);
      final d = int.parse(iso.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(y, m, d);
    }
    // DD/MM/YYYY or D/M/YYYY
    final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (dmy != null) {
      final d = int.parse(dmy.group(1)!);
      final m = int.parse(dmy.group(2)!);
      final y = int.parse(dmy.group(3)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(y, m, d);
    }
    return null;
  }

  /// Returns (hour, minute) or null.
  (int, int)? _parseTime(String s) {
    if (s.isEmpty) return null;
    final upper = s.toUpperCase().replaceAll(' ', '');
    // HH:mm or H:mm  (24h)
    final hm = RegExp(r'^(\d{1,2}):(\d{2})(?:AM|PM)?$').firstMatch(upper);
    if (hm != null) {
      var h = int.parse(hm.group(1)!);
      final m = int.parse(hm.group(2)!);
      if (upper.endsWith('PM') && h < 12) h += 12;
      if (upper.endsWith('AM') && h == 12) h = 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59) return (h, m);
    }
    return null;
  }
}
