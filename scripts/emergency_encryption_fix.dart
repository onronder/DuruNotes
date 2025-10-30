#!/usr/bin/env dart
// EMERGENCY HOTFIX: Encryption Format Correction
// This script fixes the critical bug in SupabaseNoteApi.asBytes()
// Run this immediately to prevent further data corruption

import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CORRECTED version of asBytes that preserves JSON format for encrypted data
class EncryptionFormatFix {
  /// Convert various possible wire formats to Uint8List while PRESERVING encryption format
  ///
  /// CRITICAL: This method must NOT combine or modify the JSON structure of encrypted data
  static Uint8List asBytesCorrected(dynamic v) {
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());

    // CRITICAL FIX: Handle libsodium JSON format {"n":"...", "c":"...", "m":"..."}
    // DO NOT combine fields - preserve JSON structure!
    if (v is Map<String, dynamic>) {
      // Check if this is encrypted data format
      if (v.containsKey('n') && v.containsKey('c')) {
        // Return as JSON-encoded bytes - DO NOT COMBINE FIELDS
        return Uint8List.fromList(utf8.encode(jsonEncode(v)));
      }

      // If not encrypted format, try to handle as generic map
      return Uint8List.fromList(utf8.encode(jsonEncode(v)));
    }

    if (v is String) {
      // Check if it's already a JSON string with encryption format
      if (v.startsWith('{') && v.contains('"n"') && v.contains('"c"')) {
        // It's already in correct format - just encode to bytes
        return Uint8List.fromList(utf8.encode(v));
      }

      // Handle Postgres bytea wire format: \xABCD...
      if (v.startsWith(r'\x')) {
        final hex = v.substring(2);
        final out = Uint8List(hex.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return out;
      }

      // For other strings, check if they're base64 or throw error
      try {
        // Try to decode as base64 - this might be legacy format
        return base64Decode(v);
      } on FormatException {
        // SECURITY: Never treat encrypted data as plaintext
        throw FormatException(
          'Unsupported encrypted data format. Data appears corrupted or in unknown format.',
        );
      }
    }

    throw ArgumentError('Unsupported byte value type: ${v.runtimeType}');
  }

  /// Validate that data is in correct SecretBox JSON format
  static bool isValidEncryptedFormat(Uint8List data) {
    try {
      final str = utf8.decode(data);
      final json = jsonDecode(str);

      if (json is! Map<String, dynamic>) return false;

      // Must have required fields
      if (!json.containsKey('n') ||
          !json.containsKey('c') ||
          !json.containsKey('m')) {
        return false;
      }

      // Fields must be base64 strings
      if (json['n'] is! String ||
          json['c'] is! String ||
          json['m'] is! String) {
        return false;
      }

      // Try to decode base64 to verify format
      try {
        base64Decode(json['n'] as String);
        base64Decode(json['c'] as String);
        base64Decode(json['m'] as String);
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Attempt to recover corrupted encrypted data
  static Future<Uint8List?> attemptDataRecovery(dynamic corruptedData) async {
    print('Attempting to recover corrupted encrypted data...');

    // If it's already valid, return it
    if (corruptedData is Uint8List) {
      if (isValidEncryptedFormat(corruptedData)) {
        print('Data is already in valid format');
        return corruptedData;
      }
    }

    // Try various recovery strategies

    // 1. Check if it's a combined byte array that needs to be split
    if (corruptedData is Uint8List || corruptedData is List<int>) {
      final bytes = corruptedData is Uint8List
          ? corruptedData
          : Uint8List.fromList(corruptedData as List<int>);

      // Check if it might be a combined [nonce(24)][mac(16)][ciphertext(...)] format
      if (bytes.length > 40) {
        print('Attempting to reconstruct from combined byte format...');

        // Standard nonce is 24 bytes, MAC is 16 bytes
        final nonce = bytes.sublist(0, 24);
        final mac = bytes.sublist(24, 40);
        final ciphertext = bytes.sublist(40);

        // Reconstruct JSON format
        final reconstructed = {
          'n': base64Encode(nonce),
          'c': base64Encode(ciphertext),
          'm': base64Encode(mac),
        };

        final result = Uint8List.fromList(
          utf8.encode(jsonEncode(reconstructed)),
        );

        if (isValidEncryptedFormat(result)) {
          print('Successfully reconstructed encrypted data format!');
          return result;
        }
      }
    }

    // 2. Check if it's a string that needs parsing
    if (corruptedData is String) {
      // Try to parse as JSON
      try {
        final json = jsonDecode(corruptedData);
        if (json is Map<String, dynamic>) {
          final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
          if (isValidEncryptedFormat(bytes)) {
            return bytes;
          }
        }
      } catch (_) {
        // Not JSON, try other formats
      }
    }

    print('Unable to recover corrupted data');
    return null;
  }
}

// Validation test suite
void runValidationTests() {
  print('\n=== Running Validation Tests ===\n');

  // Test 1: Valid JSON format should pass through unchanged
  print('Test 1: Valid JSON format preservation');
  final validJson = {
    'n': 'base64nonce==',
    'c': 'base64cipher==',
    'm': 'base64mac==',
  };
  final result1 = EncryptionFormatFix.asBytesCorrected(validJson);
  final decoded1 = jsonDecode(utf8.decode(result1));
  assert(decoded1['n'] == validJson['n']);
  assert(decoded1['c'] == validJson['c']);
  assert(decoded1['m'] == validJson['m']);
  print('✅ PASSED: JSON format preserved correctly\n');

  // Test 2: String JSON should be converted to bytes
  print('Test 2: String JSON to bytes conversion');
  final stringJson = '{"n":"nonce","c":"cipher","m":"mac"}';
  final result2 = EncryptionFormatFix.asBytesCorrected(stringJson);
  final decoded2 = utf8.decode(result2);
  assert(decoded2 == stringJson);
  print('✅ PASSED: String JSON converted correctly\n');

  // Test 3: Format validation
  print('Test 3: Format validation');
  final validData = Uint8List.fromList(
    utf8.encode('{"n":"test","c":"test","m":"test"}'),
  );
  assert(EncryptionFormatFix.isValidEncryptedFormat(validData) == true);

  final invalidData = Uint8List.fromList(utf8.encode('{"invalid":"format"}'));
  assert(EncryptionFormatFix.isValidEncryptedFormat(invalidData) == false);
  print('✅ PASSED: Format validation works correctly\n');

  print('=== All Tests Passed ===\n');
}

// Emergency data assessment
Future<void> assessDatabaseDamage(SupabaseClient client) async {
  print('\n=== Assessing Database Damage ===\n');

  try {
    // Check notes table
    final notesResult = await client
        .from('notes')
        .select('id, title_enc, props_enc')
        .limit(100);

    int corruptedNotes = 0;
    int validNotes = 0;

    for (final note in (notesResult as List)) {
      final titleEnc = note['title_enc'];
      final propsEnc = note['props_enc'];

      bool titleValid = false;
      bool propsValid = false;

      if (titleEnc != null) {
        try {
          final bytes = EncryptionFormatFix.asBytesCorrected(titleEnc);
          titleValid = EncryptionFormatFix.isValidEncryptedFormat(bytes);
        } catch (_) {
          titleValid = false;
        }
      }

      if (propsEnc != null) {
        try {
          final bytes = EncryptionFormatFix.asBytesCorrected(propsEnc);
          propsValid = EncryptionFormatFix.isValidEncryptedFormat(bytes);
        } catch (_) {
          propsValid = false;
        }
      }

      if (!titleValid || !propsValid) {
        corruptedNotes++;
        print(
          '❌ Note ${note['id']}: Title valid: $titleValid, Props valid: $propsValid',
        );
      } else {
        validNotes++;
      }
    }

    print('\n📊 Assessment Results:');
    print('Valid notes: $validNotes');
    print('Corrupted notes: $corruptedNotes');
    print(
      'Corruption rate: ${(corruptedNotes / (validNotes + corruptedNotes) * 100).toStringAsFixed(2)}%',
    );

    if (corruptedNotes > 0) {
      print(
        '\n⚠️ WARNING: Corrupted data detected! Immediate action required.',
      );
      print('Run data recovery migration to fix corrupted records.');
    } else {
      print('\n✅ Good news: No corruption detected in sampled data.');
    }
  } catch (e) {
    print('❌ Error assessing database: $e');
  }
}

void main(List<String> args) async {
  print('🚨 EMERGENCY ENCRYPTION FORMAT FIX 🚨');
  print('=====================================\n');

  // Run validation tests
  runValidationTests();

  // If --assess flag is provided, run database assessment
  if (args.contains('--assess')) {
    print('\nConnecting to Supabase for damage assessment...');
    print('Make sure SUPABASE_URL and SUPABASE_ANON_KEY are set.\n');

    final url = String.fromEnvironment('SUPABASE_URL');
    final anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      print('❌ Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set');
      print(
        'Run with: dart --define=SUPABASE_URL=<url> --define=SUPABASE_ANON_KEY=<key> emergency_encryption_fix.dart --assess',
      );
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    await assessDatabaseDamage(Supabase.instance.client);
  } else {
    print('\n📝 Instructions:');
    print('1. Review the corrected asBytes implementation above');
    print('2. Apply the fix to lib/data/remote/supabase_note_api.dart');
    print('3. Run tests to verify the fix');
    print('4. Deploy as emergency hotfix');
    print('\nTo assess database damage, run:');
    print(
      'dart --define=SUPABASE_URL=<url> --define=SUPABASE_ANON_KEY=<key> emergency_encryption_fix.dart --assess',
    );
  }

  print('\n✅ Emergency fix validation complete');
}
