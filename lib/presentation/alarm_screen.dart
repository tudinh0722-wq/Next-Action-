import 'dart:async';

import 'package:flutter/material.dart';

import '../application/alarm_alert.dart';
import '../application/alarm_scheduler.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({
    super.key,
    required this.alert,
    required this.scheduler,
    this.autoDismissAfter = const Duration(minutes: 5),
  });

  final AlarmAlert alert;
  final AlarmScheduler scheduler;
  final Duration autoDismissAfter;

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  Timer? _autoDismissTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer(widget.autoDismissAfter, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _acknowledge() async {
    if (_closing) return;
    setState(() => _closing = true);
    _autoDismissTimer?.cancel();

    // cancelEvent intentionally cancels the remaining reminder slots for this
    // concrete event. Recurring occurrences have distinct event IDs, so the
    // next occurrence is not affected.
    await widget.scheduler.cancelEvent(widget.alert.eventId);
    if (!mounted) return;
    AlarmAlertController.consumePending();
  }

  void _dismiss() {
    if (_closing) return;
    _closing = true;
    AlarmAlertController.consumePending();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isRepeat = widget.alert.slotIndex > 0;
    final reminderText = isRepeat
        ? 'Nhắc lại'
        : widget.alert.minutesBefore > 0
            ? 'Còn ${widget.alert.minutesBefore} phút nữa'
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
                  widget.alert.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (widget.alert.note != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.alert.note!,
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
                    onPressed: _closing ? null : _acknowledge,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('XÁC NHẬN'),
                    elevation: 6,
                    extendedPadding:
                        const EdgeInsets.symmetric(horizontal: 30),
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
