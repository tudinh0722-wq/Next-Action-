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

  final String raw;
  final int index;
  final NextAEvent? event;
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
// Each record is separated by a blank line or an explicit "---" line.
// Required: TÊN, NGÀY, BẮT ĐẦU, KẾT THÚC.
// Optional: ĐỊA ĐIỂM, GHI CHÚ, ƯU TIÊN, BÁO TRƯỚC, LẶP LẠI, LẶP LẠI_SỐ.
// ─────────────────────────────────────────────────────────────────────────────

class BulkImportService {
  const BulkImportService({
    required this.database,
    required this.scheduler,
  });

  final EventDatabase database;
  final AlarmScheduler scheduler;

  List<ImportRecord> parse(String text) {
    final blocks = _splitBlocks(text);
    return [
      for (var i = 0; i < blocks.length; i++) _parseBlock(blocks[i], i),
    ];
  }

  Future<ImportSummary> confirm(List<ImportRecord> records) async {
    final valid = records.where((r) => r.isValid).toList();
    var imported = 0;

    for (final record in valid) {
      final event = record.event!;
      final rule = event.recurrenceRule;
      final toInsert = rule != null && rule.frequency != RecurrenceFrequency.none
          ? generateOccurrences(event, rule: rule)
          : <NextAEvent>[event];

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

  List<String> _splitBlocks(String text) {
    final raw = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return raw
        .split(RegExp(r'\n\s*\n|\n---+\s*(?:\n|$)'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  ImportRecord _parseBlock(String block, int index) {
    final fields = <String, String>{};
    for (final line in block.split('\n')) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final key = line.substring(0, colon).trim().toUpperCase();
      final value = line.substring(colon + 1).trim();
      if (key.isNotEmpty) fields[key] = value;
    }

    final errors = <String>[];

    final title = fields['TÊN'] ?? fields['TEN'] ?? '';
    if (title.isEmpty) errors.add('Thiếu tên sự kiện (TÊN:)');

    final dateStr = fields['NGÀY'] ?? fields['NGAY'] ?? '';
    final date = _parseDate(dateStr);
    if (date == null) {
      errors.add('Thiếu hoặc sai ngày (YYYY-MM-DD hoặc DD/MM/YYYY)');
    }

    final startStr = fields['BẮT ĐẦU'] ?? fields['BAT DAU'] ?? fields['BẮT_ĐẦU'] ?? '';
    final startTime = _parseTime(startStr);
    if (startTime == null) errors.add('Thiếu hoặc sai giờ bắt đầu (HH:mm)');

    final endStr = fields['KẾT THÚC'] ?? fields['KET THUC'] ?? fields['KẾT_THÚC'] ?? '';
    final endTime = _parseTime(endStr);
    if (endTime == null) errors.add('Thiếu hoặc sai giờ kết thúc (HH:mm)');

    if (errors.isNotEmpty) {
      return ImportRecord._(raw: block, index: index, errors: errors);
    }

    final startDt = DateTime(
      date!.year,
      date.month,
      date.day,
      startTime!.$1,
      startTime.$2,
    );
    final endDt = DateTime(
      date.year,
      date.month,
      date.day,
      endTime!.$1,
      endTime.$2,
    );
    if (!endDt.isAfter(startDt)) errors.add('Giờ kết thúc phải sau giờ bắt đầu');

    final location = _optional(fields, ['ĐỊA ĐIỂM', 'DIA DIEM', 'ĐỊA_ĐIỂM']);
    final note = _optional(fields, ['GHI CHÚ', 'GHI_CHÚ', 'GHI CHU']);

    final priorityRaw = _optional(fields, ['ƯU TIÊN', 'UU TIEN']);
    final priority = priorityRaw == null ? 0 : int.tryParse(priorityRaw);
    if (priority == null || priority < 0 || priority > 2) {
      if (priorityRaw != null) errors.add('Ưu tiên phải là 0, 1 hoặc 2');
    }

    final reminderRaw = _optional(fields, ['BÁO TRƯỚC', 'BAO TRUOC']);
    final reminderMinutes = reminderRaw == null ? 10 : int.tryParse(reminderRaw);
    if (reminderMinutes == null || reminderMinutes < 0 || reminderMinutes > 10080) {
      if (reminderRaw != null) errors.add('Báo trước phải là số từ 0–10080 phút');
    }

    final recurrenceRaw = _optional(fields, ['LẶP LẠI', 'LAP LAI']) ?? 'none';
    final frequency = _parseFrequency(recurrenceRaw);
    if (frequency == null) {
      errors.add('Lặp lại không hợp lệ: $recurrenceRaw');
    }

    final recurrenceCountRaw = _optional(fields, ['LẶP LẠI_SỐ', 'LAP LAI SO']);
    final recurrenceCount = recurrenceCountRaw == null
        ? 10
        : int.tryParse(recurrenceCountRaw);
    if (recurrenceCount == null || recurrenceCount < 1 || recurrenceCount > 366) {
      if (recurrenceCountRaw != null || frequency != RecurrenceFrequency.none) {
        errors.add('Số lần lặp lại phải là số từ 1–366');
      }
    }

    if (errors.isNotEmpty) {
      return ImportRecord._(raw: block, index: index, errors: errors);
    }

    RecurrenceRule? rule;
    if (frequency != RecurrenceFrequency.none) {
      rule = RecurrenceRule(
        frequency: frequency!,
        endMode: RecurrenceEndMode.count,
        count: recurrenceCount!,
      );
    }

    // Stable across app launches: importing the same record again replaces the
    // same row instead of creating a duplicate.
    final id = 'import_${startDt.millisecondsSinceEpoch}_${_stableHash(title)}';
    final event = NextAEvent(
      id: id,
      title: title,
      type: EventType.classEvent,
      start: startDt,
      end: endDt,
      location: location,
      note: note,
      priority: priority ?? 0,
      recurrenceId: rule == null ? null : id,
      recurrenceRule: rule,
      reminderMinutes: reminderMinutes ?? 10,
      reminderRepeatCount: 2,
      reminderRepeatIntervalMinutes: 5,
    );

    return ImportRecord._(raw: block, index: index, event: event, errors: const []);
  }

  String? _optional(Map<String, String> fields, List<String> keys) {
    for (final key in keys) {
      final value = fields[key];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  RecurrenceFrequency? _parseFrequency(String value) {
    switch (value.toLowerCase().trim()) {
      case 'none':
      case 'không':
      case 'khong':
        return RecurrenceFrequency.none;
      case 'daily':
      case 'hàng ngày':
      case 'hang ngay':
        return RecurrenceFrequency.daily;
      case 'weekly':
      case 'hàng tuần':
      case 'hang tuan':
        return RecurrenceFrequency.weekly;
      case 'weekdays':
      case 'ngày trong tuần':
      case 'ngay trong tuan':
        return RecurrenceFrequency.weekdays;
      case 'monthly':
      case 'hàng tháng':
      case 'hang thang':
        return RecurrenceFrequency.monthly;
      default:
        return null;
    }
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (iso != null) {
      return _validDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    final dmy = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (dmy != null) {
      return _validDate(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }
    return null;
  }

  DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final candidate = DateTime(year, month, day);
    return candidate.year == year &&
            candidate.month == month &&
            candidate.day == day
        ? candidate
        : null;
  }

  (int, int)? _parseTime(String s) {
    if (s.isEmpty) return null;
    final upper = s.toUpperCase().replaceAll(' ', '');
    final hm = RegExp(r'^(\d{1,2}):(\d{2})(AM|PM)?$').firstMatch(upper);
    if (hm == null) return null;
    var hour = int.parse(hm.group(1)!);
    final minute = int.parse(hm.group(2)!);
    final suffix = hm.group(3);
    if (suffix == 'PM' && hour < 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    if (suffix != null && int.parse(hm.group(1)!) > 12) return null;
    return (hour, minute);
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
