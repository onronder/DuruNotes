import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help screen that displays the user guide and support information
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _userGuideContent = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserGuide();
  }

  Future<void> _loadUserGuide() async {
    try {
      final content = await rootBundle.loadString('docs/UserGuide.md');
      if (mounted) {
        setState(() {
          _userGuideContent = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user guide: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & User Guide'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined),
            onPressed: _showFeedbackDialog,
            tooltip: 'Send Feedback',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading user guide...'),
                ],
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildHelpContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to Load Help Content',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _loadUserGuide();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _showQuickHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Quick Help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpContent() {
    return Column(
      children: [
        // Quick actions bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.search,
                  label: 'Search Guide',
                  onTap: _showSearchDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.support_agent,
                  label: 'Contact Support',
                  onTap: _showContactSupport,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.info_outline,
                  label: 'App Info',
                  onTap: _showAppInfo,
                ),
              ),
            ],
          ),
        ),
        // User guide content
        Expanded(
          child: Markdown(
            data: _userGuideContent,
            onTapLink: (text, href, title) {
              if (href != null) {
                _launchUrl(href);
              }
            },
            styleSheet: MarkdownStyleSheet(
              h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              h3: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              p: Theme.of(context).textTheme.bodyMedium,
              code: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
              codeblockDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              blockquoteDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            selectable: true,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search User Guide'),
        content: const Text(
          "Use your browser's search function (Ctrl+F or Cmd+F) to search through the guide, or scroll to find the section you need.\n\nMain sections:\n• Getting Started\n• Advanced Reminders\n• Voice & OCR Capture\n• Share Sheet Integration\n• Search & Organization\n• Security & Privacy\n• Troubleshooting",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showContactSupport() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contact Support',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildSupportOption(
              icon: Icons.email_outlined,
              title: 'Email Support',
              subtitle: 'Get help via email',
              onTap: () => _launchUrl('mailto:support@durunotes.com?subject=Duru Notes Support Request'),
            ),
            const SizedBox(height: 16),
            _buildSupportOption(
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              subtitle: 'Report issues or crashes',
              onTap: _showFeedbackDialog,
            ),
            const SizedBox(height: 16),
            _buildSupportOption(
              icon: Icons.public,
              title: 'Online FAQ',
              subtitle: 'Visit our help center',
              onTap: () => _launchUrl('https://durunotes.com/faq'),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Information'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Duru Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            Text('Build: 100'),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• Advanced reminders'),
            Text('• Voice transcription'),
            Text('• OCR text scanning'),
            Text('• End-to-end encryption'),
            Text('• Cross-platform sync'),
            SizedBox(height: 16),
            Text('Developed with ❤️ for productivity'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showQuickHelp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quick Help',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: const [
                    _QuickHelpSection(
                      title: 'Creating Notes',
                      items: [
                        'Tap + button to create a new note',
                        'Use block editor for different content types',
                        'Add voice notes with microphone button',
                        'Scan text with camera for OCR',
                      ],
                    ),
                    _QuickHelpSection(
                      title: 'Setting Reminders',
                      items: [
                        'Tap 🔔 icon in any note',
                        'Choose time-based or location-based',
                        'Set recurring patterns for repeated tasks',
                        'Use snooze to delay reminders',
                      ],
                    ),
                    _QuickHelpSection(
                      title: 'Common Issues',
                      items: [
                        'Notifications: Check app permissions',
                        'Location reminders: Enable location access',
                        'Voice issues: Check microphone permissions',
                        'Sync problems: Check internet connection',
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    var feedbackType = 'Bug Report';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Send Feedback'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Help us improve Duru Notes',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: feedbackType,
                  decoration: const InputDecoration(
                    labelText: 'Feedback Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Bug Report', child: Text('Bug Report')),
                    DropdownMenuItem(value: 'Feature Request', child: Text('Feature Request')),
                    DropdownMenuItem(value: 'General Feedback', child: Text('General Feedback')),
                    DropdownMenuItem(value: 'Performance Issue', child: Text('Performance Issue')),
                  ],
                  onChanged: (value) => setState(() => feedbackType = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: 'Your feedback',
                    hintText: 'Please describe your issue or suggestion...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final feedback = feedbackController.text.trim();
                if (feedback.isNotEmpty) {
                  Navigator.of(context).pop();
                  _sendFeedback(feedbackType, feedback);
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  void _sendFeedback(String type, String feedback) {
    final subject = Uri.encodeComponent('Duru Notes - $type');
    final body = Uri.encodeComponent(
      'Feedback Type: $type\n\n'
      'Description:\n$feedback\n\n'
      '--- Technical Information ---\n'
      'App Version: 1.0.0\n'
      'Platform: ${Theme.of(context).platform.name}\n'
      'Timestamp: ${DateTime.now().toIso8601String()}',
    );

    _launchUrl('mailto:support@durunotes.com?subject=$subject&body=$body');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening email app...'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _QuickHelpSection extends StatelessWidget {

  const _QuickHelpSection({
    required this.title,
    required this.items,
  });
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 8),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
