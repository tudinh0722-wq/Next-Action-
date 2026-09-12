import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../application/countdown_policy.dart';
import '../../application/priority_color.dart';
import '../../domain/event.dart';

class PlannerAgenda extends StatelessWidget {
  const PlannerAgenda({super.key, required this.header, required this.events, required this.policy, required this.onEventTap, required this.onEmptyTap});
  final String header;
  final List<NextAEvent> events;
  final CountdownPolicy policy;
  final ValueChanged<NextAEvent> onEventTap;
  final VoidCallback onEmptyTap;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 82),
        children: [
          _AgendaHeader(title: header),
          if (events.isEmpty) const _EmptyAgenda() else for (final event in events) PlannerEventRow(event: event, policy: policy, onTap: () => onEventTap(event)),
        ],
      );
}

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => SizedBox(height: 42, child: Row(children: [Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), const Spacer(), const Icon(Icons.more_horiz_rounded, size: 22)]));
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(top: 28), child: Column(children: [Icon(Icons.event_available_outlined, size: 34, color: scheme.primary), const SizedBox(height: 10), const Text('Không có sự kiện')]));
  }
}

class PlannerEventRow extends StatelessWidget {
  const PlannerEventRow({super.key, required this.event, required this.policy, required this.onTap});
  final NextAEvent event;
  final CountdownPolicy policy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = nextAPriorityColor(event.priority);
    final now = DateTime.now();
    final ongoing = !now.isBefore(event.start) && now.isBefore(event.end);
    final remaining = ongoing ? event.end.difference(now) : policy.remaining(event, now);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PriorityRail(color: color),
          const SizedBox(width: 12),
          Expanded(child: _EventDetails(event: event)),
          const SizedBox(width: 10),
          _EventTimeBlock(event: event, remaining: remaining, ongoing: ongoing, color: color, policy: policy),
        ]),
      ),
    );
  }
}

class _PriorityRail extends StatelessWidget {
  const _PriorityRail({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 3, height: 48, margin: const EdgeInsets.only(top: 3), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)));
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.event});
  final NextAEvent event;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (event.location != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(event.location!, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (event.note != null && event.note!.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(event.note!, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]);
}

class _EventTimeBlock extends StatelessWidget {
  const _EventTimeBlock({required this.event, required this.remaining, required this.ongoing, required this.color, required this.policy});
  static const width = 124.0;
  final NextAEvent event;
  final Duration? remaining;
  final bool ongoing;
  final Color color;
  final CountdownPolicy policy;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${DateFormat.Hm().format(event.start)} – ${DateFormat.Hm().format(event.end)}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (remaining != null) ...[const SizedBox(height: 5), _CountdownBox(remaining: remaining!, ongoing: ongoing, color: color, policy: policy)],
      ]));
}

class _CountdownBox extends StatelessWidget {
  const _CountdownBox({required this.remaining, required this.ongoing, required this.color, required this.policy});
  final Duration remaining;
  final bool ongoing;
  final Color color;
  final CountdownPolicy policy;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(ongoing ? 'Kết thúc sau' : 'Bắt đầu sau', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 1),
          Text(policy.format(remaining), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}
