#!/bin/bash
# Emergency Hotfix Script for Encryption Format Bug
# This script applies the critical fix to SupabaseNoteApi.asBytes()

set -e

echo "🚨 APPLYING EMERGENCY ENCRYPTION HOTFIX 🚨"
echo "=========================================="
echo ""

# Backup the original file
echo "📁 Creating backup of original file..."
cp lib/data/remote/supabase_note_api.dart lib/data/remote/supabase_note_api.dart.backup.$(date +%Y%m%d_%H%M%S)

# Create the patch file
cat > /tmp/encryption_fix.patch << 'EOF'
--- a/lib/data/remote/supabase_note_api.dart
+++ b/lib/data/remote/supabase_note_api.dart
@@ -306,24 +306,14 @@ class SupabaseNoteApi {
     if (v is List<int>) return Uint8List.fromList(v);
     if (v is List<dynamic>) return Uint8List.fromList(v.cast<int>());

-    // PRODUCTION FIX: Handle libsodium JSON format {"n":"...", "c":"...", "m":"..."}
-    // This is the format Supabase stores encrypted data in
+    // CRITICAL FIX: Preserve JSON format for encrypted data
+    // DO NOT combine fields - CryptoBox expects JSON structure
     if (v is Map<String, dynamic>) {
-      final nonce = v['n'] as String?;
-      final ciphertext = v['c'] as String?;
-      final mac = v['m'] as String?;
-
-      if (nonce != null && ciphertext != null) {
-        // Combine into libsodium secretbox format:
-        // [nonce (24 bytes)][mac (16 bytes)][ciphertext]
-        final nonceBytes = base64Decode(nonce);
-        final ciphertextBytes = base64Decode(ciphertext);
-        final macBytes = mac != null ? base64Decode(mac) : Uint8List(0);
-
-        // libsodium uses [nonce][mac+ciphertext] format
-        final combined = Uint8List(nonceBytes.length + macBytes.length + ciphertextBytes.length);
-        combined.setRange(0, nonceBytes.length, nonceBytes);
-        combined.setRange(nonceBytes.length, nonceBytes.length + macBytes.length, macBytes);
-        combined.setRange(nonceBytes.length + macBytes.length, combined.length, ciphertextBytes);
-
-        return combined;
+      // Check if this is encrypted data format
+      if (v.containsKey('n') && v.containsKey('c')) {
+        // Return as JSON-encoded bytes - preserve structure!
+        return Uint8List.fromList(utf8.encode(jsonEncode(v)));
       }
+      // For other maps, also encode as JSON
+      return Uint8List.fromList(utf8.encode(jsonEncode(v)));
     }

     if (v is String) {
-      // PRODUCTION FIX: Try to parse as JSON first (for string-encoded libsodium format)
+      // Check if it's already a JSON string with encryption format
       if (v.startsWith('{') && v.contains('"n"') && v.contains('"c"')) {
-        try {
-          final jsonMap = jsonDecode(v) as Map<String, dynamic>;
-          return asBytes(jsonMap); // Recursively handle the map
-        } on FormatException {
-          // Not valid JSON, continue with other string formats
-        }
+        // Already in correct format - just encode to bytes
+        return Uint8List.fromList(utf8.encode(v));
       }

       // Postgres bytea wire format: \xABCD...
@@ -350,7 +340,8 @@ class SupabaseNoteApi {
       try {
         return base64Decode(v);
       } on FormatException {
-        return Uint8List.fromList(utf8.encode(v));
+        // SECURITY: Never treat encrypted data as plaintext
+        throw FormatException('Unsupported encrypted data format');
       }
     }
     throw ArgumentError('Unsupported byte value type: ${v.runtimeType}');
EOF

echo "🔧 Applying patch..."
if patch -p1 < /tmp/encryption_fix.patch; then
    echo "✅ Patch applied successfully!"
else
    echo "❌ Failed to apply patch. Manual intervention required."
    echo "Please review lib/data/remote/supabase_note_api.dart.backup.* for the original"
    exit 1
fi

echo ""
echo "🧪 Running quick validation..."
if flutter analyze --no-fatal-infos lib/data/remote/supabase_note_api.dart; then
    echo "✅ Code analysis passed!"
else
    echo "⚠️ Code analysis found issues. Please review."
fi

echo ""
echo "📋 Next Steps:"
echo "1. Run: flutter test test/services/encryption_test.dart"
echo "2. Test encryption/decryption with a sample note"
echo "3. Deploy to staging environment first"
echo "4. Monitor error logs for 'Unexpected character' errors"
echo "5. If stable, deploy to production"
echo ""
echo "⚠️ IMPORTANT: Monitor closely after deployment!"
echo "Look for:"
echo "  - Decryption errors in logs"
echo "  - 'Unexpected character' messages"
echo "  - Any increase in error rates"
echo ""
echo "🔄 To rollback if needed:"
echo "cp lib/data/remote/supabase_note_api.dart.backup.<timestamp> lib/data/remote/supabase_note_api.dart"
echo ""
echo "✅ Hotfix script completed!"