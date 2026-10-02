import 'package:flutter/material.dart';

enum PonosDestination {
  overview(
    label: 'Overview',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  workAreas(
    label: 'Work Areas',
    icon: Icons.track_changes_outlined,
    selectedIcon: Icons.track_changes,
  ),
  focus(label: 'Focus', icon: Icons.timer_outlined, selectedIcon: Icons.timer),
  logWork(
    label: 'Log Work',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
  );

  const PonosDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
