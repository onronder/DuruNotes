import 'package:duru_notes/theme/material3_theme.dart' show DuruColors;
import 'package:duru_notes/ui/notes_list_screen.dart';
import 'package:duru_notes/ui/task_list_screen.dart';
import 'package:duru_notes/ui/productivity_analytics_screen.dart';
import 'package:duru_notes/ui/time_tracking_dashboard_screen.dart';
import 'package:duru_notes/ui/widgets/shared/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  final List<_Destination> _destinations = const [
    _Destination(
      label: 'Notes',
      icon: Icons.notes_outlined,
      selectedIcon: Icons.notes,
    ),
    _Destination(
      label: 'Tasks',
      icon: Icons.check_circle_outline,
      selectedIcon: Icons.check_circle,
    ),
    _Destination(
      label: 'Tracking',
      icon: Icons.timer_outlined,
      selectedIcon: Icons.timer,
    ),
    _Destination(
      label: 'Insights',
      icon: Icons.auto_graph_outlined,
      selectedIcon: Icons.auto_graph,
    ),
  ];

  late final List<Widget> _screens = const [
    NotesListScreen(),
    TaskListScreen(),
    TimeTrackingDashboardScreen(),
    ProductivityAnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavigation(
      destinations: _destinations
          .map(
            (destination) => NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(
                destination.selectedIcon,
                color: DuruColors.primary,
              ),
              label: destination.label,
            ),
          )
          .toList(),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (value) {
        setState(() => _selectedIndex = value);
      },
      body: _screens[_selectedIndex],
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
