import 'package:duru_notes_app/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, _) {
          final session = Supabase.instance.client.auth.currentSession;
          return session != null ? const HomeScreen() : const _Auth();
        },
      ),
    );
  }
}

class _Auth extends StatefulWidget {
  const _Auth();

  @override
  State<_Auth> createState() => _AuthState();
}

class _AuthState extends State<_Auth> {
  final email = TextEditingController();
  final pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Text(
              'Sign in',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signInWithPassword(
                  email: email.text.trim(),
                  password: pass.text.trim(),
                );
              },
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
