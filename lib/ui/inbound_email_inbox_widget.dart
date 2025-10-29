import 'dart:async';
import 'package:duru_notes/domain/entities/note.dart' as domain;
import 'package:duru_notes/domain/entities/inbox_item.dart';
import 'package:duru_notes/infrastructure/providers/repository_providers.dart'
    show notesCoreRepositoryProvider;
import 'package:duru_notes/services/inbox_management_service.dart';
import 'package:duru_notes/services/providers/services_providers.dart'
    show inboxManagementServiceProvider, inboxUnreadServiceProvider;
import 'package:duru_notes/features/sync/providers/sync_providers.dart'
    show unifiedRealtimeServiceProvider;
import 'package:duru_notes/features/notes/providers/notes_pagination_providers.dart'
    show notesPageProvider;
import 'package:duru_notes/features/notes/providers/notes_providers.dart'
    show filteredNotesProvider;
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:duru_notes/ui/widgets/email_attachments_section.dart';
import 'package:duru_notes/ui/components/modern_app_bar.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/providers.dart' show loggerProvider;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Widget for displaying the unified inbox (email and web clips)
class InboundEmailInboxWidget extends ConsumerStatefulWidget {
  const InboundEmailInboxWidget({super.key});

  @override
  ConsumerState<InboundEmailInboxWidget> createState() =>
      _InboundEmailInboxWidgetState();
}

class _InboundEmailInboxWidgetState
    extends ConsumerState<InboundEmailInboxWidget> {
  late final InboxManagementService _inboxService;
  late final AppLogger _logger;
  List<InboxItem> _items = [];
  bool _isLoading = true;
  String? _userEmailAddress;
  StreamSubscription<DatabaseChangeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _inboxService = ref.read(inboxManagementServiceProvider);
    _logger = ref.read(loggerProvider);
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Subscribe to realtime updates for instant list refresh
      _subscribeToRealtime();
    });
  }

  void _subscribeToRealtime() {
    try {
      final unifiedRealtime = ref.read(unifiedRealtimeServiceProvider);
      if (unifiedRealtime != null) {
        _realtimeSubscription = unifiedRealtime.inboxStream.listen((event) {
          _logger.debug(
            'Inbox realtime event',
            data: {'eventType': event.eventType},
          );
          _loadData();
        });
      }
      _logger.debug('Subscribed to inbox realtime updates');
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to subscribe to inbox realtime updates',
        data: {'error': error.toString()},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // PRODUCTION FIX: Check mounted before setState to prevent disposed widget errors
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Load both email address and inbox items in parallel
      final results = await Future.wait([
        _inboxService.getUserInboundEmail(),
        _inboxService.listInboxItems(), // Unified inbox list
      ]);

      // PRODUCTION FIX: Check mounted before setState
      if (mounted) {
        setState(() {
          _userEmailAddress = results[0] as String?;
          _items = results[1]! as List<InboxItem>;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load inbox items',
        error: e,
        stackTrace: stackTrace,
        data: {'operation': '_loadData'},
      );
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));

      // PRODUCTION FIX: Check mounted before setState
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading inbox items. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => unawaited(_loadData()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _convertToNote(
    InboxItem item, {
    bool navigateToNote = true,
  }) async {
    final itemType = item.isEmail ? 'email' : 'web clip';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Note'),
        content: Text(
          'Convert "${item.displayTitle}" to a note?\n\n'
          'This will create a new note and remove the $itemType from your inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final unreadService = ref.read(inboxUnreadServiceProvider);
      unawaited(unreadService?.markItemViewed(item.id));
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to mark inbox item as read before conversion',
        data: {'itemId': item.id, 'error': error.toString()},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }

    // Show immediate feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Converting to note...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final result = await _inboxService.convertItemToNote(item);

    await result.when(
      success: (noteId) async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${item.isEmail ? "Email" : "Web clip"} converted to note successfully',
              ),
              backgroundColor: Colors.green,
              action: navigateToNote
                  ? SnackBarAction(
                      label: 'OPEN',
                      textColor: Colors.white,
                      onPressed: () => _navigateToNote(noteId),
                    )
                  : null,
            ),
          );

          // PRODUCTION FIX: Invalidate notes providers to show new note immediately
          // This ensures the notes list refreshes automatically when user navigates back
          try {
            debugPrint(
              '[InboxWidget] 📝 Invalidating notes providers after conversion',
            );
            ref.invalidate(notesPageProvider);
            ref.invalidate(filteredNotesProvider);
            debugPrint('[InboxWidget] ✅ Notes providers invalidated');
          } catch (error, stackTrace) {
            _logger.warning(
              'Failed to invalidate notes providers after conversion',
              data: {'noteId': noteId, 'error': error.toString()},
            );
            unawaited(Sentry.captureException(error, stackTrace: stackTrace));
          }

          // Update inbox badge count to reflect item removal
          try {
            final unreadService = ref.read(inboxUnreadServiceProvider);
            await unreadService?.computeBadgeCount();
            debugPrint('[InboxWidget] ✅ Badge count updated');
          } catch (error, stackTrace) {
            _logger.warning(
              'Failed to update inbox badge count',
              data: {'error': error.toString()},
            );
            unawaited(Sentry.captureException(error, stackTrace: stackTrace));
          }

          // Optionally navigate to the note immediately
          if (navigateToNote) {
            // Small delay to let the UI update
            await Future<void>.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              _navigateToNote(noteId);
            }
          } else {
            _loadData(); // Refresh the inbox list if not navigating
          }
        }
      },
      failure: (error) async {
        _logger.warning(
          'Failed to convert inbox item to note',
          data: {
            'itemId': item.id,
            'type': item.isEmail ? 'email' : 'web clip',
            'error': error.userMessage,
          },
        );
        unawaited(Sentry.captureException(error));
        if (mounted) {
          // Show user-friendly error message
          final message = error.userMessage;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  Future<void> _navigateToNote(String noteId) async {
    try {
      // Get the note details for navigation
      final notesRepo = ref.read(notesCoreRepositoryProvider);
      final domain.Note? note = await notesRepo.getNoteById(noteId);

      if (note != null && mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => ModernEditNoteScreen(
              noteId: note.id,
              initialTitle: note.title,
              initialBody: note.body,
            ),
          ),
        );

        // Refresh the list when returning from the note
        _loadData();
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to navigate to note',
        error: e,
        stackTrace: stackTrace,
        data: {'noteId': noteId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open note. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(InboxItem item) async {
    final itemType = item.isEmail ? 'Email' : 'Web Clip';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemType'),
        content: Text('Delete "${item.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final unreadService = ref.read(inboxUnreadServiceProvider);
      unawaited(unreadService?.markItemViewed(item.id));
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to mark inbox item as read before deletion',
        data: {'itemId': item.id, 'error': error.toString()},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }

    final result = await _inboxService.deleteInboxItem(item.id);
    if (result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$itemType deleted')));
      }
      _loadData(); // Refresh the list
      _logger.info(
        'Inbox item deleted',
        data: {'itemId': item.id, 'type': itemType},
      );
    }
  }

  void _showItemDetails(InboxItem item) {
    try {
      final unreadService = ref.read(inboxUnreadServiceProvider);
      unawaited(unreadService?.markItemViewed(item.id));
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to mark inbox item as viewed',
        data: {'itemId': item.id, 'error': error.toString()},
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => InboxItemDetailSheet(
        item: item,
        inboxService: _inboxService,
        onConvert: () {
          Navigator.of(context).pop();
          _convertToNote(item);
        },
        onDelete: () {
          Navigator.of(context).pop();
          _deleteItem(item);
        },
      ),
    );
  }

  void _copyEmailAddress() {
    if (_userEmailAddress != null) {
      Clipboard.setData(ClipboardData(text: _userEmailAddress!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email address copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Inbox',
        actions: [
          ModernAppBarAction(
            icon: CupertinoIcons.refresh,
            onPressed: _loadData,
            tooltip: 'Refresh inbox',
          ),
        ],
      ),
      body: Column(
        children: [
          // User's email address card
          if (_userEmailAddress != null)
            Container(
              margin: EdgeInsets.all(DuruSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.primary.withValues(alpha: 0.05),
                    DuruColors.accent.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(DuruSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.envelope_fill,
                          size: 16,
                          color: DuruColors.primary,
                        ),
                        SizedBox(width: DuruSpacing.sm),
                        Text(
                          'Forward emails or use with Web Clipper:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: DuruSpacing.sm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DuruSpacing.sm,
                        vertical: DuruSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _userEmailAddress!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                color: DuruColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.doc_on_clipboard,
                              size: 20,
                              color: DuruColors.primary,
                            ),
                            onPressed: _copyEmailAddress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Email list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.tray,
                          size: 64,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        SizedBox(height: DuruSpacing.md),
                        Text(
                          'Your inbox is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: DuruSpacing.sm),
                        if (_userEmailAddress != null)
                          Text(
                            'Send emails to:\n$_userEmailAddress\n\nOr use the Web Clipper extension',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Dismissible(
                          key: Key(item.id),
                          background: Container(
                            color: Colors.green,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: const Icon(
                              Icons.note_add,
                              color: Colors.white,
                            ),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              await _convertToNote(item);
                              return false; // Don't dismiss, we'll refresh
                            } else {
                              await _deleteItem(item);
                              return false; // Don't dismiss, we'll refresh
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: DuruSpacing.md,
                              vertical: DuruSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(DuruSpacing.sm),
                              leading: Container(
                                padding: EdgeInsets.all(DuruSpacing.sm),
                                decoration: BoxDecoration(
                                  color: item.isWebClip
                                      ? DuruColors.accent.withValues(alpha: 0.1)
                                      : DuruColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: item.isWebClip
                                    ? Icon(
                                        CupertinoIcons.globe,
                                        color: DuruColors.accent,
                                        size: 20,
                                      )
                                    : Icon(
                                        CupertinoIcons.envelope_fill,
                                        color: DuruColors.primary,
                                        size: 20,
                                      ),
                              ),
                              title: Text(
                                item.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displaySubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.displayText != null)
                                    Text(
                                      item.displayText!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (item.hasAttachments)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        right: DuruSpacing.xs,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.paperclip,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  SizedBox(width: DuruSpacing.xs),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DuruSpacing.sm,
                                      vertical: DuruSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _formatDate(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => _showItemDetails(item),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class InboxItemDetailSheet extends StatefulWidget {
  const InboxItemDetailSheet({
    required this.item,
    required this.inboxService,
    required this.onConvert,
    required this.onDelete,
    super.key,
  });
  final InboxItem item;
  final InboxManagementService inboxService;
  final VoidCallback onConvert;
  final VoidCallback onDelete;

  @override
  State<InboxItemDetailSheet> createState() => _InboxItemDetailSheetState();
}

class _InboxItemDetailSheetState extends State<InboxItemDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final attachments = widget.item.isEmail
        ? widget.inboxService.getAttachments(widget.item)
        : <EmailAttachment>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  widget.item.displayTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Source-specific details
                if (widget.item.isEmail) ...[
                  // From
                  Row(
                    children: [
                      const Text(
                        'From: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          widget.item.from ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // To
                  Row(
                    children: [
                      const Text(
                        'To: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          widget.item.to ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                if (widget.item.isWebClip) ...[
                  // URL
                  Row(
                    children: [
                      const Text(
                        'Source: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Text(
                          widget.item.webUrl ?? 'Unknown',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Date
                Row(
                  children: [
                    Text(
                      widget.item.isWebClip ? 'Clipped: ' : 'Date: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(widget.item.createdAt.toLocal().toString()),
                  ],
                ),
                const SizedBox(height: 16),

                // Attachments - Use EmailAttachmentsSection widget
                if (attachments.isNotEmpty) ...[
                  const Text(
                    'Attachments:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  EmailAttachmentsSection(
                    files: attachments.map((a) {
                      // Convert EmailAttachment to EmailAttachmentRef
                      // CRITICAL FIX: Pass URL and expiry from backend
                      final path = a.storagePath ?? '';
                      return EmailAttachmentRef(
                        path: path,
                        filename: a.filename,
                        mimeType: a.contentType,
                        sizeBytes: a.size,
                        url: a.url, // Pre-signed URL from backend
                        urlExpiresAt: a.urlExpiresAt, // Expiration timestamp
                      );
                    }).toList(),
                    bucketId: 'inbound-attachments-temp',
                    signedUrlTtlSeconds: 86400, // 24 hours for regenerated URLs
                  ),
                  const SizedBox(height: 16),
                ],

                // Body
                const Text(
                  'Content:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Note: Removed Expanded to fix "unbounded height" error in SingleChildScrollView
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.item.displayText ??
                        widget.item.html ??
                        '(no content)',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onConvert,
                        icon: const Icon(Icons.note_add),
                        label: const Text('Convert to Note'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
