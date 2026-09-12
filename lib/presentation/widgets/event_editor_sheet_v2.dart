import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../application/priority_color.dart';
import '../../application/recurrence_policy.dart';
import '../../domain/event.dart';

class EventEditorResult {
  const EventEditorResult({required this.events, required this.deleted});
  final List<NextAEvent> events;
  final bool deleted;
  NextAEvent? get event => events.isEmpty ? null : events.first;
}

Future<EventEditorResult?> showEventEditor(
  BuildContext context, {
  NextAEvent? event,
  required DateTime selectedDay,
}) async {
  if (event != null) {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Chỉnh sửa sự kiện'),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xóa sự kiện'),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return null;
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Xóa sự kiện?'),
          content: Text('Xóa “${event.title}” khỏi lịch?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
          ],
        ),
      );
      return ok == true ? const EventEditorResult(events: [], deleted: true) : null;
    }
    if (action != 'edit') return null;
  }

  return showModalBottomSheet<EventEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventEditorSheet(event: event, selectedDay: selectedDay),
  );
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({required this.event, required this.selectedDay});
  final NextAEvent? event;
  final DateTime selectedDay;

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
    final e = widget.event;
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _start = e?.start ?? DateTime(widget.selectedDay.year, widget.selectedDay.month, widget.selectedDay.day, 8);
    _end = e?.end ?? _start.add(const Duration(hours: 1));
    _priority = e?.priority ?? 0;
    _recurrenceRule = e?.recurrenceRule ?? const RecurrenceRule(frequency: RecurrenceFrequency.none);
    _reminderMinutes = e?.reminderMinutes ?? 10;
    _reminderRepeatCount = e?.reminderRepeatCount ?? 2;
    _reminderRepeatIntervalMinutes = e?.reminderRepeatIntervalMinutes ?? 5;
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
    final date = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null) return;
    setState(() {
      final value = DateTime(date.year, date.month, date.day, current.hour, current.minute);
      if (start) {
        _start = value;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
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
      builder: (c) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: Row(
                  children: [
                    const Expanded(child: Text('Chọn thời gian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('Xong')),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: current,
                  onDateTimeChanged: (v) => picked = DateTime(current.year, current.month, current.day, v.hour, v.minute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _pickReminder() async {
    final result = await showDialog<_ReminderSettings>(
      context: context,
      builder: (_) => _ReminderDialog(minutes: _reminderMinutes, repeatCount: _reminderRepeatCount, interval: _reminderRepeatIntervalMinutes),
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
      builder: (_) => _RecurrenceDialog(initial: _recurrenceRule, start: _start),
    );
    if (result != null) setState(() => _recurrenceRule = result);
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));

    final old = widget.event;
    final id = old?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final recurring = _recurrenceRule.frequency != RecurrenceFrequency.none;
    final event = NextAEvent(
      id: id,
      title: title,
      type: old?.type ?? EventType.classEvent,
      start: _start,
      end: _end,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      priority: _priority.clamp(0, 2).toInt(),
      recurrenceId: recurring ? (old?.recurrenceId ?? id) : null,
      recurrenceRule: recurring ? _recurrenceRule : null,
      reminderMinutes: _reminderMinutes,
      reminderRepeatCount: _reminderRepeatCount,
      reminderRepeatIntervalMinutes: _reminderRepeatIntervalMinutes,
    );
    final events = old == null && recurring ? generateOccurrences(event, rule: _recurrenceRule) : [event];
    Navigator.pop(context, EventEditorResult(events: events, deleted: false));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: _EditorTabs(selectedBulk: _bulkImportTab, onChanged: (v) => setState(() => _bulkImportTab = v)),
            ),
            Expanded(
              child: _bulkImportTab
                  ? const _BulkImportSlot()
                  : _EventContent(
                      title: _title,
                      location: _location,
                      note: _note,
                      start: _start,
                      end: _end,
                      priority: _priority,
                      reminderMinutes: _reminderMinutes,
                      reminderRepeatCount: _reminderRepeatCount,
                      reminderRepeatIntervalMinutes: _reminderRepeatIntervalMinutes,
                      recurrence: _recurrenceRule,
                      onPriority: (p) => setState(() => _priority = p),
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

  String _weekdayLabel(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday: return 'T.2';
      case DateTime.tuesday: return 'T.3';
      case DateTime.wednesday: return 'T.4';
      case DateTime.thursday: return 'T.5';
      case DateTime.friday: return 'T.6';
      case DateTime.saturday: return 'T.7';
      case DateTime.sunday: return 'CN';
    }
    return '';
  }

  String _date(DateTime d) => '${_weekdayLabel(d)}, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$hour:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _recurrenceLabel() => switch (recurrence.frequency) {
    RecurrenceFrequency.none => 'Không lặp lại',
    RecurrenceFrequency.daily => 'Hàng ngày',
    RecurrenceFrequency.weekly => 'Hàng tuần',
    RecurrenceFrequency.weekdays => 'Hàng tuần',
    RecurrenceFrequency.monthly => 'Hàng tháng',
  };

  @override
  Widget build(BuildContext context) {
    final reminderLabel = reminderMinutes > 0 ? '$reminderMinutes phút' : 'Tắt';
    final repeatLabel = reminderMinutes > 0 && reminderRepeatCount > 0 ? '$reminderRepeatCount lần • mỗi $reminderRepeatIntervalMinutes phút' : 'Không báo lại';
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
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
                    _PrioritySelector(priority: priority, onSelected: onPriority),
                  ],
                ),
                const SizedBox(height: 10),
                _DateTimeColumns(start: start, end: end, date: _date, time: _time, onStartDate: onStartDate, onStartTime: onStartTime, onEndDate: onEndDate, onEndTime: onEndTime),
                const SizedBox(height: 18),
                _EditorTextField(icon: Icons.location_on_outlined, controller: location, hintText: 'Địa chỉ', maxLength: 30, textInputAction: TextInputAction.next),
                const SizedBox(height: 2),
                _EditorTextField(icon: Icons.notes_outlined, controller: note, hintText: 'Ghi chú', maxLength: 30, minLines: 1, maxLines: 3, textInputAction: TextInputAction.newline),
                const SizedBox(height: 14),
                _EditorOptionTile(icon: Icons.notifications_none_rounded, title: 'Báo trước', subtitle: reminderLabel, onTap: onReminder),
                _EditorOptionTile(icon: Icons.repeat_rounded, title: 'Báo lại', subtitle: repeatLabel, onTap: onReminder),
                _EditorOptionTile(icon: Icons.sync_rounded, title: 'Lặp lại', subtitle: _recurrenceLabel(), muted: recurrence.frequency == RecurrenceFrequency.none, onTap: onRecurrence),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 6, 56, 30),
          child: _BottomActionFab(onCancel: onCancel, onSave: onSave),
        ),
      ],
    );
  }
}

class _PrioritySelector extends StatefulWidget {
  const _PrioritySelector({required this.priority, required this.onSelected});
  final int priority;
  final ValueChanged<int> onSelected;

  @override
  State<_PrioritySelector> createState() => _PrioritySelectorState();
}

class _PrioritySelectorState extends State<_PrioritySelector> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      child: _expanded
          ? Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            widget.onSelected(i);
                            setState(() => _expanded = false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _PriorityDot(priority: i, selected: widget.priority == i),
                          ),
                        ),
                      ),
                    IconButton(onPressed: () => setState(() => _expanded = false), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
            )
          : InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _PriorityDot(priority: widget.priority, selected: true),
              ),
            ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority, required this.selected});
  final int priority;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: nextAPriorityColor(priority),
        border: selected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 1.5) : null,
      ),
    );
  }
}

class _DateTimeColumns extends StatelessWidget {
  const _DateTimeColumns({required this.start, required this.end, required this.date, required this.time, required this.onStartDate, required this.onStartTime, required this.onEndDate, required this.onEndTime});
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Column(children: [_DateTimeButton(label: date(start), onTap: onStartDate), _DateTimeButton(label: time(start), onTap: onStartTime, large: false)])),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward_rounded, size: 30)),
        Expanded(child: Column(children: [_DateTimeButton(label: date(end), onTap: onEndDate), _DateTimeButton(label: time(end), onTap: onEndTime, large: false)])),
      ],
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({required this.label, required this.onTap, this.large = true});
  final String label;
  final VoidCallback onTap;
  final bool large;

  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6), child: Text(label, style: TextStyle(fontSize: large ? 18 : 17))));
}

class _EditorTextField extends StatelessWidget {
  const _EditorTextField({required this.icon, required this.controller, required this.hintText, this.maxLength, this.minLines, this.maxLines = 1, this.textInputAction});
  final IconData icon;
  final TextEditingController controller;
  final String hintText;
  final int? maxLength;
  final int? minLines;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          prefixIcon: SizedBox(
            width: 40,
            height: 48,
            child: Center(child: Icon(icon)),
          ),
          prefixIconConstraints: const BoxConstraints.tightFor(width: 40, height: 48),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: hintText,
        ),
      );
}

class _EditorOptionTile extends StatelessWidget {
  const _EditorOptionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.muted = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final color = muted ? s.onSurfaceVariant : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
      minLeadingWidth: 40,
      horizontalTitleGap: 16,
      leading: SizedBox(
        width: 40,
        height: 48,
        child: Center(child: Icon(icon, color: color)),
      ),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(subtitle, style: TextStyle(color: muted ? s.onSurfaceVariant : null)),
      trailing: Icon(Icons.chevron_right_rounded, color: color),
      onTap: onTap,
    );
  }
}

class _BottomActionFab extends StatelessWidget {
  const _BottomActionFab({required this.onCancel, required this.onSave});
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surfaceContainerHigh,
      elevation: 7,
      shadowColor: s.shadow.withValues(alpha: 0.20),
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            Expanded(child: InkWell(onTap: onCancel, child: const Center(child: Text('Thoát', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))))),
            Expanded(child: InkWell(onTap: onSave, child: const Center(child: Text('Lưu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))))),
          ],
        ),
      ),
    );
  }
}

class _EditorTabs extends StatelessWidget {
  const _EditorTabs({required this.selectedBulk, required this.onChanged});
  final bool selectedBulk;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(34),
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Expanded(child: _EditorTab(selected: !selectedBulk, label: 'Thêm sự kiện', icon: Icons.event_available_outlined, onTap: () => onChanged(false))),
            Expanded(child: _EditorTab(selected: selectedBulk, label: 'AI Import', icon: Icons.auto_awesome_outlined, onTap: () => onChanged(true))),
          ],
        ),
      ),
    );
  }
}

class _EditorTab extends StatelessWidget {
  const _EditorTab({required this.selected, required this.label, required this.icon, required this.onTap});
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: selected ? s.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: selected ? s.onSurface : s.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 17, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? s.onSurface : s.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
