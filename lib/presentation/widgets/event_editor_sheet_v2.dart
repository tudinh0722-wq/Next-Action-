import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../application/bulk_import_service.dart';
import '../../application/priority_color.dart';
import '../../application/recurrence_policy.dart';
import '../../application/recurrence_service.dart';
import '../../domain/event.dart';
import 'ai_import_sheet.dart';

class EventEditorResult {
  const EventEditorResult({
    required this.events,
    required this.deleted,
    this.scope,
  });

  final List<NextAEvent> events;
  final bool deleted;
  final RecurrenceScope? scope;

  NextAEvent? get event => events.isEmpty ? null : events.first;
}

Future<EventEditorResult?> showEventEditor(
  BuildContext context, {
  NextAEvent? event,
  required DateTime selectedDay,
  BulkImportService? importService,
}) async {
  if (event != null) {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Chỉnh sửa sự kiện'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xóa sự kiện'),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!context.mounted) return null;

    if (action == 'delete') {
      final scope = event.recurrenceId == null
          ? RecurrenceScope.single
          : await _pickRecurrenceScope(
              context,
              title: 'Xóa sự kiện lặp',
              destructive: true,
            );

      if (!context.mounted || scope == null) return null;

      return EventEditorResult(
        events: const [],
        deleted: true,
        scope: scope,
      );
    }

    if (action != 'edit') return null;

    final scope = event.recurrenceId == null
        ? RecurrenceScope.single
        : await _pickRecurrenceScope(
            context,
            title: 'Chỉnh sửa sự kiện lặp',
            destructive: false,
          );

    if (!context.mounted || scope == null) return null;

    return showModalBottomSheet<EventEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventEditorSheet(
        event: event,
        selectedDay: selectedDay,
        importService: importService,
        scope: scope,
      ),
    );
  }

  return showModalBottomSheet<EventEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventEditorSheet(
      event: null,
      selectedDay: selectedDay,
      importService: importService,
    ),
  );
}

Future<RecurrenceScope?> _pickRecurrenceScope(
  BuildContext context, {
  required String title,
  required bool destructive,
}) {
  return showDialog<RecurrenceScope>(
    context: context,
    builder: (_) => _RecurrenceScopeDialog(
      title: title,
      destructive: destructive,
    ),
  );
}

class _RecurrenceScopeDialog extends StatefulWidget {
  const _RecurrenceScopeDialog({
    required this.title,
    required this.destructive,
  });

  final String title;
  final bool destructive;

  @override
  State<_RecurrenceScopeDialog> createState() =>
      _RecurrenceScopeDialogState();
}

class _RecurrenceScopeDialogState extends State<_RecurrenceScopeDialog> {
  RecurrenceScope _scope = RecurrenceScope.single;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<RecurrenceScope>(
            dense: true,
            value: RecurrenceScope.single,
            groupValue: _scope,
            onChanged: (value) => setState(() => _scope = value!),
            title: const Text('Chỉ sự kiện này'),
          ),
          RadioListTile<RecurrenceScope>(
            dense: true,
            value: RecurrenceScope.future,
            groupValue: _scope,
            onChanged: (value) => setState(() => _scope = value!),
            title: const Text('Sự kiện này và các sự kiện sau'),
          ),
          RadioListTile<RecurrenceScope>(
            dense: true,
            value: RecurrenceScope.series,
            groupValue: _scope,
            onChanged: (value) => setState(() => _scope = value!),
            title: const Text('Tất cả sự kiện trong chuỗi'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, _scope),
          child: Text(widget.destructive ? 'Xóa' : 'Tiếp tục'),
        ),
      ],
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.event,
    required this.selectedDay,
    this.importService,
    this.scope,
  });

  final NextAEvent? event;
  final DateTime selectedDay;
  final BulkImportService? importService;
  final RecurrenceScope? scope;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _note;
  late DateTime _start;
  late DateTime _end;
  late int _priority;
  late RecurrenceRule _recurrenceRule;

  int _reminderMinutes = 10;
  int _reminderRepeatCount = 2;
  int _reminderRepeatIntervalMinutes = 5;
  bool _bulkImportTab = false;

  @override
  void initState() {
    super.initState();

    final event = widget.event;

    _title = TextEditingController(text: event?.title ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _note = TextEditingController(text: event?.note ?? '');

    _start = event?.start ?? DateTime(
      widget.selectedDay.year,
      widget.selectedDay.month,
      widget.selectedDay.day,
      8,
    );
    _end = event?.end ?? _start.add(const Duration(hours: 1));
    _priority = event?.priority ?? 0;
    _recurrenceRule = event?.recurrenceRule ??
        const RecurrenceRule(frequency: RecurrenceFrequency.none);
    _reminderMinutes = event?.reminderMinutes ?? 10;
    _reminderRepeatCount = event?.reminderRepeatCount ?? 2;
    _reminderRepeatIntervalMinutes =
        event?.reminderRepeatIntervalMinutes ?? 5;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final current = start ? _start : _end;

    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        current.hour,
        current.minute,
      );

      if (start) {
        _start = value;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = value;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    var picked = current;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chọn thời gian',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Xong'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: false,
                    initialDateTime: current,
                    onDateTimeChanged: (value) {
                      picked = DateTime(
                        current.year,
                        current.month,
                        current.day,
                        value.hour,
                        value.minute,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    setState(() {
      if (start) {
        _start = picked;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickReminder() async {
    final result = await showDialog<_ReminderSettings>(
      context: context,
      builder: (_) => _ReminderDialog(
        minutes: _reminderMinutes,
        repeatCount: _reminderRepeatCount,
        interval: _reminderRepeatIntervalMinutes,
      ),
    );

    if (result == null) return;

    setState(() {
      _reminderMinutes = result.enabled ? result.minutes : 0;
      _reminderRepeatCount = result.enabled ? result.repeatCount : 0;
      _reminderRepeatIntervalMinutes = result.enabled ? result.interval : 5;
    });
  }

  Future<void> _pickRecurrence() async {
    final result = await showDialog<RecurrenceRule>(
      context: context,
      builder: (_) => _RecurrenceDialog(initial: _recurrenceRule),
    );

    if (result != null) {
      setState(() => _recurrenceRule = result);
    }
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();

    final title = _title.text.trim();
    if (title.isEmpty) return;

    if (!_end.isAfter(_start)) {
      _end = _start.add(const Duration(hours: 1));
    }

    final old = widget.event;
    final id = old?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final recurring =
        _recurrenceRule.frequency != RecurrenceFrequency.none;

    final event = NextAEvent(
      id: id,
      title: title,
      type: old?.type ?? EventType.classEvent,
      start: _start,
      end: _end,
      location: _location.text.trim().isEmpty
          ? null
          : _location.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      priority: _priority.clamp(0, 2).toInt(),
      recurrenceId: recurring ? (old?.recurrenceId ?? id) : null,
      recurrenceRule: recurring ? _recurrenceRule : null,
      reminderMinutes: _reminderMinutes,
      reminderRepeatCount: _reminderRepeatCount,
      reminderRepeatIntervalMinutes: _reminderRepeatIntervalMinutes,
    );

    final events = old == null && recurring
        ? generateOccurrences(event, rule: _recurrenceRule)
        : [event];

    Navigator.pop(
      context,
      EventEditorResult(
        events: events,
        deleted: false,
        scope: widget.scope,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showImportTab = widget.importService != null && widget.event == null;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: showImportTab
                  ? _EditorTabs(
                      selectedBulk: _bulkImportTab,
                      onChanged: (value) =>
                          setState(() => _bulkImportTab = value),
                    )
                  : _SingleTabHeader(
                      onClose: () => Navigator.pop(context),
                    ),
            ),
            Expanded(
              child: _bulkImportTab && showImportTab
                  ? AiImportSheet(
                      service: widget.importService!,
                      onImported: (_) {},
                    )
                  : _EventContent(
                      title: _title,
                      location: _location,
                      note: _note,
                      start: _start,
                      end: _end,
                      priority: _priority,
                      reminderMinutes: _reminderMinutes,
                      reminderRepeatCount: _reminderRepeatCount,
                      reminderRepeatIntervalMinutes:
                          _reminderRepeatIntervalMinutes,
                      recurrence: _recurrenceRule,
                      onPriority: (value) =>
                          setState(() => _priority = value),
                      onStartDate: () => _pickDate(true),
                      onStartTime: () => _pickTime(true),
                      onEndDate: () => _pickDate(false),
                      onEndTime: () => _pickTime(false),
                      onReminder: _pickReminder,
                      onRecurrence: _pickRecurrence,
                      onCancel: () => Navigator.pop(context),
                      onSave: _save,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleTabHeader extends StatelessWidget {
  const _SingleTabHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Chỉnh sửa sự kiện',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _EventContent extends StatelessWidget {
  const _EventContent({
    required this.title,
    required this.location,
    required this.note,
    required this.start,
    required this.end,
    required this.priority,
    required this.reminderMinutes,
    required this.reminderRepeatCount,
    required this.reminderRepeatIntervalMinutes,
    required this.recurrence,
    required this.onPriority,
    required this.onStartDate,
    required this.onStartTime,
    required this.onEndDate,
    required this.onEndTime,
    required this.onReminder,
    required this.onRecurrence,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController title;
  final TextEditingController location;
  final TextEditingController note;
  final DateTime start;
  final DateTime end;
  final int priority;
  final int reminderMinutes;
  final int reminderRepeatCount;
  final int reminderRepeatIntervalMinutes;
  final RecurrenceRule recurrence;
  final ValueChanged<int> onPriority;
  final VoidCallback onStartDate;
  final VoidCallback onStartTime;
  final VoidCallback onEndDate;
  final VoidCallback onEndTime;
  final VoidCallback onReminder;
  final VoidCallback onRecurrence;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  String _weekdayLabel(DateTime date) {
    const labels = ['T.2', 'T.3', 'T.4', 'T.5', 'T.6', 'T.7', 'CN'];
    return labels[date.weekday - 1];
  }

  String _date(DateTime date) {
    return '${_weekdayLabel(date)}, '
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String _time(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _recurrenceLabel() {
    return switch (recurrence.frequency) {
      RecurrenceFrequency.none => 'Không lặp lại',
      RecurrenceFrequency.daily => 'Hàng ngày',
      RecurrenceFrequency.weekly => 'Hàng tuần',
      RecurrenceFrequency.weekdays => 'Ngày trong tuần',
      RecurrenceFrequency.monthly => 'Hàng tháng',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reminderLabel = reminderMinutes > 0
        ? '$reminderMinutes phút'
        : 'Tắt';
    final repeatLabel = reminderMinutes > 0 && reminderRepeatCount > 0
        ? '$reminderRepeatCount lần • mỗi '
            '$reminderRepeatIntervalMinutes phút'
        : 'Không báo lại';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              4,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: title,
                        autofocus: true,
                        maxLength: 47,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Tên sự kiện',
                          border: InputBorder.none,
                          counterText: '',
                          hintStyle: TextStyle(fontSize: 25),
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PrioritySelector(
                      priority: priority,
                      onSelected: onPriority,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _DateTimeBlock(
                  start: start,
                  end: end,
                  date: _date,
                  time: _time,
                  onStartDate: onStartDate,
                  onStartTime: onStartTime,
                  onEndDate: onEndDate,
                  onEndTime: onEndTime,
                ),
                const SizedBox(height: 18),
                _EditorTextField(
                  icon: Icons.location_on_outlined,
                  controller: location,
                  hintText: 'Địa chỉ',
                  maxLength: 30,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 2),
                _EditorTextField(
                  icon: Icons.notes_outlined,
                  controller: note,
                  hintText: 'Ghi chú',
                  maxLength: 30,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 14),
                _EditorOptionTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Báo trước',
                  subtitle: reminderLabel,
                  onTap: onReminder,
                ),
                _EditorOptionTile(
                  icon: Icons.repeat_rounded,
                  title: 'Lặp lại',
                  subtitle: _recurrenceLabel(),
                  onTap: onRecurrence,
                ),
                _EditorOptionTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Báo lại',
                  subtitle: repeatLabel,
                  onTap: onReminder,
                ),
              ],
            ),
          ),
        ),
        _EditorActionBar(
          onCancel: onCancel,
          onSave: onSave,
          scheme: scheme,
        ),
      ],
    );
  }
}

class _DateTimeBlock extends StatelessWidget {
  const _DateTimeBlock({
    required this.start,
    required this.end,
    required this.date,
    required this.time,
    required this.onStartDate,
    required this.onStartTime,
    required this.onEndDate,
    required this.onEndTime,
  });

  final DateTime start;
  final DateTime end;
  final String Function(DateTime) date;
  final String Function(DateTime) time;
  final VoidCallback onStartDate;
  final VoidCallback onStartTime;
  final VoidCallback onEndDate;
  final VoidCallback onEndTime;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _DateTimeSide(
            label: 'BẮT ĐẦU',
            dateText: date(start),
            timeText: time(start),
            onDate: onStartDate,
            onTime: onStartTime,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.arrow_forward_rounded, size: 20),
          ),
          _DateTimeSide(
            label: 'KẾT THÚC',
            dateText: date(end),
            timeText: time(end),
            onDate: onEndDate,
            onTime: onEndTime,
          ),
        ],
      ),
    );
  }
}

class _DateTimeSide extends StatelessWidget {
  const _DateTimeSide({
    required this.label,
    required this.dateText,
    required this.timeText,
    required this.onDate,
    required this.onTime,
  });

  final String label;
  final String dateText;
  final String timeText;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        TextButton(
          onPressed: onDate,
          child: Text(dateText),
        ),
        TextButton(
          onPressed: onTime,
          child: Text(timeText),
        ),
      ],
    );
  }
}

class _EditorActionBar extends StatelessWidget {
  const _EditorActionBar({
    required this.onCancel,
    required this.onSave,
    required this.scheme,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: Material(
        elevation: 3,
        shadowColor: scheme.shadow.withValues(alpha: .18),
        color: scheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onCancel,
                  customBorder: const StadiumBorder(),
                  child: const Center(
                    child: Text(
                      'Thoát',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: onSave,
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Lưu',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  const _EditorTextField({
    required this.icon,
    required this.controller,
    required this.hintText,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.textInputAction,
  });

  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Center(
            child: Icon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            maxLength: maxLength,
            minLines: minLines,
            maxLines: maxLines,
            textInputAction: textInputAction,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorOptionTile extends StatelessWidget {
  const _EditorOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 40,
        child: Center(child: Icon(icon, size: 22)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({
    required this.selectedBulk,
    required this.onChanged,
  });

  final bool selectedBulk;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(34),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Expanded(
              child: _EditorTab(
                selected: !selectedBulk,
                label: 'Thêm sự kiện',
                icon: Icons.event_available_outlined,
                onTap: () => onChanged(false),
              ),
            ),
            Expanded(
              child: _EditorTab(
                selected: selectedBulk,
                label: 'AI Import',
                icon: Icons.auto_awesome_outlined,
                onTap: () => onChanged(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorTab extends StatelessWidget {
  const _EditorTab({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  const _PrioritySelector({
    required this.priority,
    required this.onSelected,
  });

  final int priority;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: priority,
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('HIGH 1')),
        PopupMenuItem(value: 1, child: Text('HIGH 2')),
        PopupMenuItem(value: 2, child: Text('HIGH 3')),
      ],
      child: Icon(
        Icons.flag_outlined,
        color: nextAPriorityColor(priority),
      ),
    );
  }
}

class _ReminderSettings {
  const _ReminderSettings({
    required this.enabled,
    required this.minutes,
    required this.repeatCount,
    required this.interval,
  });

  final bool enabled;
  final int minutes;
  final int repeatCount;
  final int interval;
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({
    required this.minutes,
    required this.repeatCount,
    required this.interval,
  });

  final int minutes;
  final int repeatCount;
  final int interval;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late bool enabled;
  late int minutes;
  late int repeatCount;
  late int interval;

  @override
  void initState() {
    super.initState();
    enabled = widget.minutes > 0;
    minutes = widget.minutes > 0 ? widget.minutes : 10;
    repeatCount = widget.repeatCount > 0 ? widget.repeatCount : 2;
    interval = widget.interval > 0 ? widget.interval : 5;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Báo trước'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bật nhắc nhở'),
            value: enabled,
            onChanged: (value) => setState(() => enabled = value),
          ),
          if (enabled) ...[
            DropdownButtonFormField<int>(
              initialValue: minutes,
              decoration: const InputDecoration(labelText: 'Báo trước'),
              items: const [5, 10, 15, 30, 60]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value phút'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => minutes = value ?? minutes),
            ),
            DropdownButtonFormField<int>(
              initialValue: repeatCount,
              decoration: const InputDecoration(labelText: 'Số lần báo lại'),
              items: const [1, 2, 3, 5]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value lần'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => repeatCount = value ?? repeatCount),
            ),
            DropdownButtonFormField<int>(
              initialValue: interval,
              decoration: const InputDecoration(labelText: 'Khoảng cách'),
              items: const [1, 5, 10, 15]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value phút'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => interval = value ?? interval),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ReminderSettings(
              enabled: enabled,
              minutes: minutes,
              repeatCount: repeatCount,
              interval: interval,
            ),
          ),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}

class _RecurrenceDialog extends StatefulWidget {
  const _RecurrenceDialog({required this.initial});

  final RecurrenceRule initial;

  @override
  State<_RecurrenceDialog> createState() => _RecurrenceDialogState();
}

class _RecurrenceDialogState extends State<_RecurrenceDialog> {
  late RecurrenceRule rule;

  @override
  void initState() {
    super.initState();
    rule = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Lặp lại'),
      content: DropdownButtonFormField<RecurrenceFrequency>(
        initialValue: rule.frequency,
        items: const [
          DropdownMenuItem(
            value: RecurrenceFrequency.none,
            child: Text('Không lặp lại'),
          ),
          DropdownMenuItem(
            value: RecurrenceFrequency.daily,
            child: Text('Hàng ngày'),
          ),
          DropdownMenuItem(
            value: RecurrenceFrequency.weekly,
            child: Text('Hàng tuần'),
          ),
          DropdownMenuItem(
            value: RecurrenceFrequency.weekdays,
            child: Text('Ngày trong tuần'),
          ),
          DropdownMenuItem(
            value: RecurrenceFrequency.monthly,
            child: Text('Hàng tháng'),
          ),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            rule = RecurrenceRule(
              frequency: value,
              count: rule.count,
              until: rule.until,
            );
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, rule),
          child: const Text('Xong'),
        ),
      ],
    );
  }
}
