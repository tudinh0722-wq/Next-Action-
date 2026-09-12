import 'package:flutter/material.dart';

/// Product-level reminder priorities. These are deliberately independent of
/// Android notification importance; all three use the same NextA alarm UX.
const nextAPriorityLabels = <String>[
  'HIGH 1',
  'HIGH 2',
  'HIGH 3',
];

const nextAPriorityColors = <Color>[
  Color(0xFF8FC7FF),
  Color(0xFFFFB36B),
  Color(0xFFFF8C92),
];

String nextAPriorityLabel(int priority) =>
    nextAPriorityLabels[priority.clamp(0, 2).toInt()];

Color nextAPriorityColor(int priority) =>
    nextAPriorityColors[priority.clamp(0, 2).toInt()];
