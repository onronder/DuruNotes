import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing email aliases with caching and domain configuration
class EmailAliasService {
  EmailAliasService(this._supabase);
  
  final SupabaseClient _supabase;
  static const String _aliasKeyPrefix = 'email_alias_';
  static const String _aliasTimestampPrefix = 'email_alias_ts_';
  static const Duration _cacheExpiration = Duration(days: 7);
  
  /// Get the inbound email domain from environment configuration
  String get inboundDomain {
    // ALWAYS use in.durunotes.app - this is the correct domain for production
    // Ignore any compile-time or dotenv overrides to prevent misconfiguration
    const correctDomain = 'in.durunotes.app';
    
    // Debug logging to see what values are present (but we won't use them)
    final fromDotenv = dotenv.env['INBOUND_EMAIL_DOMAIN'];
    const fromCompileTime = String.fromEnvironment(
      'INBOUND_EMAIL_DOMAIN',
      defaultValue: '',
    );
    
    debugPrint('[EmailAliasService] Domain from dotenv: $fromDotenv (ignored)');
    debugPrint('[EmailAliasService] Domain from compile-time: ${fromCompileTime.isEmpty ? "(empty)" : fromCompileTime} (ignored)');
    debugPrint('[EmailAliasService] Using correct domain: $correctDomain');
    
    return correctDomain;
  }

  /// Get or create the user's email alias with caching
  Future<String?> getOrCreateAlias() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;
      
      // Try to get from cache first
      final cachedAlias = await _getCachedAlias(userId);
      if (cachedAlias != null) {
        debugPrint('[EmailAliasService] Using cached alias: $cachedAlias');
        return cachedAlias;
      }
      
      // Try to get existing alias from database
      final response = await _supabase
          .from('inbound_aliases')
          .select('alias')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response != null && response['alias'] != null) {
        final alias = response['alias'] as String;
        await _cacheAlias(userId, alias);
        debugPrint('[EmailAliasService] Retrieved existing alias: $alias');
        return alias;
      }
      
      // Generate new alias if none exists
      final result = await _supabase.rpc<dynamic>(
        'generate_user_alias',
        params: {'p_user_id': userId},
      );
      
      if (result != null) {
        final alias = result as String;
        await _cacheAlias(userId, alias);
        debugPrint('[EmailAliasService] Generated new alias: $alias');
        return alias;
      }
      
      return null;
    } catch (e) {
      debugPrint('[EmailAliasService] Error getting alias: $e');
      return null;
    }
  }
  
  /// Get the full inbound email address for the user
  Future<String?> getFullEmailAddress() async {
    final alias = await getOrCreateAlias();
    if (alias == null) {
      debugPrint('[EmailAliasService] No alias available');
      return null;
    }
    final domain = inboundDomain;
    final fullAddress = '$alias@$domain';
    debugPrint('[EmailAliasService] Full email address: $fullAddress');
    return fullAddress;
  }
  
  /// Clear cached alias (useful on logout)
  Future<void> clearCache() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_aliasKeyPrefix$userId');
      await prefs.remove('$_aliasTimestampPrefix$userId');
      debugPrint('[EmailAliasService] Cache cleared for user: $userId');
    } catch (e) {
      debugPrint('[EmailAliasService] Error clearing cache: $e');
    }
  }
  
  /// Force refresh the alias from server
  Future<String?> refreshAlias() async {
    await clearCache();
    return getOrCreateAlias();
  }
  
  // Private helper methods
  
  Future<String?> _getCachedAlias(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alias = prefs.getString('$_aliasKeyPrefix$userId');
      
      if (alias == null) return null;
      
      // Check if cache is expired
      final timestamp = prefs.getInt('$_aliasTimestampPrefix$userId');
      if (timestamp != null) {
        final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (DateTime.now().difference(cachedTime) > _cacheExpiration) {
          debugPrint('[EmailAliasService] Cache expired for user: $userId');
          return null;
        }
      }
      
      return alias;
    } catch (e) {
      debugPrint('[EmailAliasService] Error reading cache: $e');
      return null;
    }
  }
  
  Future<void> _cacheAlias(String userId, String alias) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_aliasKeyPrefix$userId', alias);
      await prefs.setInt(
        '$_aliasTimestampPrefix$userId',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('[EmailAliasService] Cached alias for user: $userId');
    } catch (e) {
      debugPrint('[EmailAliasService] Error caching alias: $e');
    }
  }
}
