import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/subscription_service.dart';
import '../../theme/material3_theme.dart';

/// Widget that gates premium features behind subscription
class PremiumGateWidget extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final String placementId;
  final Widget? fallbackWidget;
  
  const PremiumGateWidget({
    super.key,
    required this.child,
    required this.featureName,
    this.placementId = 'premium_features',
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumAccess = ref.watch(premiumAccessProvider);
    
    return premiumAccess.when(
      data: (hasPremium) {
        if (hasPremium) {
          return child; // Show premium feature
        } else {
          return fallbackWidget ?? _buildUpgradePrompt(context, ref);
        }
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) {
        // On error, show upgrade prompt (fail-safe)
        return fallbackWidget ?? _buildUpgradePrompt(context, ref);
      },
    );
  }

  Widget _buildUpgradePrompt(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.1),
            theme.colorScheme.secondaryContainer.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Premium Feature',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$featureName requires a premium subscription',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => _restorePurchases(context, ref),
                child: const Text('Restore'),
              ),
              ElevatedButton.icon(
                onPressed: () => _showPaywall(context, ref),
                icon: const Icon(Icons.upgrade),
                label: const Text('Upgrade'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPaywall(BuildContext context, WidgetRef ref) async {
    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      
      final success = await subscriptionService.presentPaywall(
        placementId: placementId,
        context: context,
      );
      
      if (success) {
        // Refresh premium access status
        ref.invalidate(premiumAccessProvider);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome to Premium! Enjoy $featureName'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load subscription options: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      
      final success = await subscriptionService.restorePurchases();
      
      if (success) {
        // Refresh premium access status
        ref.invalidate(premiumAccessProvider);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Purchases restored successfully!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No purchases found to restore'),
            ),
          );
        }
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore purchases: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

/// Simple premium feature checker
class PremiumFeatureChecker extends ConsumerWidget {
  final Widget Function(bool hasPremium) builder;
  
  const PremiumFeatureChecker({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumAccess = ref.watch(premiumAccessProvider);
    
    return premiumAccess.when(
      data: (hasPremium) => builder(hasPremium),
      loading: () => builder(false), // Default to free during loading
      error: (_, __) => builder(false), // Default to free on error
    );
  }
}
