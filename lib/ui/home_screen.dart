// Legacy home screen - redirects to proper notes list screen
import 'package:duru_notes/ui/notes_list_screen.dart';
// For backwards compatibility, create an alias
import 'package:flutter/material.dart';

export 'notes_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotesListScreen();
  }
}
