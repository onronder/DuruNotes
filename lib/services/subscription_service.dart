import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/monitoring/app_logger.dart';
import 'analytics/analytics_service.dart';

/// Comprehensive subscription management service using Adapty
class SubscriptionService {
  final AppLogger _logger;
  final AnalyticsService _analytics;
  
  SubscriptionService({
    required AppLogger logger,
    required AnalyticsService analytics,
  }) : _logger = logger,
       _analytics = analytics;

  /// Check if user has premium subscription
  Future<bool> hasPremiumAccess() async {
    try {
      final profile = await Adapty().getProfile();
      
      // Check for active premium subscription
      final hasAccess = profile.accessLevels['premium']?.isActive ?? false;
      
      _logger.info('Premium access check: $hasAccess');
      
      // Track subscription status
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'subscription_check': true,
        'has_premium': hasAccess,
        'access_level': hasAccess ? 'premium' : 'free',
      });
      
      return hasAccess;
      
    } catch (e) {
      _logger.error('Failed to check premium access: $e');
      
      // Track error
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'subscription_check_error': e.toString(),
      });
      
      return false; // Default to free access on error
    }
  }

  /// Get current user profile
  Future<AdaptyProfile?> getUserProfile() async {
    try {
      final profile = await Adapty().getProfile();
      
      _logger.info('Retrieved user profile successfully');
      
      return profile;
      
    } catch (e) {
      _logger.error('Failed to get user profile: $e');
      return null;
    }
  }

  /// Present paywall for subscription upgrade
  Future<bool> presentPaywall({
    required String placementId,
    required BuildContext context,
  }) async {
    try {
      // Get paywall configuration
      final paywall = await Adapty().getPaywall(
        placementId: placementId,
        locale: 'en', // or get from app locale
      );
      
      if (paywall == null) {
        _logger.warning('No paywall found for placement: $placementId');
        return false;
      }
      
      // Present paywall using AdaptyUI
      final result = await AdaptyUI().presentPaywall(
        paywall: paywall,
        context: context,
      );
      
      _logger.info('Paywall presented with result: ${result?.action}');
      
      // Track paywall presentation
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'paywall_presented': true,
        'placement_id': placementId,
        'paywall_result': result?.action?.toString(),
      });
      
      // Handle result
      if (result?.action is AdaptyUIActionPurchase) {
        final purchaseAction = result!.action as AdaptyUIActionPurchase;
        return await _handlePurchase(purchaseAction.product);
      }
      
      return false;
      
    } catch (e) {
      _logger.error('Failed to present paywall: $e');
      
      // Track error
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'paywall_error': e.toString(),
        'placement_id': placementId,
      });
      
      return false;
    }
  }

  /// Handle purchase transaction
  Future<bool> _handlePurchase(AdaptyPaywallProduct product) async {
    try {
      _logger.info('Processing purchase for product: ${product.vendorProductId}');
      
      // Make purchase
      final result = await Adapty().makePurchase(product: product);
      
      if (result.profile.accessLevels['premium']?.isActive == true) {
        _logger.info('Purchase successful - premium access granted');
        
        // Track successful purchase
        _analytics.event(AnalyticsEvents.noteCreate, properties: {
          'purchase_successful': true,
          'product_id': product.vendorProductId,
          'premium_granted': true,
        });
        
        return true;
      } else {
        _logger.warning('Purchase completed but premium access not granted');
        return false;
      }
      
    } catch (e) {
      _logger.error('Purchase failed: $e');
      
      // Track purchase failure
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'purchase_failed': true,
        'product_id': product.vendorProductId,
        'error': e.toString(),
      });
      
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    try {
      _logger.info('Restoring purchases...');
      
      final profile = await Adapty().restorePurchases();
      
      final hasAccess = profile.accessLevels['premium']?.isActive ?? false;
      
      _logger.info('Purchases restored - premium access: $hasAccess');
      
      // Track restore
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'purchases_restored': true,
        'premium_access_restored': hasAccess,
      });
      
      return hasAccess;
      
    } catch (e) {
      _logger.error('Failed to restore purchases: $e');
      
      // Track restore failure
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'restore_failed': true,
        'error': e.toString(),
      });
      
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
      
      if (paywall == null) {
        _logger.warning('No paywall found for placement: $placementId');
        return [];
      }
      
      final products = paywall.products;
      
      _logger.info('Retrieved ${products.length} products for placement: $placementId');
      
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
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'user_identified': true,
        'user_id_provided': userId.isNotEmpty,
      });
      
    } catch (e) {
      _logger.error('Failed to identify user: $e');
    }
  }

  /// Set user attributes for segmentation
  Future<void> setUserAttributes(Map<String, String> attributes) async {
    try {
      final builder = AdaptyProfileParametersBuilder();
      
      // Add custom attributes
      attributes.forEach((key, value) {
        builder.setCustomAttribute(key, value);
      });
      
      await Adapty().updateProfile(builder.build());
      
      _logger.info('User attributes updated: ${attributes.keys.join(', ')}');
      
      // Track attribute update
      _analytics.event(AnalyticsEvents.noteCreate, properties: {
        'user_attributes_updated': true,
        'attributes_count': attributes.length,
      });
      
    } catch (e) {
      _logger.error('Failed to set user attributes: $e');
    }
  }

  /// Check for promotional offers
  Future<List<AdaptyPaywallProduct>> getPromotionalOffers(String placementId) async {
    try {
      final products = await getProducts(placementId);
      
      // Filter products with promotional offers
      final promotionalProducts = products.where(
        (product) => product.subscriptionOffer != null
      ).toList();
      
      _logger.info('Found ${promotionalProducts.length} promotional offers');
      
      return promotionalProducts;
      
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
  return await subscriptionService.hasPremiumAccess();
});

/// Provider for user subscription profile
final userProfileProvider = FutureProvider<AdaptyProfile?>((ref) async {
  final subscriptionService = ref.read(subscriptionServiceProvider);
  return await subscriptionService.getUserProfile();
});
