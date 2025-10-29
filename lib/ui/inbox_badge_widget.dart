import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show unifiedRealtimeServiceProvider;
import 'package:duru_notes/services/providers/services_providers.dart'
    show inboxUnreadServiceProvider;
import 'package:duru_notes/ui/inbound_email_inbox_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Inbox button with realtime badge counter
class InboxBadgeWidget extends ConsumerStatefulWidget {
  const InboxBadgeWidget({super.key});

  @override
  ConsumerState<InboxBadgeWidget> createState() => _InboxBadgeWidgetState();
}

class _InboxBadgeWidgetState extends ConsumerState<InboxBadgeWidget> {
  AppLogger get _logger => ref.read(loggerProvider);

  @override
  void initState() {
    super.initState();
    // Ensure services are initialized on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  void _initializeServices() {
    try {
      // Force initialization of unified realtime service
      final realtime = ref.read(unifiedRealtimeServiceProvider);
      _logger.debug(
        'Unified realtime service initialized for inbox badge',
        data: {'isSubscribed': realtime?.isSubscribed},
      );

      // Force initialization of unread service
      final unreadService = ref.read(inboxUnreadServiceProvider);
      unawaited(unreadService?.computeBadgeCount());
      _logger.debug('Inbox unread service initialized');
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to initialize inbox badge services',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Watch for changes in unread count
    var unreadCount = 0;
    try {
      final unreadService = ref.watch(inboxUnreadServiceProvider);
      unreadCount = unreadService?.unreadCount ?? 0;
      _logger.debug(
        'Inbox unread count updated',
        data: {'unreadCount': unreadCount},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to read inbox unread count',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }

    // Also watch unified realtime service to ensure it's active
    try {
      final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);
      final isSubscribed = unifiedRealtime?.isSubscribed ?? false;
      _logger.debug(
        'Unified realtime subscription status updated',
        data: {'isSubscribed': isSubscribed},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Unified realtime service unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.inbox_rounded),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const InboundEmailInboxWidget(),
              ),
            );

            // Check if widget is still mounted before using context or ref
            if (!mounted) return;

            // Update badge count after returning
            try {
              final unreadService = ref.read(inboxUnreadServiceProvider);
              await unreadService?.computeBadgeCount();
            } catch (error, stackTrace) {
              _logger.error(
                'Failed to refresh inbox badge count after inbox visit',
                error: error,
                stackTrace: stackTrace,
              );
              unawaited(Sentry.captureException(error, stackTrace: stackTrace));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Unable to refresh inbox count.'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    action: SnackBarAction(
                      label: 'Retry',
                      onPressed: () {
                        final service = ref.read(inboxUnreadServiceProvider);
                        if (service != null) {
                          unawaited(service.computeBadgeCount());
                        }
                      },
                    ),
                  ),
                );
              }
            }
          },
          tooltip: 'Inbox',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
