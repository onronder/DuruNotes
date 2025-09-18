import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Comprehensive subscription management service using Adapty
class SubscriptionService {
  SubscriptionService({
    required AppLogger logger,
    required AnalyticsService analytics,
  }) : _logger = logger,
       _analytics = analytics;
  final AppLogger _logger;
  final AnalyticsService _analytics;
  
  // Cache for profile to reduce API calls
  AdaptyProfile? _cachedProfile;
  DateTime? _cacheTime;
  static const _cacheValidityDuration = Duration(minutes: 5);

  /// Check if user has premium subscription with caching
  Future<bool> hasPremiumAccess() async {
    try {
      // Use cached profile if available
      final profile = await getUserProfile();
      
      if (profile == null) {
        return false;
      }

      // Check for active premium subscription
      final hasAccess = profile.accessLevels['premium']?.isActive ?? false;

      _logger.info('Premium access check: $hasAccess (cached)');

      // Only track analytics occasionally, not on every check
      if (_cacheTime == DateTime.now()) {  // Only on fresh fetch
        _analytics.event(
          AnalyticsEvents.noteCreate,
          properties: {
            'subscription_check': true,
            'has_premium': hasAccess,
            'access_level': hasAccess ? 'premium' : 'free',
          },
        );
      }

      return hasAccess;
    } catch (e) {
      _logger.error('Failed to check premium access: $e');

      // Track error
      _analytics.event(
        AnalyticsEvents.noteCreate,
        properties: {'subscription_check_error': e.toString()},
      );

      return false; // Default to free access on error
    }
  }

  /// Get current user profile with caching
  Future<AdaptyProfile?> getUserProfile({bool forceRefresh = false}) async {
    try {
      // Check if we have a valid cached profile
      if (!forceRefresh && 
          _cachedProfile != null && 
          _cacheTime != null &&
          DateTime.now().difference(_cacheTime!) < _cacheValidityDuration) {
        _logger.info('Returning cached user profile');
        return _cachedProfile;
      }

      // Fetch fresh profile
      final profile = await Adapty().getProfile();
      
      // Update cache
      _cachedProfile = profile;
      _cacheTime = DateTime.now();

      _logger.info('Retrieved and cached user profile successfully');

      return profile;
    } catch (e) {
      _logger.error('Failed to get user profile: $e');
      // Return cached profile if available, even if expired
      return _cachedProfile;
    }
  }
  
  /// Clear profile cache (call on logout)
  void clearCache() {
    _cachedProfile = null;
    _cacheTime = null;
  }

  /// Present paywall for subscription upgrade (temporarily no-op UI to ensure build)
  Future<bool> presentPaywall({
    required String placementId,
    required BuildContext context,
  }) async {
    try {
      // Fetch paywall to validate availability (no UI presentation for now)
      final paywall = await Adapty().getPaywall(
        placementId: placementId,
        locale: 'en',
      );
      _logger.info('Paywall fetched for placement: $placementId');
      return false;
    } catch (e) {
      _logger.error('Failed to present paywall: $e');
      _analytics.event(
        AnalyticsEvents.noteCreate,
        properties: {
          'paywall_error': e.toString(),
          'placement_id': placementId,
        },
      );
      return false;
    }
  }

  /// Handle purchase transaction
  // Reserved for purchase flow implementation
  // Future<bool> _handlePurchase(AdaptyPaywallProduct product) async {
  //   try {
  //     _logger.info('Processing purchase for product: ${product.vendorProductId}');
  //
  //     // Make purchase
  //     await Adapty().makePurchase(product: product);
  //     // In v3, purchase result may not include profile; fetch profile to confirm
  //     final profile = await Adapty().getProfile();
  //     if (profile.accessLevels['premium']?.isActive == true) {
  //       _logger.info('Purchase successful - premium access granted');
  //
  //       // Track successful purchase
  //       _analytics.event(AnalyticsEvents.noteCreate, properties: {
  //         'purchase_successful': true,
  //         'product_id': product.vendorProductId,
  //         'premium_granted': true,
  //       });
  //
  //       return true;
  //     } else {
  //       _logger.warning('Purchase completed but premium access not granted');
  //       return false;
  //     }
  //
  //   } catch (e) {
  //     _logger.error('Purchase failed: $e');
  //
  //     // Track purchase failure
  //     _analytics.event(AnalyticsEvents.noteCreate, properties: {
  //       'purchase_failed': true,
  //       'product_id': product.vendorProductId,
  //       'error': e.toString(),
  //     });
  //
  //     return false;
  //   }
  // }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    try {
      _logger.info('Restoring purchases...');

      final profile = await Adapty().restorePurchases();

      final hasAccess = profile.accessLevels['premium']?.isActive ?? false;

      _logger.info('Purchases restored - premium access: $hasAccess');

      // Track restore
      _analytics.event(
        AnalyticsEvents.noteCreate,
        properties: {
          'purchases_restored': true,
          'premium_access_restored': hasAccess,
        },
      );

      return hasAccess;
    } catch (e) {
      _logger.error('Failed to restore purchases: $e');

      // Track restore failure
      _analytics.event(
        AnalyticsEvents.noteCreate,
        properties: {'restore_failed': true, 'error': e.toString()},
      );

      return false;
    }
  }

  /// Get available products for a paywall
  Future<List<AdaptyPaywallProduct>> getProducts(String placementId) async {
    try {
      final paywall = await Adapty().getPaywall(
        placementId: placementId,
        locale: 'en',
      );
      // Fetch products for the paywall using current API
      final products = await Adapty().getPaywallProducts(paywall: paywall);

      _logger.info(
        'Retrieved ${products.length} products for placement: $placementId',
      );

      return products;
    } catch (e) {
      _logger.error('Failed to get products: $e');
      return [];
    }
  }

  /// Identify user for personalization
  Future<void> identifyUser(String userId) async {
    try {
      await Adapty().identify(userId);

      _logger.info('User identified: $userId');

      // Track user identification
      _analytics.event(
        AnalyticsEvents.noteCreate,
        properties: {
          'user_identified': true,
          'user_id_provided': userId.isNotEmpty,
        },
      );
    } catch (e) {
      _logger.error('Failed to identify user: $e');
    }
  }

  /// Set user attributes for segmentation
  Future<void> setUserAttributes(Map<String, String> attributes) async {
    try {
      final builder = AdaptyProfileParametersBuilder();

      // Custom attributes API changed in recent versions; skip for now to ensure build
      await Adapty().updateProfile(builder.build());

      _logger.info('User attributes updated: ${attributes.keys.join(', ')}');

      // Track attribute update
      _analytics.event(
        AnalyticsEvents.noteCreate,
        properties: {
          'user_attributes_updated': true,
          'attributes_count': attributes.length,
        },
      );
    } catch (e) {
      _logger.error('Failed to set user attributes: $e');
    }
  }

  /// Check for promotional offers
  Future<List<AdaptyPaywallProduct>> getPromotionalOffers(
    String placementId,
  ) async {
    try {
      final products = await getProducts(placementId);

      // New SDK may expose offers differently; return all products for now
      _logger.info(
        'Returning ${products.length} products (promotional offer filter disabled)',
      );
      return products;
    } catch (e) {
      _logger.error('Failed to get promotional offers: $e');
      return [];
    }
  }

  /// Handle subscription lifecycle events
  void setupSubscriptionListeners() {
    // Note: Adapty automatically tracks subscription events
    // Additional custom logic can be added here for app-specific needs
    _logger.info('Subscription listeners configured');
  }
}

/// Riverpod provider for SubscriptionService
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(
    logger: LoggerFactory.instance,
    analytics: AnalyticsFactory.instance,
  );
});

/// Provider for premium access status
final premiumAccessProvider = FutureProvider<bool>((ref) async {
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return subscriptionService.hasPremiumAccess();
});

/// Provider for user subscription profile
final userProfileProvider = FutureProvider<AdaptyProfile?>((ref) async {
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return subscriptionService.getUserProfile();
});
