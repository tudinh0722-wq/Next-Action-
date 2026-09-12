import 'dart:async';

import 'package:flutter/material.dart';

import '../application/alarm_scheduler.dart';
import '../application/countdown_policy.dart';
import '../application/tts_service.dart';
import '../data/event_database.dart';
import '../domain/event.dart';
import 'widgets/event_editor_sheet.dart';
import 'widgets/planner_agenda.dart';
import 'widgets/planner_calendar.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    required this.events,
    required this.database,
    required this.scheduler,
    required this.tts,
    this.themeMode = ThemeMode.system,
    this.seedColor = const Color(0xFF1A73E8),
    this.onThemeChanged,
    this.onSeedColorChanged,
  });

  final List<NextAEvent> events;
  final EventDatabase database;
  final AlarmScheduler scheduler;
  final TtsService tts;
  final ThemeMode themeMode;
  final Color seedColor;
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ValueChanged<Color>? onSeedColorChanged;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late DateTime _selected;
  late DateTime _month;
  late List<NextAEvent> _events;
  bool _expanded = true;
  final _countdownPolicy = const CountdownPolicy();
  Timer? _countdownTimer;
  static const _pageAnimationDuration = Duration(milliseconds: 420);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    _events = List.of(widget.events);
    _startCountdownTicker();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    final now = DateTime.now();
    final seconds = 60 - now.second;
    _countdownTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() {});
      _countdownTimer =
          Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  List<NextAEvent> _eventsFor(DateTime day) {
    final result = _events
        .where((e) =>
            e.start.year == day.year &&
            e.start.month == day.month &&
            e.start.day == day.day)
        .toList();
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  void _selectDay(DateTime day) => setState(() {
        _selected = DateTime(day.year, day.month, day.day);
        _month = DateTime(day.year, day.month);
      });

  void _shiftDay(int delta) =>
      _selectDay(_selected.add(Duration(days: delta)));

  void _shiftMonth(int delta) {
    final target = DateTime(_month.year, _month.month + delta);
    final maxDay = DateTime(target.year, target.month + 1, 0).day;
    setState(() {
      _month = target;
      _selected = DateTime(
          target.year, target.month, _selected.day.clamp(1, maxDay));
    });
  }

  void _shiftWeek(int delta) =>
      _selectDay(_selected.add(Duration(days: 7 * delta)));

  void _handleVerticalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 220) return;
    if (velocity < 0 && _expanded) {
      setState(() => _expanded = false);
    } else if (velocity > 0 && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  Future<String?> _pickDeleteScope(NextAEvent event) async {
    if (event.recurrenceId == null) return 'single';
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa sự kiện lặp'),
        content: RadioGroup<String>(
          groupValue: 'single',
          onChanged: (_) {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                  value: 'single',
                  title: const Text('Chỉ sự kiện này'),
                  groupValue: 'single',
                  onChanged: (_) => Navigator.pop(c, 'single')),
              RadioListTile<String>(
                  value: 'future',
                  title:
                      const Text('Sự kiện này và các sự kiện sau'),
                  groupValue: 'single',
                  onChanged: (_) => Navigator.pop(c, 'future')),
              RadioListTile<String>(
                  value: 'series',
                  title: const Text('Tất cả sự kiện trong chuỗi'),
                  groupValue: 'single',
                  onChanged: (_) => Navigator.pop(c, 'series')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Hủy'))
        ],
      ),
    );
  }

  Future<void> _editEvent(NextAEvent? event) async {
    final result = await showEventEditor(
        context,
        event: event,
        selectedDay: _selected);
    if (!mounted || result == null) return;

    if (result.deleted && event != null) {
      final scope = await _pickDeleteScope(event);
      if (!mounted || scope == null) return;

      if (scope == 'series' && event.recurrenceId != null) {
        await widget.database.deleteSeries(event.recurrenceId!);
        if (!mounted) return;
        final removed = _events
            .where((e) => e.recurrenceId == event.recurrenceId)
            .toList();
        for (final e in removed) {
          await widget.scheduler.cancelEvent(e.id);
        }
        setState(() => _events
            .removeWhere((e) => e.recurrenceId == event.recurrenceId));
      } else if (scope == 'future' && event.recurrenceId != null) {
        await widget.database
            .deleteSeriesFrom(event.recurrenceId!, event.start);
        if (!mounted) return;
        final removed = _events
            .where((e) =>
                e.recurrenceId == event.recurrenceId &&
                !e.start.isBefore(event.start))
            .toList();
        for (final e in removed) {
          await widget.scheduler.cancelEvent(e.id);
        }
        setState(() => _events.removeWhere((e) =>
            e.recurrenceId == event.recurrenceId &&
            !e.start.isBefore(event.start)));
      } else {
        await widget.database.delete(event.id);
        await widget.scheduler.cancelEvent(event.id);
        if (!mounted) return;
        setState(() => _events.removeWhere((e) => e.id == event.id));
      }
      return;
    }

    if (result.events.isEmpty) return;
    await widget.database.upsertAll(result.events);
    for (final e in result.events) {
      await widget.scheduler.scheduleEvent(e);
    }
    if (!mounted) return;
    setState(() {
      if (event != null) {
        _events.removeWhere((e) => e.id == event.id);
      }
      _events.addAll(result.events);
      _events.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  Future<void> _addEventForDay(DateTime day) async {
    final result = await showEventEditor(
        context,
        selectedDay: DateTime(day.year, day.month, day.day));
    if (!mounted || result == null || result.events.isEmpty) return;
    await widget.database.upsertAll(result.events);
    for (final e in result.events) {
      await widget.scheduler.scheduleEvent(e);
    }
    if (!mounted) return;
    setState(() {
      _events.addAll(result.events);
      _events.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  String _selectedHeader() {
    const weekdays = ['T.2', 'T.3', 'T.4', 'T.5', 'T.6', 'T.7', 'CN'];
    return '${_selected.day}   ${weekdays[_selected.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PlannerTopBar(
              monthLabel: 'TH${_month.month}',
              today: DateTime.now().day,
              onMenu: () => _showThemeMenu(context),
              onSearch: () => _showSearch(context),
              onToday: () => _selectDay(DateTime.now()),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: _handleVerticalSwipe,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() > 200) {
                          _expanded
                              ? _shiftMonth(velocity < 0 ? 1 : -1)
                              : _shiftWeek(velocity < 0 ? 1 : -1);
                        }
                      },
                      child: PlannerCalendar(
                        month: _month,
                        selected: _selected,
                        expanded: _expanded,
                        eventsFor: _eventsFor,
                        onSelect: _selectDay,
                        onLongPress: _addEventForDay,
                        animationDuration: _pageAnimationDuration,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() > 200) {
                            _shiftDay(velocity < 0 ? 1 : -1);
                          }
                        },
                        child: Stack(
                          children: [
                            PlannerAgenda(
                              header: _selectedHeader(),
                              events: _eventsFor(_selected),
                              policy: _countdownPolicy,
                              onEventTap: _editEvent,
                              onEmptyTap: () {},
                            ),
                            Positioned(
                              left: 72,
                              right: 72,
                              bottom: 30,
                              child: PlannerFab(
                                label:
                                    'Thêm vào ${_selected.day} Th${_selected.month}',
                                onTap: () => _editEvent(null),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSearch(BuildContext context) async {
    final event = await showDialog<NextAEvent>(
        context: context,
        builder: (_) => _SearchDialog(database: widget.database));
    if (!mounted || event == null) return;
    _selectDay(event.start);
  }

  Future<void> _showThemeMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Giao diện',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Hệ thống')),
                  ButtonSegment(
                      value: ThemeMode.light, label: Text('Sáng')),
                  ButtonSegment(
                      value: ThemeMode.dark, label: Text('Tối')),
                ],
                selected: {widget.themeMode},
                onSelectionChanged: (s) =>
                    widget.onThemeChanged?.call(s.first),
              ),
              const SizedBox(height: 18),
              const Text('Màu chủ đề',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: const [
                  Color(0xFF1A73E8),
                  Color(0xFF6750A4),
                  Color(0xFF006A6A),
                  Color(0xFF8E4A2F),
                  Color(0xFF7A4E00),
                ]
                    .map((c) => _SeedColorButton(
                        color: c,
                        onSelected: widget.onSeedColorChanged))
                    .toList(),
              ),
              const SizedBox(height: 10),
              const Text(
                  'Trên Android có màu động, NextA ưu tiên màu hệ thống theo Material 3.'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets (unchanged visual baseline) ────────────────────────────

class _SearchDialog extends StatefulWidget {
  const _SearchDialog({required this.database});
  final EventDatabase database;
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _controller = TextEditingController();
  List<NextAEvent> _results = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final results = await widget.database.search(_controller.text);
      if (mounted) setState(() => _results = results);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 560),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              children: [
                Row(children: [
                  const Expanded(
                      child: Text('Tìm kiếm',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700))),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded))
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (_) => _search(),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Tên, địa điểm hoặc ghi chú'),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text('Không tìm thấy sự kiện',
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant)))
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final e = _results[i];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 2, vertical: 2),
                              title: Text(e.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  '${e.start.day}/${e.start.month}/${e.start.year} · ${e.location ?? 'Không có địa điểm'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () =>
                                  Navigator.pop(context, e),
                            );
                          }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeedColorButton extends StatelessWidget {
  const _SeedColorButton(
      {required this.color, required this.onSelected});
  final Color color;
  final ValueChanged<Color>? onSelected;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: () {
        onSelected?.call(color);
        Navigator.pop(context);
      },
      child: CircleAvatar(radius: 17, backgroundColor: color));
}

class PlannerTopBar extends StatelessWidget {
  const PlannerTopBar({
    super.key,
    required this.monthLabel,
    required this.today,
    required this.onMenu,
    required this.onSearch,
    required this.onToday,
  });
  final String monthLabel;
  final int today;
  final VoidCallback onMenu, onSearch, onToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded)),
          const Spacer(),
          Text(monthLabel,
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: InkWell(
                onTap: onToday,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: scheme.outline, width: 1.5),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$today',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlannerFab extends StatelessWidget {
  const PlannerFab(
      {super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      shadowColor: scheme.shadow.withValues(alpha: .18),
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_rounded, size: 18),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
