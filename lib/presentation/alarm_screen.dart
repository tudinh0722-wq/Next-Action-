import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/alarm_alert.dart';
import '../application/alarm_scheduler.dart';

class AlarmScreen extends StatelessWidget {
  const AlarmScreen({
    super.key,
    required this.alert,
    required this.scheduler,
  });

  final AlarmAlert alert;
  final AlarmScheduler scheduler;

  Future<void> _acknowledge(BuildContext context) async {
    await scheduler.cancelEvent(alert.eventId);
    AlarmAlertController.consumePending();

    if (!context.mounted) return;
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRepeat = alert.slotIndex > 0;
    final reminderText = isRepeat
        ? 'Nhắc lại'
        : alert.minutesBefore > 0
            ? 'Còn ${alert.minutesBefore} phút nữa'
            : 'Đang diễn ra';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer,
              scheme.surface,
              scheme.secondaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Icon(
                  Icons.notifications_active_rounded,
                  size: 72,
                  color: scheme.primary,
                ),
                const SizedBox(height: 28),
                Text(
                  reminderText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  alert.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (alert.note != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    alert.note!,
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  child: FloatingActionButton.extended(
                    onPressed: () => _acknowledge(context),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('ĐÃ BIẾT'),
                    elevation: 6,
                    extendedPadding: const EdgeInsets.symmetric(horizontal: 30),
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
