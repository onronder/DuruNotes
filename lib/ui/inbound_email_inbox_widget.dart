import 'dart:async';

import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/inbox_management_service.dart';
import 'package:duru_notes/services/unified_realtime_service.dart';
import 'package:duru_notes/ui/modern_edit_note_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  List<InboxItem> _items = [];
  bool _isLoading = true;
  String? _userEmailAddress;
  StreamSubscription<DatabaseChangeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    _inboxService = ref.read(inboxManagementServiceProvider);
    _loadData();

    // Mark inbox as viewed to reset unread counter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final unreadService = ref.read(inboxUnreadServiceProvider);
        unreadService?.markInboxViewed();
      } catch (e) {
        // Unread service might not be available
        debugPrint('Could not mark inbox as viewed: $e');
      }

      // Subscribe to realtime updates for instant list refresh
      _subscribeToRealtime();
    });
  }

  void _subscribeToRealtime() {
    try {
      final unifiedRealtime = ref.read(unifiedRealtimeServiceProvider);
      if (unifiedRealtime != null) {
        _realtimeSubscription = unifiedRealtime.inboxStream.listen((event) {
          debugPrint(
            '[InboxWidget] Unified realtime event received: ${event.eventType}',
          );
          // Refresh the list when items are added or deleted
          _loadData();
        });
      }
      debugPrint('[InboxWidget] Subscribed to realtime updates');
    } catch (e) {
      debugPrint('[InboxWidget] Could not subscribe to realtime: $e');
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load both email address and inbox items in parallel
      final results = await Future.wait([
        _inboxService.getUserInboundEmail(),
        _inboxService.listInboxItems(), // Unified inbox list
      ]);

      setState(() {
        _userEmailAddress = results[0] as String?;
        _items = results[1]! as List<InboxItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading inbox items: $e'),
            backgroundColor: Colors.red,
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

          // Optionally navigate to the note immediately
          if (navigateToNote) {
            // Small delay to let the UI update
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              _navigateToNote(noteId);
            }
          } else {
            _loadData(); // Refresh the list if not navigating
          }
        }
      },
      failure: (error) async {
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
      final notesRepo = ref.read(notesRepositoryProvider);
      final note = await notesRepo.getNote(noteId);

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
    } catch (e) {
      debugPrint('[InboxWidget] Error navigating to note: $e');
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

    final result = await _inboxService.deleteInboxItem(item.id);
    if (result.isSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$itemType deleted')));
      }
      _loadData(); // Refresh the list
    }
  }

  void _showItemDetails(InboxItem item) {
    showModalBottomSheet(
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
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // User's email address card
          if (_userEmailAddress != null)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Forward emails or use with Web Clipper:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _userEmailAddress!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: _copyEmailAddress,
                        ),
                      ],
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
                            const Icon(Icons.inbox,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Your inbox is empty',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (_userEmailAddress != null)
                              Text(
                                '📧 Send emails to:\n$_userEmailAddress\n\n🌐 Or use the Web Clipper extension',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
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
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: item.isWebClip
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                                  child: item.isWebClip
                                      ? Icon(
                                          Icons.language,
                                          color: Colors.blue.shade700,
                                        )
                                      : Icon(
                                          Icons.email,
                                          color: Colors.grey.shade700,
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
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.attach_file,
                                          size: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(item.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _showItemDetails(item),
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

class InboxItemDetailSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final attachments =
        item.isEmail ? inboxService.getAttachments(item) : <EmailAttachment>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                item.displayTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Source-specific details
              if (item.isEmail) ...[
                // From
                Row(
                  children: [
                    const Text(
                      'From: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        item.from ?? 'Unknown',
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
                        item.to ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              if (item.isWebClip) ...[
                // URL
                Row(
                  children: [
                    const Text(
                      'Source: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        item.webUrl ?? 'Unknown',
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
                    item.isWebClip ? 'Clipped: ' : 'Date: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(item.createdAt.toLocal().toString()),
                ],
              ),
              const SizedBox(height: 16),

              // Attachments
              if (attachments.isNotEmpty) ...[
                const Text(
                  'Attachments:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Limit height of attachments list to prevent overflow
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: attachments.length > 3
                        ? 200
                        : attachments.length * 70.0,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: attachments.length > 3
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    itemCount: attachments.length,
                    itemBuilder: (context, index) {
                      final attachment = attachments[index];
                      return ListTile(
                        leading: const Icon(Icons.attachment),
                        title: Text(attachment.filename),
                        subtitle: Text(attachment.sizeFormatted),
                        dense: true,
                        onTap: () async {
                          // Get signed URL and open attachment
                          if (attachment.url != null) {
                            // TODO: Implement attachment viewing
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Attachment viewing not yet implemented',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Body
              const Text(
                'Content:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.displayText ?? item.html ?? '(no content)',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
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
                      onPressed: onConvert,
                      icon: const Icon(Icons.note_add),
                      label: const Text('Convert to Note'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
