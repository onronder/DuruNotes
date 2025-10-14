import 'dart:async';

import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Widget that gates premium features behind subscription
class PremiumGateWidget extends ConsumerWidget {
  const PremiumGateWidget({
    required this.child,
    required this.featureName,
    super.key,
    this.placementId = 'premium_features',
    this.fallbackWidget,
  });
  final Widget child;
  final String featureName;
  final String placementId;
  final Widget? fallbackWidget;

  void _showErrorSnack(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: onRetry != null
            ? SnackBarAction(label: 'Retry', onPressed: onRetry)
            : null,
      ),
    );
  }

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
      loading: () => const Center(child: CircularProgressIndicator()),
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
            theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
      final logger = ref.read(loggerProvider);

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
        logger.info(
          'Premium paywall completed successfully',
          data: {'placementId': placementId, 'featureName': featureName},
        );
      } else {
        logger.warning(
          'Premium paywall dismissed or failed',
          data: {'placementId': placementId, 'featureName': featureName},
        );
      }
    } catch (error, stackTrace) {
      final logger = ref.read(loggerProvider);
      logger.error(
        'Failed to present premium paywall',
        error: error,
        stackTrace: stackTrace,
        data: {'placementId': placementId, 'featureName': featureName},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (context.mounted) {
        _showErrorSnack(
          context,
          'Unable to load subscription options. Please try again.',
          onRetry: () => unawaited(_showPaywall(context, ref)),
        );
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      final logger = ref.read(loggerProvider);

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
        logger.info(
          'Premium purchases restored',
          data: {'featureName': featureName},
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No purchases found to restore')),
          );
        }
        logger.warning(
          'No purchases found during restore',
          data: {'featureName': featureName},
        );
      }
    } catch (error, stackTrace) {
      final logger = ref.read(loggerProvider);
      logger.error(
        'Failed to restore purchases',
        error: error,
        stackTrace: stackTrace,
        data: {'featureName': featureName},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (context.mounted) {
        _showErrorSnack(
          context,
          'Failed to restore purchases. Please try again.',
          onRetry: () => unawaited(_restorePurchases(context, ref)),
        );
      }
    }
  }
}

/// Simple premium feature checker
class PremiumFeatureChecker extends ConsumerWidget {
  const PremiumFeatureChecker({required this.builder, super.key});
  final Widget Function(bool hasPremium) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumAccess = ref.watch(premiumAccessProvider);

    return premiumAccess.when(
      data: builder,
      loading: () => builder(false), // Default to free during loading
      error: (_, _) => builder(false), // Default to free on error
    );
  }
}
