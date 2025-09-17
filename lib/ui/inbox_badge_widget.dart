import 'package:duru_notes/providers.dart';
import 'package:duru_notes/ui/inbound_email_inbox_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Inbox button with realtime badge counter
class InboxBadgeWidget extends ConsumerStatefulWidget {
  const InboxBadgeWidget({super.key});

  @override
  ConsumerState<InboxBadgeWidget> createState() => _InboxBadgeWidgetState();
}

class _InboxBadgeWidgetState extends ConsumerState<InboxBadgeWidget> {
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
      ref.read(unifiedRealtimeServiceProvider);
      debugPrint('[InboxBadge] Unified realtime service initialized');

      // Force initialization of unread service
      final unreadService = ref.read(inboxUnreadServiceProvider);
      unreadService?.computeBadgeCount();
      debugPrint('[InboxBadge] Unread service initialized');
    } catch (e) {
      debugPrint('[InboxBadge] Error initializing services: $e');
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
      debugPrint('[InboxBadge] Current unread count: $unreadCount');
    } catch (e) {
      debugPrint('[InboxBadge] Error getting unread count: $e');
    }

    // Also watch unified realtime service to ensure it's active
    try {
      final unifiedRealtime = ref.watch(unifiedRealtimeServiceProvider);
      final isSubscribed = unifiedRealtime?.isSubscribed ?? false;
      debugPrint('[InboxBadge] Unified realtime subscribed: $isSubscribed');
    } catch (e) {
      debugPrint('[InboxBadge] Unified realtime service not available: $e');
    }

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.inbox_rounded),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const InboundEmailInboxWidget(),
              ),
            );
            // Update badge count after returning
            try {
              final unreadService = ref.read(inboxUnreadServiceProvider);
              await unreadService?.computeBadgeCount();
            } catch (_) {}
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
