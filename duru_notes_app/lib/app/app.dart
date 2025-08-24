import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:duru_notes_app/services/share_service.dart';
import 'package:duru_notes_app/ui/auth_screen.dart';
import 'package:duru_notes_app/ui/home_screen.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Duru Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
        useMaterial3: true,
      ),
      home: ShareAwareWrapper(ref: ref),
    );
  }
}

class ShareAwareWrapper extends StatefulWidget {
  const ShareAwareWrapper({required this.ref, super.key});
  
  final WidgetRef ref;

  @override
  State<ShareAwareWrapper> createState() => _ShareAwareWrapperState();
}

class _ShareAwareWrapperState extends State<ShareAwareWrapper> {
  late ShareService _shareService;

  @override
  void initState() {
    super.initState();
    _shareService = widget.ref.read(shareServiceProvider);
    // Initialize share service after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _shareService.initialize(context);
      }
    });
  }

  @override
  void dispose() {
    _shareService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData ? snapshot.data!.session : null;
        
        if (session != null) {
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
