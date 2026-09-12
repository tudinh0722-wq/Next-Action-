import '../domain/event.dart';

class CountdownPolicy {
  const CountdownPolicy({this.horizon = const Duration(days: 14)});

  final Duration horizon;

  Duration? remaining(NextAEvent event, DateTime now) {
    if (now.isBefore(event.start)) {
      final delta = event.start.difference(now);
      return delta <= horizon ? delta : null;
    }

    if (now.isBefore(event.end)) {
      return event.end.difference(now);
    }

    return null;
  }

  String format(Duration remaining) {
    if (remaining.inDays >= 1) {
      final days = remaining.inDays;
      final hours = remaining.inHours.remainder(24);
      return '${days}d ${hours}h';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
