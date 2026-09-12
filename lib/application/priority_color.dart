import 'package:flutter/material.dart';

const nextAPriorityColors = <Color>[
  Color(0xFF8FC7FF),
  Color(0xFFFFB36B),
  Color(0xFFFF8C92),
];

Color nextAPriorityColor(int priority) =>
    nextAPriorityColors[priority.clamp(0, 2).toInt()];
