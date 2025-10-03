import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/cross_platform_tokens.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: DuruColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.chat_bubble_text,
              color: Colors.white,
            ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Hero Section with Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DuruColors.primary.withValues(alpha: isDark ? 0.3 : 0.1),
                DuruColors.accent.withValues(alpha: isDark ? 0.2 : 0.05),
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                CupertinoIcons.question_circle_fill,
                size: 64,
                color: DuruColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'How can we help you?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Find answers, contact support, or learn about features',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Quick actions bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildModernActionCard(
                  icon: CupertinoIcons.search,
                  label: 'Search Guide',
                  color: DuruColors.primary,
                  onTap: _showSearchDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModernActionCard(
                  icon: CupertinoIcons.chat_bubble_2,
                  label: 'Contact Support',
                  color: DuruColors.accent,
                  onTap: _showContactSupport,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModernActionCard(
                  icon: CupertinoIcons.info_circle,
                  label: 'App Info',
                  color: const Color(0xFF9333EA), // AI Purple
                  onTap: _showAppInfo,
                ),
              ),
            ],
          ),
        ),
        // User guide content with modern styling
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Markdown(
                data: _userGuideContent,
                padding: const EdgeInsets.all(16),
                onTapLink: (text, href, title) {
                  if (href != null) {
                    _launchUrl(href);
                  }
                },
                styleSheet: MarkdownStyleSheet(
              h1: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DuruColors.primary,
                  ),
              h2: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              h3: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
              p: theme.textTheme.bodyMedium?.copyWith(
                color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.8),
              ),
              code: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: DuruColors.primary.withValues(alpha: 0.1),
                color: DuruColors.primary,
              ),
              codeblockDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.primary.withValues(alpha: 0.05),
                    DuruColors.accent.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: DuruColors.primary.withValues(alpha: 0.2),
                ),
              ),
              blockquoteDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.accent.withValues(alpha: 0.05),
                    DuruColors.accent.withValues(alpha: 0.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: DuruColors.accent,
                    width: 4,
                  ),
                ),
              ),
              listBullet: theme.textTheme.bodyMedium?.copyWith(
                color: DuruColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            selectable: true,
          ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
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
    showDialog<void>(
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
              onTap: () => _launchUrl(
                'mailto:support@durunotes.com?subject=Duru Notes Support Request',
              ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DuruColors.primary.withValues(alpha: 0.05),
            DuruColors.accent.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : DuruColors.primary).withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DuruColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: DuruColors.primary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          CupertinoIcons.chevron_forward,
          size: 16,
          color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.5),
        ),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showAppInfo() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [DuruColors.primary, DuruColors.accent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.app_badge,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('App Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.primary.withValues(alpha: 0.1),
                    DuruColors.accent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duru Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: DuruColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version: 1.0.0 • Build: 100',
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Features',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildFeaturesList(context),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Crafted for productivity excellence',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: DuruColors.accent,
                ),
              ),
            ),
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
    showModalBottomSheet<void>(
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

    showDialog<void>(
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
                    DropdownMenuItem(
                      value: 'Bug Report',
                      child: Text('Bug Report'),
                    ),
                    DropdownMenuItem(
                      value: 'Feature Request',
                      child: Text('Feature Request'),
                    ),
                    DropdownMenuItem(
                      value: 'General Feedback',
                      child: Text('General Feedback'),
                    ),
                    DropdownMenuItem(
                      value: 'Performance Issue',
                      child: Text('Performance Issue'),
                    ),
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

  List<Widget> _buildFeaturesList(BuildContext context) {
    final features = [
      {'icon': CupertinoIcons.bell, 'text': 'Advanced reminders'},
      {'icon': CupertinoIcons.mic, 'text': 'Voice transcription'},
      {'icon': CupertinoIcons.camera, 'text': 'OCR text scanning'},
      {'icon': CupertinoIcons.lock_shield, 'text': 'End-to-end encryption'},
      {'icon': CupertinoIcons.cloud_upload, 'text': 'Cross-platform sync'},
    ];

    return features.map((feature) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            feature['icon'] as IconData,
            size: 16,
            color: DuruColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            feature['text'] as String,
            style: TextStyle(
              color: (Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    )).toList();
  }

class _QuickHelpSection extends StatelessWidget {
  const _QuickHelpSection({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DuruColors.primary.withValues(alpha: 0.05),
            DuruColors.accent.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : DuruColors.primary).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DuruColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.lightbulb,
                  size: 16,
                  color: DuruColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: DuruColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                      color: DuruColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
