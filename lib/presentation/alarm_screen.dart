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
  double _dragProgress = 0;

  static const _swipeTriggerFraction = 0.72;

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

    // Confirming the alarm intentionally cancels all remaining reminder slots
    // for this concrete event. Recurring occurrences have distinct event IDs,
    // so confirming one occurrence does not cancel the next occurrence.
    await widget.scheduler.cancelEvent(widget.alert.eventId);
    if (!mounted) return;
    AlarmAlertController.consumePending();
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;

    // Auto-dismiss must also stop the native repeating vibration. It is the
    // same acknowledgement of the active alarm from the scheduler's point of
    // view, only without an explicit user swipe.
    await widget.scheduler.cancelEvent(widget.alert.eventId);
    if (!mounted) return;
    AlarmAlertController.consumePending();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    final width = context.size?.width ?? 1;
    setState(() {
      _dragProgress = (_dragProgress + details.delta.dx / width).clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_closing) return;
    if (_dragProgress >= _swipeTriggerFraction) {
      _acknowledge();
      return;
    }
    setState(() => _dragProgress = 0);
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
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
                  const Spacer(flex: 2),
                  Center(
                    child: SizedBox(
                      width: 320,
                      child: _SwipeToAcknowledge(
                        progress: _dragProgress,
                        enabled: !_closing,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeToAcknowledge extends StatelessWidget {
  const _SwipeToAcknowledge({
    required this.progress,
    required this.enabled,
  });

  final double progress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveProgress = progress.clamp(0.0, 1.0);

    return Container(
      height: 68,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        color: scheme.surface.withOpacity(0.72),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const knobSize = 56.0;
          const horizontalPadding = 6.0;
          final travel = constraints.maxWidth - knobSize - horizontalPadding * 2;
          final offset = horizontalPadding + travel * effectiveProgress;

          return Stack(
            alignment: Alignment.center,
            children: [
              Text(
                enabled ? 'VUỐT SANG PHẢI ĐỂ XÁC NHẬN' : 'ĐANG XÁC NHẬN...',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                left: offset,
                top: horizontalPadding,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary,
                    boxShadow: const [
                      BoxShadow(blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
