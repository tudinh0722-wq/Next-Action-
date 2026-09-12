import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'application/countdown_policy.dart';
import 'domain/event.dart';

void main() => runApp(const NextAApp());

class NextAApp extends StatelessWidget {
  const NextAApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NextA',
        theme: ThemeData(
            colorSchemeSeed: const Color(0xff3f51b5), useMaterial3: true),
        home: const PlannerScreen(),
      );
}

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _countdown = const CountdownPolicy();
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  void _select(DateTime value) => setState(() {
        _selectedDate = _dateOnly(value);
        _visibleMonth = DateTime(value.year, value.month);
      });

  void _moveMonth(int delta) => setState(() {
        _visibleMonth =
            DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      });

  @override
  Widget build(BuildContext context) {
    final agenda = _demoEvents
        .where((event) => _sameDay(event.start, _selectedDate))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(DateFormat('MMMM y').format(_visibleMonth)),
        leading: IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(
              onPressed: () => _select(DateTime.now()),
              icon: const Icon(Icons.today_outlined)),
        ],
      ),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              onPressed: () => _moveMonth(-1),
              icon: const Icon(Icons.chevron_left)),
          const Text('S   M   T   W   T   F   S'),
          IconButton(
              onPressed: () => _moveMonth(1),
              icon: const Icon(Icons.chevron_right)),
        ]),
        _MonthGrid(
          visibleMonth: _visibleMonth,
          selectedDate: _selectedDate,
          events: _demoEvents,
          onSelected: _select,
        ),
        const Divider(height: 1),
        Expanded(
            child: _Agenda(
                date: _selectedDate, events: agenda, countdown: _countdown)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Event creation is the next Flutter milestone.')),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid(
      {required this.visibleMonth,
      required this.selectedDate,
      required this.events,
      required this.onSelected});
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final List<NextAEvent> events;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final first = DateTime(visibleMonth.year, visibleMonth.month);
    final firstCell = first.subtract(Duration(days: first.weekday % 7));
    final today = DateTime.now();
    return SizedBox(
      height: 300,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 42,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
        itemBuilder: (context, index) {
          final date = firstCell.add(Duration(days: index));
          final selected = _sameDay(date, selectedDate);
          final isToday = _sameDay(date, today);
          final hasEvents = events.any((event) => _sameDay(event.start, date));
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onSelected(date),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(children: [
                Container(
                  alignment: Alignment.center,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.primary : null,
                    border: isToday && !selected
                        ? Border.all(color: colors.primary)
                        : null,
                  ),
                  child: Text('${date.day}',
                      style: TextStyle(
                        color: selected
                            ? colors.onPrimary
                            : date.month == visibleMonth.month
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                        fontWeight:
                            isToday || selected ? FontWeight.bold : null,
                      )),
                ),
                if (hasEvents)
                  Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                          color: colors.secondary, shape: BoxShape.circle)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Agenda extends StatelessWidget {
  const _Agenda(
      {required this.date, required this.events, required this.countdown});
  final DateTime date;
  final List<NextAEvent> events;
  final CountdownPolicy countdown;

  @override
  Widget build(BuildContext context) {
    final heading = DateFormat('EEEE, d MMMM').format(date);
    if (events.isEmpty) return Center(child: Text('No events on $heading'));
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final event in events)
            Card(
                child: ListTile(
              leading: Container(
                  width: 4,
                  height: 48,
                  color: event.priority > 0 ? colors.tertiary : colors.primary),
              title: Text(event.title),
              subtitle: Text(
                  '${DateFormat.Hm().format(event.start)} – ${DateFormat.Hm().format(event.end)}${event.location == null ? '' : ' · ${event.location}'}'),
              trailing: _countdownText(event, now),
            )),
        ]);
  }

  Widget? _countdownText(NextAEvent event, DateTime now) {
    final remaining = countdown.remaining(event, now);
    return remaining == null ? null : Text(countdown.format(remaining));
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final _demoEvents = <NextAEvent>[
  NextAEvent(
      id: '1',
      title: 'Mobile development',
      type: EventType.classEvent,
      start: DateTime(2026, 9, 10, 8),
      end: DateTime(2026, 9, 10, 10),
      location: 'Room A201',
      priority: 1),
  NextAEvent(
      id: '2',
      title: 'Project review',
      type: EventType.meeting,
      start: DateTime(2026, 9, 10, 14),
      end: DateTime(2026, 9, 10, 15, 30),
      location: 'Online',
      priority: 2),
  NextAEvent(
      id: '3',
      title: 'Database assignment',
      type: EventType.assignment,
      start: DateTime(2026, 9, 14, 9),
      end: DateTime(2026, 9, 14, 11)),
];
