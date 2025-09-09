import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/inbound_email_service.dart';

class InboundEmailInboxWidget extends StatefulWidget {
  const InboundEmailInboxWidget({Key? key}) : super(key: key);

  @override
  State<InboundEmailInboxWidget> createState() => _InboundEmailInboxWidgetState();
}

class _InboundEmailInboxWidgetState extends State<InboundEmailInboxWidget> {
  late final InboundEmailService _emailService;
  List<InboundEmail> _emails = [];
  bool _isLoading = true;
  String? _userEmailAddress;
  
  @override
  void initState() {
    super.initState();
    _emailService = InboundEmailService(Supabase.instance.client);
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load both email address and inbox items in parallel
      final results = await Future.wait([
        _emailService.getUserInboundEmail(),
        _emailService.getInboundEmails(),
      ]);
      
      setState(() {
        _userEmailAddress = results[0] as String?;
        _emails = results[1] as List<InboundEmail>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading emails: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _convertToNote(InboundEmail email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Note'),
        content: Text(
          'Convert "${email.subject ?? "Untitled"}" to a note?\n\n'
          'This will create a new note and remove the email from your inbox.',
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
    
    final noteId = await _emailService.convertEmailToNote(email);
    if (noteId != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email converted to note successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData(); // Refresh the list
    }
  }
  
  Future<void> _deleteEmail(InboundEmail email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Email'),
        content: Text('Delete "${email.subject ?? "Untitled"}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    final success = await _emailService.deleteInboundEmail(email.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email deleted')),
        );
      }
      _loadData(); // Refresh the list
    }
  }
  
  void _showEmailDetails(InboundEmail email) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EmailDetailSheet(
        email: email,
        emailService: _emailService,
        onConvert: () {
          Navigator.of(context).pop();
          _convertToNote(email);
        },
        onDelete: () {
          Navigator.of(context).pop();
          _deleteEmail(email);
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
        title: const Text('Email Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
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
                      'Forward emails to:',
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
                : _emails.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'No emails yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            if (_userEmailAddress != null)
                              Text(
                                'Send an email to\n$_userEmailAddress',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          itemCount: _emails.length,
                          itemBuilder: (context, index) {
                            final email = _emails[index];
                            return Dismissible(
                              key: Key(email.id),
                              background: Container(
                                color: Colors.green,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 16),
                                child: const Icon(Icons.note_add, color: Colors.white),
                              ),
                              secondaryBackground: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  await _convertToNote(email);
                                  return false; // Don't dismiss, we'll refresh
                                } else {
                                  await _deleteEmail(email);
                                  return false; // Don't dismiss, we'll refresh
                                }
                              },
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    (email.from?.substring(0, 1) ?? '?').toUpperCase(),
                                  ),
                                ),
                                title: Text(
                                  email.subject ?? '(no subject)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      email.from ?? 'Unknown sender',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (email.text != null)
                                      Text(
                                        email.text!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (email.hasAttachments)
                                      Icon(
                                        Icons.attach_file,
                                        size: 20,
                                        color: Colors.grey[600],
                                      ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(email.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _showEmailDetails(email),
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

class EmailDetailSheet extends StatelessWidget {
  final InboundEmail email;
  final InboundEmailService emailService;
  final VoidCallback onConvert;
  final VoidCallback onDelete;
  
  const EmailDetailSheet({
    Key? key,
    required this.email,
    required this.emailService,
    required this.onConvert,
    required this.onDelete,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final attachments = emailService.getAttachments(email);
    
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
              
              // Subject
              Text(
                email.subject ?? '(no subject)',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // From
              Row(
                children: [
                  const Text('From: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      email.from ?? 'Unknown',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // To
              Row(
                children: [
                  const Text('To: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      email.to ?? 'Unknown',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Date
              Row(
                children: [
                  const Text('Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(email.createdAt.toLocal().toString()),
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
                ...attachments.map((attachment) => ListTile(
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
                          content: Text('Attachment viewing not yet implemented'),
                        ),
                      );
                    }
                  },
                )),
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
                      email.text ?? email.html ?? '(no content)',
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
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
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
