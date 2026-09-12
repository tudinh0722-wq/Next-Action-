import 'package:flutter/material.dart';

import '../../application/priority_color.dart';
import '../../domain/event.dart';

class PlannerCalendar extends StatefulWidget {
  const PlannerCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.expanded,
    required this.eventsFor,
    required this.onSelect,
    required this.onLongPress,
    this.animationDuration = const Duration(milliseconds: 420),
  });

  final DateTime month;
  final DateTime selected;
  final bool expanded;
  final List<NextAEvent> Function(DateTime) eventsFor;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onLongPress;
  final Duration animationDuration;

  @override
  State<PlannerCalendar> createState() => _PlannerCalendarState();
}

class _PlannerCalendarState extends State<PlannerCalendar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _monthController;
  DateTime? _fromMonth;

  @override
  void initState() {
    super.initState();
    _monthController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
  }

  @override
  void didUpdateWidget(covariant PlannerCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _monthController.duration = widget.animationDuration;
    }
    if (widget.expanded && !_sameMonth(oldWidget.month, widget.month)) {
      _fromMonth = oldWidget.month;
      _monthController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _calendarFor(widget.month);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _monthController,
        builder: (context, child) {
          final from = _fromMonth;
          if (from == null || _monthController.isCompleted || !widget.expanded) {
            return calendar;
          }

          final progress = Curves.easeOutCubic.transform(_monthController.value);
          final direction = _movingForward ? -1.0 : 1.0;
          final width = MediaQuery.sizeOf(context).width;
          final outgoing = _calendarFor(from);

          return SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Transform.translate(
                  offset: Offset(direction * width * progress, 0),
                  child: Transform.scale(
                    scale: 1 - (0.02 * progress),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: 1 - (0.18 * progress),
                      child: outgoing,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-direction * width * (1 - progress), 0),
                  child: Transform.scale(
                    scale: 0.98 + (0.02 * progress),
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: 0.82 + (0.18 * progress),
                      child: calendar,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _movingForward =>
      _fromMonth == null || widget.month.isAfter(_fromMonth!);

  Widget _calendarFor(DateTime month) {
    final weekDays = _weekDays(widget.selected);
    final calendar = widget.expanded
        ? _MonthGrid(
            days: _monthDays(month),
            month: month,
            selected: widget.selected,
            eventsFor: widget.eventsFor,
            onSelect: widget.onSelect,
            onLongPress: widget.onLongPress,
          )
        : _WeekGrid(
            days: weekDays,
            selected: widget.selected,
            eventsFor: widget.eventsFor,
            onSelect: widget.onSelect,
            onLongPress: widget.onLongPress,
          );

    return AnimatedSize(
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: calendar,
    );
  }

  List<DateTime> _monthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return List.generate(35, (index) => start.add(Duration(days: index)));
  }

  List<DateTime> _weekDays(DateTime selected) {
    final start = selected.subtract(Duration(days: selected.weekday - 1));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.days,
    required this.month,
    required this.selected,
    required this.eventsFor,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<DateTime> days;
  final DateTime month;
  final DateTime selected;
  final List<NextAEvent> Function(DateTime) eventsFor;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WeekdayHeader(),
        SizedBox(
          height: 274,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 54,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              return CalendarDayCell(
                date: day,
                inMonth: day.year == month.year && day.month == month.month,
                selected: _sameDay(day, selected),
                events: eventsFor(day),
                onTap: () => onSelect(day),
                onLongPress: () => onLongPress(day),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.days,
    required this.selected,
    required this.eventsFor,
    required this.onSelect,
    required this.onLongPress,
  });

  final List<DateTime> days;
  final DateTime selected;
  final List<NextAEvent> Function(DateTime) eventsFor;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const WeekdayHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: SizedBox(
            height: 54,
            child: Row(
              children: days
                  .map(
                    (day) => Expanded(
                      child: CalendarDayCell(
                        date: day,
                        inMonth: true,
                        selected: _sameDay(day, selected),
                        events: eventsFor(day),
                        onTap: () => onSelect(day),
                        onLongPress: () => onLongPress(day),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  static const labels = ['T.2', 'T.3', 'T.4', 'T.5', 'T.6', 'T.7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        children: List.generate(
          labels.length,
          (index) => Expanded(
            child: SizedBox(
              height: 25,
              child: Center(
                child: Text(
                  labels[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: index == 6 ? scheme.error : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.events,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime date;
  final bool inMonth;
  final bool selected;
  final List<NextAEvent> events;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markers = _markerEvents(events);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 3),
        decoration: BoxDecoration(
          color: calendarTileColor(context, events, inMonth),
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: scheme.primary, width: 2)
              : null,
        ),
        child: Column(
          children: [
            SizedBox(
              height: 23,
              child: Align(
                alignment: Alignment.topCenter,
                child: Text('${date.day}', style: _dateStyle(scheme)),
              ),
            ),
            const Spacer(),
            _EventMarkers(events: markers),
          ],
        ),
      ),
    );
  }

  List<NextAEvent> _markerEvents(List<NextAEvent> source) {
    final sorted = List<NextAEvent>.of(source)
      ..sort((a, b) {
        final priority = b.priority.compareTo(a.priority);
        return priority != 0 ? priority : a.start.compareTo(b.start);
      });
    return sorted.take(2).toList();
  }

  TextStyle _dateStyle(ColorScheme scheme) => TextStyle(
        fontSize: selected ? 12 : 13,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        color: !inMonth
            ? scheme.onSurface.withValues(alpha: 0.42)
            : date.weekday == DateTime.sunday
                ? scheme.error
                : scheme.onSurface,
      );
}

class _EventMarkers extends StatelessWidget {
  const _EventMarkers({required this.events});

  final List<NextAEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox(height: 4);

    return SizedBox(
      width: 32,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final event in events)
            Container(
              width: double.infinity,
              height: 4,
              margin: const EdgeInsets.only(bottom: 1),
              decoration: BoxDecoration(
                color: nextAPriorityColor(event.priority),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

Color calendarTileColor(
  BuildContext context,
  List<NextAEvent> events,
  bool inMonth,
) {
  final scheme = Theme.of(context).colorScheme;
  if (events.isEmpty) {
    return scheme.surfaceContainerLow.withValues(
      alpha: inMonth ? 0.55 : 0.20,
    );
  }

  final important = events.where((event) => event.priority >= 1).toList()
    ..sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0 ? priority : a.start.compareTo(b.start);
    });

  final source = important.isNotEmpty ? important.first : events.first;
  final opacity = important.isNotEmpty ? 0.18 : 0.10;
  return Color.lerp(
        scheme.surface,
        nextAPriorityColor(source.priority),
        opacity,
      ) ??
      scheme.surface;
}
