import 'dart:async';

import 'package:flutter/material.dart';

import '../application/alarm_scheduler.dart';
import '../application/bulk_import_service.dart';
import '../application/countdown_policy.dart';
import '../application/recurrence_service.dart';
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
  late final RecurrenceService _recurrenceService;
  late final BulkImportService _bulkImportService;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
    _events = List.of(widget.events)
      ..sort((a, b) => a.start.compareTo(b.start));

    _recurrenceService = RecurrenceService(
      database: widget.database,
      scheduler: widget.scheduler,
    );

    _bulkImportService = BulkImportService(
      database: widget.database,
      scheduler: widget.scheduler,
    );

    _startTicker();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _countdownTimer?.cancel();

    final secondsUntilNextMinute = 60 - DateTime.now().second;

    _countdownTimer = Timer(
      Duration(seconds: secondsUntilNextMinute),
      () {
        if (!mounted) return;

        setState(() {});

        _countdownTimer = Timer.periodic(
          const Duration(minutes: 1),
          (_) {
            if (mounted) {
              setState(() {});
            }
          },
        );
      },
    );
  }

  List<NextAEvent> _eventsFor(DateTime day) {
    final result = _events
        .where(
          (event) =>
              event.start.year == day.year &&
              event.start.month == day.month &&
              event.start.day == day.day,
        )
        .toList();

    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selected = DateTime(date.year, date.month, date.day);
      _month = DateTime(date.year, date.month);
    });
  }

  void _shiftDay(int days) {
    _selectDay(_selected.add(Duration(days: days)));
  }

  void _shiftWeek(int weeks) {
    _shiftDay(weeks * 7);
  }

  void _shiftMonth(int months) {
    final target = DateTime(_month.year, _month.month + months);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    final day = _selected.day > lastDay ? lastDay : _selected.day;

    setState(() {
      _month = target;
      _selected = DateTime(target.year, target.month, day);
    });
  }

  void _handleVerticalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity.abs() < 220) return;

    if (velocity < 0 && _expanded) {
      setState(() => _expanded = false);
    }

    if (velocity > 0 && !_expanded) {
      setState(() => _expanded = true);
    }
  }

  Future<void> _reloadEvents() async {
    final events = await widget.database.getAll();

    if (!mounted) return;

    events.sort((a, b) => a.start.compareTo(b.start));
    setState(() => _events = events);
  }

  Future<void> _editEvent(NextAEvent? event) async {
    final result = await showEventEditor(
      context,
      event: event,
      selectedDay: _selected,
      importService: event == null ? _bulkImportService : null,
    );

    if (!mounted) return;

    if (result == null) {
      await _reloadEvents();
      return;
    }

    if (result.deleted && event != null) {
      final scope = result.scope ?? RecurrenceScope.single;
      final removed = await _recurrenceService.delete(
        event,
        scope,
        _events,
      );

      if (!mounted) return;

      setState(() {
        _events.removeWhere((item) => removed.contains(item.id));
      });
      return;
    }

    if (result.events.isEmpty) return;

    if (event != null) {
      final scope = result.scope ?? RecurrenceScope.single;
      final editResult = await _recurrenceService.edit(
        event,
        result.events.first,
        scope,
        _events,
      );

      if (!mounted) return;

      setState(() {
        _events.removeWhere(
          (item) => editResult.toRemove.contains(item.id),
        );
        _events.addAll(editResult.toAdd);
        _events.sort((a, b) => a.start.compareTo(b.start));
      });
      return;
    }

    await widget.database.upsertAll(result.events);

    for (final newEvent in result.events) {
      await widget.scheduler.scheduleEvent(newEvent);
    }

    if (!mounted) return;

    setState(() {
      _events.addAll(result.events);
      _events.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  Future<void> _addEventForDay(DateTime day) async {
    final result = await showEventEditor(
      context,
      selectedDay: DateTime(day.year, day.month, day.day),
      importService: _bulkImportService,
    );

    if (!mounted) return;

    if (result == null) {
      await _reloadEvents();
      return;
    }

    if (result.events.isEmpty) return;

    await widget.database.upsertAll(result.events);

    for (final newEvent in result.events) {
      await widget.scheduler.scheduleEvent(newEvent);
    }

    if (!mounted) return;

    setState(() {
      _events.addAll(result.events);
      _events.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  String _selectedHeader() {
    const weekdays = [
      'T.2',
      'T.3',
      'T.4',
      'T.5',
      'T.6',
      'T.7',
      'CN',
    ];

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

                        if (velocity.abs() <= 200) return;

                        if (_expanded) {
                          _shiftMonth(velocity < 0 ? 1 : -1);
                        } else {
                          _shiftWeek(velocity < 0 ? 1 : -1);
                        }
                      },
                      child: PlannerCalendar(
                        month: _month,
                        selected: _selected,
                        expanded: _expanded,
                        eventsFor: _eventsFor,
                        onSelect: _selectDay,
                        onLongPress: _addEventForDay,
                        animationDuration: const Duration(
                          milliseconds: 420,
                        ),
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
                              onEmptyTap: () => _editEvent(null),
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
      builder: (_) => _SearchDialog(database: widget.database),
    );

    if (!mounted || event == null) return;
    _selectDay(event.start);
  }

  Future<void> _showThemeMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Giao diện',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Hệ thống'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Sáng'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Tối'),
                    ),
                  ],
                  selected: {widget.themeMode},
                  onSelectionChanged: (selection) {
                    widget.onThemeChanged?.call(selection.first);
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Màu chủ đề',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    for (final color in const [
                      Color(0xFF1A73E8),
                      Color(0xFF6750A4),
                      Color(0xFF006A6A),
                      Color(0xFF8E4A2F),
                      Color(0xFF7A4E00),
                    ])
                      _SeedColorButton(
                        color: color,
                        onSelected: widget.onSeedColorChanged,
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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

    _debounce = Timer(
      const Duration(milliseconds: 180),
      () async {
        final results = await widget.database.search(_controller.text);

        if (mounted) {
          setState(() => _results = results);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 430,
          maxHeight: 560,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tìm kiếm',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (_) => _search(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Tên, địa điểm hoặc ghi chú',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            'Không tìm thấy sự kiện',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final event = _results[index];

                            return ListTile(
                              title: Text(
                                event.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${event.start.day}/${event.start.month}/${event.start.year} · '
                                '${event.location ?? 'Không có địa điểm'}',
                              ),
                              onTap: () => Navigator.pop(context, event),
                            );
                          },
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

class _SeedColorButton extends StatelessWidget {
  const _SeedColorButton({
    required this.color,
    required this.onSelected,
  });

  final Color color;
  final ValueChanged<Color>? onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onSelected?.call(color);
        Navigator.pop(context);
      },
      child: CircleAvatar(
        radius: 17,
        backgroundColor: color,
      ),
    );
  }
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
  final VoidCallback onMenu;
  final VoidCallback onSearch;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded),
          ),
          const Spacer(),
          Text(
            monthLabel,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: onToday,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: scheme.outline,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$today',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
  const PlannerFab({
    super.key,
    required this.label,
    required this.onTap,
  });

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
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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
