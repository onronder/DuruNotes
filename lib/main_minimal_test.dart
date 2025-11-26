import 'dart:async';
import 'package:flutter/material.dart';

/// Minimal test to isolate setState() issue
/// This bypasses all bootstrap logic to test if basic setState() works
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MinimalTestApp());
}

class MinimalTestApp extends StatefulWidget {
  const MinimalTestApp({super.key});

  @override
  State<MinimalTestApp> createState() => _MinimalTestAppState();
}

class _MinimalTestAppState extends State<MinimalTestApp> {
  String _message = 'Initial State';
  int _buildCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('🧪 [MinimalTest] initState called');

    // Test 1: Immediate setState
    debugPrint('🧪 [MinimalTest] Calling setState immediately');
    setState(() {
      _message = 'setState immediate';
    });
    debugPrint('🧪 [MinimalTest] setState immediate completed');

    // Test 2: Delayed setState (simulating async work)
    Future.delayed(const Duration(milliseconds: 500), () {
      debugPrint('🧪 [MinimalTest] Calling setState after delay');
      if (mounted) {
        setState(() {
          _message = 'setState delayed';
        });
        debugPrint('🧪 [MinimalTest] setState delayed completed');
      }
    });

    // Test 3: setState with scheduleMicrotask
    scheduleMicrotask(() {
      debugPrint('🧪 [MinimalTest] Calling setState in microtask');
      if (mounted) {
        setState(() {
          _message = 'setState microtask';
        });
        debugPrint('🧪 [MinimalTest] setState microtask completed');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    debugPrint(
      '🧪 [MinimalTest] build() called #$_buildCount, message: $_message',
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Build Count: $_buildCount',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text('Message: $_message', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  debugPrint(
                    '🧪 [MinimalTest] Button pressed, calling setState',
                  );
                  setState(() {
                    _message = 'Button pressed';
                  });
                  debugPrint('🧪 [MinimalTest] Button setState completed');
                },
                child: const Text('Test Button setState'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
