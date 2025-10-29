#!/usr/bin/env dart
/// Production-grade diagnostic tool for email inbox issue
/// This script connects to production Supabase and diagnoses the exact root cause
library;

import 'dart:convert';
import 'dart:io';

const String projectRef = 'jtaedgpxesshdrnbgvjr';
const String targetAlias = 'note_9a550fd2';

void main() async {
  print('📊 Email Inbox Production Diagnostic Tool');
  print('=' * 60);
  print('');

  // Load environment configuration
  print('🔍 Step 1: Loading Supabase credentials...');
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ??
                      'https://$projectRef.supabase.co';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'];
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (anonKey == null || serviceRoleKey == null) {
    print('❌ ERROR: Missing Supabase credentials');
    print('   Please set SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY');
    print('   You can find these in: https://supabase.com/dashboard/project/$projectRef/settings/api');
    exit(1);
  }

  print('✅ Credentials loaded');
  print('   URL: $supabaseUrl');
  print('');

  final client = HttpClient();

  try {
    // Step 2: Check if alias exists
    print('🔍 Step 2: Checking if alias "$targetAlias" exists...');
    final aliasResponse = await _query(
      client,
      supabaseUrl,
      serviceRoleKey,
      'SELECT id, alias, user_id, is_active, created_at FROM inbound_aliases WHERE alias = \'$targetAlias\' LIMIT 1',
    );

    if (aliasResponse.isEmpty) {
      print('❌ PROBLEM IDENTIFIED: Alias "$targetAlias" does NOT exist in database');
      print('');
      print('🔧 ROOT CAUSE:');
      print('   The email alias has not been created for this user.');
      print('');
      print('💡 SOLUTION:');
      print('   1. Open the app');
      print('   2. Navigate to Settings → Email Inbox');
      print('   3. The app should automatically create an alias');
      print('   4. Or run this SQL manually:');
      print('');
      print('   INSERT INTO inbound_aliases (user_id, alias)');
      print('   VALUES (');
      print('     \'<USER_ID>\',  -- Replace with actual user ID');
      print('     \'$targetAlias\'');
      print('   );');
      exit(1);
    }

    final aliasData = aliasResponse[0];
    final userId = aliasData['user_id'] as String;
    final isActive = aliasData['is_active'] as bool? ?? true;

    print('✅ Alias exists!');
    print('   User ID: $userId');
    print('   Is Active: $isActive');
    print('');

    if (!isActive) {
      print('⚠️  WARNING: Alias is INACTIVE');
      print('   Emails sent to this alias will be rejected');
      print('');
    }

    // Step 3: Check for inbox records for this user
    print('🔍 Step 3: Checking for inbox records for user $userId...');
    final inboxResponse = await _query(
      client,
      supabaseUrl,
      serviceRoleKey,
      '''SELECT
           id,
           source_type,
           title,
           is_processed,
           created_at,
           metadata->>'from' as sender_email,
           metadata->>'to' as recipient_email
         FROM clipper_inbox
         WHERE user_id = '$userId'
         ORDER BY created_at DESC
         LIMIT 10''',
    );

    print('   Found ${inboxResponse.length} inbox records');
    print('');

    if (inboxResponse.isEmpty) {
      print('❌ PROBLEM IDENTIFIED: No emails in database for this user');
      print('');
      print('🔧 ROOT CAUSE: One of the following:');
      print('   1. SendGrid webhook is not configured correctly');
      print('   2. SendGrid account has unpaid invoice (emails blocked)');
      print('   3. Emails were never sent to SendGrid');
      print('   4. Edge function failed to process emails');
      print('');
      print('💡 DIAGNOSTIC STEPS:');
      print('');
      print('   A) Check SendGrid webhook configuration:');
      print('      URL: https://$projectRef.supabase.co/functions/v1/email-inbox');
      print('      Go to: https://app.sendgrid.com/settings/parse');
      print('');
      print('   B) Check SendGrid billing:');
      print('      https://app.sendgrid.com/billing/invoices');
      print('');
      print('   C) Check Edge Function logs:');
      print('      supabase functions logs email-inbox --limit 50');
      print('');
      print('   D) Test Edge Function manually:');
      print('      curl -X POST \\');
      print('        "https://$projectRef.supabase.co/functions/v1/email-inbox?secret=YOUR_SECRET" \\');
      print('        -H "Content-Type: application/json" \\');
      print('        -d \'{');
      print('          "to": "$targetAlias@in.durunotes.app",');
      print('          "from": "test@example.com",');
      print('          "subject": "Test Email",');
      print('          "text": "Test content"');
      print('        }\'');
      exit(1);
    }

    // Print inbox records
    print('📧 Inbox Records:');
    print('-' * 60);
    for (final record in inboxResponse) {
      print('   ID: ${record['id']}');
      print('   From: ${record['sender_email'] ?? 'N/A'}');
      print('   To: ${record['recipient_email'] ?? 'N/A'}');
      print('   Subject: ${record['title']}');
      print('   Is Processed: ${record['is_processed']}');
      print('   Created: ${record['created_at']}');
      print('   ---');
    }
    print('');

    // Step 4: Check if records are processed
    final unprocessed = inboxResponse.where((r) =>
      r['is_processed'] == null || r['is_processed'] == false
    ).toList();

    print('📊 Summary:');
    print('   Total Records: ${inboxResponse.length}');
    print('   Unprocessed: ${unprocessed.length}');
    print('   Processed: ${inboxResponse.length - unprocessed.length}');
    print('');

    if (unprocessed.isEmpty && inboxResponse.isNotEmpty) {
      print('❌ PROBLEM IDENTIFIED: All emails are marked as PROCESSED');
      print('');
      print('🔧 ROOT CAUSE:');
      print('   The app query filters by: is_processed IS NULL OR is_processed = false');
      print('   But all emails have is_processed = true');
      print('');
      print('💡 SOLUTION:');
      print('   Option 1: Reset is_processed flag (RECOMMENDED):');
      print('   UPDATE clipper_inbox');
      print('   SET is_processed = false');
      print('   WHERE user_id = \'$userId\'');
      print('     AND (converted_to_note_id IS NULL OR converted_to_note_id = \'\');');
      print('');
      print('   Option 2: Change app query to show all records:');
      print('   Remove the .or(\'is_processed.is.null,is_processed.eq.false\') filter');
      exit(1);
    }

    if (unprocessed.length >= 2) {
      print('✅ SUCCESS: Found ${unprocessed.length} unprocessed emails!');
      print('');
      print('🎯 These emails SHOULD be visible in the app.');
      print('');
      print('🔧 If app still shows empty, check:');
      print('');
      print('   1. User Authentication:');
      print('      - Is the user logged in with the correct account?');
      print('      - Check app logs for: "Current user ID: $userId"');
      print('');
      print('   2. App Query:');
      print('      - Check app logs for: "Query response count: X"');
      print('      - Should show ${unprocessed.length} records');
      print('');
      print('   3. RLS Policies:');
      print('      - Run this query as the authenticated user:');
      print('      SET LOCAL request.jwt.claims.sub = \'$userId\';');
      print('      SELECT COUNT(*) FROM clipper_inbox;');
      print('');
      print('   4. Real-time Subscriptions:');
      print('      - Check if real-time is enabled on clipper_inbox table');
      print('      - Restart the app to refresh connection');
    }

    // Step 5: Check user account
    print('');
    print('🔍 Step 5: Verifying user account...');
    final userResponse = await _query(
      client,
      supabaseUrl,
      serviceRoleKey,
      'SELECT id, email, created_at FROM auth.users WHERE id = \'$userId\' LIMIT 1',
    );

    if (userResponse.isEmpty) {
      print('❌ CRITICAL: User account does not exist!');
      print('   This is a data integrity issue.');
      exit(1);
    }

    final userData = userResponse[0];
    print('✅ User account verified');
    print('   Email: ${userData['email']}');
    print('   Account Created: ${userData['created_at']}');
    print('');

    print('=' * 60);
    print('✅ Diagnostic Complete');
    print('');

  } catch (e, stack) {
    print('❌ ERROR: $e');
    print('Stack trace: $stack');
    exit(1);
  } finally {
    client.close();
  }
}

Future<List<dynamic>> _query(
  HttpClient client,
  String supabaseUrl,
  String serviceRoleKey,
  String sql,
) async {
  final request = await client.postUrl(
    Uri.parse('$supabaseUrl/rest/v1/rpc/exec_sql'),
  );

  request.headers.set('apikey', serviceRoleKey);
  request.headers.set('Authorization', 'Bearer $serviceRoleKey');
  request.headers.set('Content-Type', 'application/json');

  // Try using the PostgREST format
  request.write(jsonEncode({'query': sql}));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode == 404) {
    // exec_sql might not exist, try direct query
    return await _directQuery(client, supabaseUrl, serviceRoleKey, sql);
  }

  if (response.statusCode != 200) {
    throw Exception('Query failed: ${response.statusCode} - $responseBody');
  }

  return jsonDecode(responseBody) as List<dynamic>;
}

Future<List<dynamic>> _directQuery(
  HttpClient client,
  String supabaseUrl,
  String serviceRoleKey,
  String sql,
) async {
  // Extract table name from SQL
  final tableMatch = RegExp(r'FROM\s+(\w+)').firstMatch(sql);
  if (tableMatch == null) {
    throw Exception('Could not extract table name from SQL');
  }

  final tableName = tableMatch.group(1)!;

  // Build query URL (simplified - won't support all SQL features)
  final request = await client.getUrl(
    Uri.parse('$supabaseUrl/rest/v1/$tableName?limit=10'),
  );

  request.headers.set('apikey', serviceRoleKey);
  request.headers.set('Authorization', 'Bearer $serviceRoleKey');

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();

  if (response.statusCode != 200) {
    throw Exception('Query failed: ${response.statusCode} - $responseBody');
  }

  return jsonDecode(responseBody) as List<dynamic>;
}
