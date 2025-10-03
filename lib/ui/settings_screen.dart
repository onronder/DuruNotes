import 'package:duru_notes/core/settings/locale_notifier.dart';
import 'package:duru_notes/core/settings/sync_mode.dart';
import 'package:duru_notes/core/ui/responsive.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/export_service.dart';
import 'package:duru_notes/ui/components/ios_style_toggle.dart';
import 'package:duru_notes/ui/components/modern_app_bar.dart';
import 'package:duru_notes/ui/help_screen.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Comprehensive settings screen for Duru Notes
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _emailInAddress;
  bool _isLoadingEmail = false;
  PackageInfo? _packageInfo;
  bool _isSyncing = false;

  Future<void> _exportAllFromSettings(ExportFormat format) async {
    final svc = ref.read(exportServiceProvider);
    final logger = ref.read(loggerProvider);
    try {
      // Reuse existing export flow from notes screen to maintain consistency
      final notes = ref.read(currentNotesProvider);
      if (notes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No notes to export')));
        }
        return;
      }

      // Export the latest note for quick share from settings to keep UX simple
      final note = notes.first;
      switch (format) {
        case ExportFormat.markdown:
          final res = await svc.exportToMarkdown(note);
          if (res.success && res.file != null && mounted) {
            await svc.shareFile(res.file!, format);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Exported as Markdown')),
            );
          }
        case ExportFormat.pdf:
          final res = await svc.exportToPdf(note);
          if (res.success && res.file != null && mounted) {
            await svc.shareFile(res.file!, format);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Exported as PDF')));
          }
        case ExportFormat.html:
          final res = await svc.exportToHtml(note);
          if (res.success && res.file != null && mounted) {
            await svc.shareFile(res.file!, format);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Exported as HTML')));
          }
        case ExportFormat.docx:
        case ExportFormat.txt:
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Export format ${format.displayName} not supported yet',
                ),
              ),
            );
          }
      }
    } catch (e, st) {
      logger.error('Settings export failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadEmailAddress();
  }

  Future<void> _loadEmailAddress() async {
    setState(() => _isLoadingEmail = true);
    try {
      // Use the provider to get the EmailAliasService
      final aliasService = ref.read(emailAliasServiceProvider);

      // Debug: Check if dotenv is loaded
      debugPrint('[Settings] Checking dotenv status...');
      debugPrint(
        '[Settings] INBOUND_EMAIL_DOMAIN from env: ${dotenv.env['INBOUND_EMAIL_DOMAIN']}',
      );

      final address = await aliasService.getFullEmailAddress();
      debugPrint('[Settings] Loaded email address: $address');

      // Validate the domain is correct
      if (address != null && !address.endsWith('@in.durunotes.app')) {
        debugPrint('[Settings] WARNING: Email address has wrong domain!');
        debugPrint('[Settings] Expected: @in.durunotes.app');
        debugPrint('[Settings] Got: $address');
      }

      if (mounted) {
        setState(() {
          _emailInAddress = address;
          _isLoadingEmail = false;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Error loading email address: $e');
      if (mounted) {
        setState(() => _isLoadingEmail = false);
      }
    }
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = packageInfo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0A0A0A)
          : const Color(0xFFF8FAFB),
      appBar: ModernAppBar(
        title: l10n.settingsTitle,
        subtitle: 'Customize your experience',
        showGradient: true,
        actions: [
          ModernAppBarAction(
            icon: CupertinoIcons.question_circle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
            ),
            tooltip: 'Help',
          ),
        ],
      ),
      body: AppBreakpoints.clampControlsTextScale(
        context: context,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header section with user info
              _buildHeaderSection(context, l10n),

              // Settings sections with cards
              Padding(
                padding: AppBreakpoints.screenPadding(context),
                child: Column(
                  children: [
                    _buildAccountSection(context, l10n),
                    _buildEmailInSection(context, l10n),
                    _buildAISection(context, l10n),
                    _buildSyncSection(context, l10n),
                    _buildAppearanceSection(context, l10n),
                    _buildLanguageSection(context, l10n),
                    _buildNotificationsSection(context, l10n),
                    _buildSecuritySectionWithIOSToggles(context, l10n),
                    _buildImportExportSection(context, l10n),
                    _buildHelpAboutSection(context, l10n),
                    const SizedBox(height: 32), // Bottom padding
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(DuruSpacing.md),
      padding: EdgeInsets.all(DuruSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DuruColors.primary.withValues(alpha: 0.05),
            DuruColors.accent.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // User avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [DuruColors.primary, DuruColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: isCompact ? 64 : 80,
              height: isCompact ? 64 : 80,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: user != null && user.userMetadata?['avatar_url'] != null
                  ? ClipOval(
                      child: Image.network(
                        user.userMetadata!['avatar_url'] as String,
                        width: isCompact ? 64 : 80,
                        height: isCompact ? 64 : 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          CupertinoIcons.person_fill,
                          size: isCompact ? 32 : 40,
                          color: DuruColors.primary,
                        ),
                      ),
                    )
                  : Icon(
                      CupertinoIcons.person_fill,
                      size: isCompact ? 32 : 40,
                      color: DuruColors.primary,
                    ),
            ),
          ),
          SizedBox(height: isCompact ? 12 : 16),

          // User info
          if (user != null) ...[
            Text(
              user.email ?? 'Unknown User',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isCompact ? 2 : 4),
            Text(
              'Signed in',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ] else ...[
            Text(
              'Not signed in',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
    bool useGradient = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      margin: EdgeInsets.only(bottom: DuruSpacing.md),
      decoration: BoxDecoration(
        gradient: useGradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (iconColor ?? DuruColors.primary).withValues(alpha: 0.05),
                  colorScheme.surface,
                ],
              )
            : null,
        color: useGradient ? null : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (iconColor ?? colorScheme.outline).withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(DuruSpacing.sm),
                      decoration: BoxDecoration(
                        color: (iconColor ?? DuruColors.primary).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: isCompact ? 18 : 20,
                        color: iconColor ?? DuruColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 12 : 16),
                // Section content
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: DuruSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: DuruColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildEmailInSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Email-In Address',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingEmail)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_emailInAddress != null) ...[
              // Email address display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _emailInAddress!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: _emailInAddress!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy to clipboard',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri(
                          scheme: 'mailto',
                          path: _emailInAddress,
                          query: 'subject=Test Note from DuruNotes',
                        );

                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open email client'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Send Test Email'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _loadEmailAddress,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Send any email to this address to create a note. '
                        'Attachments are preserved and notes are filed into Incoming Mail. '
                        'Your address is unique—treat it like a secret.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Error or not available
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Email-in address not available. Please try again later.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadEmailAddress,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAISection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // AI feature states (these would come from providers in production)
    bool aiEnabled = true;
    bool smartSuggestions = true;
    bool semanticSearch = false;
    bool onDeviceOnly = true;
    String selectedModel = 'Nano (50MB)';

    return _buildSectionCard(
      title: 'AI Assistant',
      icon: CupertinoIcons.sparkles,
      iconColor: const Color(0xFF9333EA), // AI Purple
      useGradient: true,
      children: [
        // AI Enable Toggle
        SwitchListTile(
          title: Text(
            'Enable AI Features',
            style: theme.textTheme.bodyLarge,
          ),
          subtitle: Text(
            'Smart suggestions and semantic search',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          value: aiEnabled,
          onChanged: (value) {
            // Toggle AI features
            HapticFeedback.lightImpact();
          },
          activeColor: const Color(0xFF9333EA),
        ),
        const Divider(height: 24),

        // Model Selection
        ListTile(
          title: Text(
            'AI Model',
            style: theme.textTheme.bodyLarge,
          ),
          subtitle: Text(
            selectedModel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(
              horizontal: DuruSpacing.sm,
              vertical: DuruSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.cloud_download,
                  size: 16,
                  color: const Color(0xFF9333EA),
                ),
                SizedBox(width: DuruSpacing.xs),
                Text(
                  'Change',
                  style: TextStyle(
                    color: const Color(0xFF9333EA),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          onTap: () {
            // Show model selection dialog
            HapticFeedback.lightImpact();
          },
        ),
        const Divider(height: 24),

        // Feature Toggles
        SwitchListTile(
          title: Text(
            'Smart Suggestions',
            style: theme.textTheme.bodyMedium,
          ),
          subtitle: Text(
            'AI-powered writing assistance',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          value: smartSuggestions,
          onChanged: aiEnabled ? (value) {
            HapticFeedback.lightImpact();
          } : null,
          activeColor: const Color(0xFF9333EA),
        ),

        SwitchListTile(
          title: Text(
            'Semantic Search',
            style: theme.textTheme.bodyMedium,
          ),
          subtitle: Text(
            'Find notes by meaning, not just keywords',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          value: semanticSearch,
          onChanged: aiEnabled ? (value) {
            HapticFeedback.lightImpact();
          } : null,
          activeColor: const Color(0xFF9333EA),
        ),
        const Divider(height: 24),

        // Privacy Control
        Container(
          padding: EdgeInsets.all(DuruSpacing.md),
          decoration: BoxDecoration(
            color: onDeviceOnly
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onDeviceOnly
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                onDeviceOnly
                  ? CupertinoIcons.lock_shield_fill
                  : CupertinoIcons.cloud,
                color: onDeviceOnly ? Colors.green : Colors.orange,
                size: 24,
              ),
              SizedBox(width: DuruSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      onDeviceOnly ? 'On-Device Processing' : 'Cloud Processing',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: DuruSpacing.xs),
                    Text(
                      onDeviceOnly
                        ? 'All AI processing happens locally on your device'
                        : 'Some features may use cloud processing',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: onDeviceOnly,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                },
                activeColor: Colors.green,
              ),
            ],
          ),
        ),

        // Learn More Link
        Padding(
          padding: EdgeInsets.only(top: DuruSpacing.md),
          child: InkWell(
            onTap: () {
              // Open AI features documentation
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 16,
                  color: const Color(0xFF9333EA),
                ),
                SizedBox(width: DuruSpacing.xs),
                Text(
                  'Learn more about AI features',
                  style: TextStyle(
                    color: const Color(0xFF9333EA),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, AppLocalizations l10n) {
    final user = Supabase.instance.client.auth.currentUser;
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.account),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (user != null) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      user.email?.substring(0, 1).toUpperCase() ?? 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    l10n.signedInAs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    user.email ?? 'Unknown',
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    Icons.verified_user,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isCompact ? 6 : 10,
                  ),
                  visualDensity:
                      isCompact ? const VisualDensity(vertical: -2) : null,
                  minLeadingWidth: 0,
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.signOut,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _showSignOutDialog(context, l10n),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncSection(BuildContext context, AppLocalizations l10n) {
    final syncMode = ref.watch(syncModeProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.sync),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(
                  l10n.syncMode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  syncMode.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              const Divider(height: 1),
              RadioListTile<SyncMode>(
                title: Text(
                  l10n.automaticSync,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.automaticSyncDesc,
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: SyncMode.automatic,
                groupValue: syncMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(syncModeProvider.notifier).setMode(mode);
                  }
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 0 : 4,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -3) : null,
              ),
              RadioListTile<SyncMode>(
                title: Text(
                  l10n.manualSync,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.manualSyncDesc,
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                value: SyncMode.manual,
                groupValue: syncMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(syncModeProvider.notifier).setMode(mode);
                  }
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 0 : 4,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -3) : null,
              ),
              if (syncMode == SyncMode.manual) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSyncing
                              ? null
                              : () => _performManualSync(l10n),
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_isSyncing ? l10n.syncing : l10n.syncNow),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Debug button for testing saved searches
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final db = ref.read(appDbProvider);
                            await db.debugMetadata();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Check console for debug output',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.bug_report),
                          label: const Text('Debug Saved Searches'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context, AppLocalizations l10n) {
    final themeMode = ref.watch(themeModeProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.appearance),
        Card(
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text(
                  l10n.lightTheme,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: ThemeMode.light,
                groupValue: themeMode,
                secondary: const Icon(Icons.light_mode),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 0 : 4,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -3) : null,
              ),
              RadioListTile<ThemeMode>(
                title: Text(
                  l10n.darkTheme,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: ThemeMode.dark,
                groupValue: themeMode,
                secondary: const Icon(Icons.dark_mode),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 0 : 4,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -3) : null,
              ),
              RadioListTile<ThemeMode>(
                title: Text(
                  l10n.systemTheme,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: ThemeMode.system,
                groupValue: themeMode,
                secondary: const Icon(Icons.brightness_auto),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 0 : 4,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -3) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.language),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(
                  l10n.selectLanguage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  currentLocale?.displayName ?? 'System Default',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLanguageDialog(context, l10n),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.notifications),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(
                  l10n.notificationPermissions,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text(
                  'Manage notification settings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _openNotificationSettings,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context, AppLocalizations l10n) {
    final analyticsEnabled = ref.watch(analyticsSettingsProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.security),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.security,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                title: Text(
                  l10n.endToEndEncryption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.encryptionEnabled,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Icon(
                  Icons.verified,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(
                  l10n.analyticsOptIn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.analyticsDesc,
                  maxLines: isCompact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: const Icon(Icons.analytics),
                value: analyticsEnabled,
                onChanged: (value) {
                  ref
                      .read(analyticsSettingsProvider.notifier)
                      .setAnalyticsEnabled(value);
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 0 : 4,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -3) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportExportSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.importExport),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_download),
                title: Text(
                  l10n.importNotes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text(
                  'Import from Markdown, Evernote, or Obsidian',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showImportDialog(context, l10n),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: Text(
                  l10n.exportNotes,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text(
                  'Export to Markdown, PDF, or HTML',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showExportDialog(context, l10n),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpAboutSection(BuildContext context, AppLocalizations l10n) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.helpAbout),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.help),
                title: Text(
                  l10n.userGuide,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('Learn how to use Duru Notes'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen()));
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(
                  l10n.version,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _packageInfo != null
                      ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                      : 'Loading...',
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text(
                  l10n.privacyPolicy,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('https://durunotes.com/privacy'),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(
                  l10n.termsOfService,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('https://durunotes.com/terms'),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: Text(
                  l10n.contactSupport,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('mailto:support@durunotes.com'),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isCompact ? 6 : 10,
                ),
                visualDensity:
                    isCompact ? const VisualDensity(vertical: -2) : null,
                minLeadingWidth: 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSignOutDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.no),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (confirmed ?? false && mounted) {
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        // Clear local database and per-user last pull key via SyncService
        final sync = ref.read(syncServiceProvider);
        await sync.reset();
        // Delete per-user master key
        if (uid != null && uid.isNotEmpty) {
          await ref.read(keyManagerProvider).deleteMasterKey(uid);
        }
        // IMPORTANT: Also clear the AMK from AccountKeyService
        await ref.read(accountKeyServiceProvider).clearLocalAmk();
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
        }
      }
    }
  }

  Future<void> _performManualSync(AppLocalizations l10n) async {
    setState(() => _isSyncing = true);

    try {
      debugPrint('🔄 Manual sync triggered from settings screen');
      final success = await ref.read(syncModeProvider.notifier).manualSync();

      if (success) {
        debugPrint('📱 Refreshing notes list in UI...');
        // Reload the first page of notes to show synced data
        await ref.read(notesPageProvider.notifier).refresh();

        // Load additional pages if there are more notes
        while (ref.read(hasMoreNotesProvider)) {
          await ref.read(notesPageProvider.notifier).loadMore();
        }

        // Refresh folders as well
        await ref.read(folderHierarchyProvider.notifier).loadFolders();

        // Add a small delay to ensure UI updates
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Get current notes count for feedback
        final currentNotes = ref.read(currentNotesProvider);
        debugPrint('📊 UI now showing ${currentNotes.length} notes');
      }

      if (mounted) {
        final message = success
            ? '${l10n.syncComplete} (${ref.read(currentNotesProvider).length} notes)'
            : l10n.syncFailed;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error,
            action: success
                ? null
                : SnackBarAction(
                    label: 'Debug',
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sync Debug Info'),
                          content: const Text(
                            'Check console logs for detailed sync information.\n\n'
                            'Common issues:\n'
                            '• Not authenticated\n'
                            '• Network connectivity\n'
                            '• Supabase configuration\n'
                            '• Encryption key issues',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Sync operation threw exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.syncFailed}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _showLanguageDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final currentLocale = ref.read(localeProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<Locale?>(
              title: const Text('System Default'),
              value: null,
              groupValue: currentLocale,
              onChanged: (locale) {
                ref.read(localeProvider.notifier).setLocale(locale);
                Navigator.of(context).pop();
              },
            ),
            ...LocaleNotifier.supportedLocales.map(
              (locale) => RadioListTile<Locale?>(
                title: Row(
                  children: [
                    Text(locale.flagEmoji),
                    const SizedBox(width: 8),
                    Text(locale.displayName),
                  ],
                ),
                value: locale,
                groupValue: currentLocale,
                onChanged: (selectedLocale) {
                  ref.read(localeProvider.notifier).setLocale(selectedLocale);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotificationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open system settings')),
        );
      }
    }
  }

  void _showImportDialog(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importNotes),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImportExportButton(
              icon: Icons.article,
              title: l10n.markdownFiles,
              subtitle: 'Import .md and .markdown files',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement file picker for markdown import
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Markdown import coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildImportExportButton(
              icon: Icons.note_add,
              title: l10n.evernoteExport,
              subtitle: 'Import .enex files from Evernote',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement file picker for ENEX import
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Evernote import coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildImportExportButton(
              icon: Icons.folder,
              title: l10n.obsidianVault,
              subtitle: 'Import Obsidian vault folder',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement directory picker for Obsidian import
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Obsidian import coming soon')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.exportNotes),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImportExportButton(
              icon: Icons.article,
              title: l10n.markdown,
              subtitle: 'Export as .md files with full formatting',
              onTap: () async {
                Navigator.of(context).pop();
                await _exportAllFromSettings(ExportFormat.markdown);
              },
            ),
            const SizedBox(height: 8),
            _buildImportExportButton(
              icon: Icons.picture_as_pdf,
              title: l10n.pdf,
              subtitle: 'Export as PDF documents for sharing',
              onTap: () async {
                Navigator.of(context).pop();
                await _exportAllFromSettings(ExportFormat.pdf);
              },
            ),
            const SizedBox(height: 8),
            _buildImportExportButton(
              icon: Icons.web,
              title: l10n.html,
              subtitle: 'Export as web pages with styling',
              onTap: () async {
                Navigator.of(context).pop();
                await _exportAllFromSettings(ExportFormat.html);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildImportExportButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  /// Build security section with iOS-style toggles
  Widget _buildSecuritySectionWithIOSToggles(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final analyticsEnabled = ref.watch(analyticsSettingsProvider);

    return SettingsSection(
      title: l10n.security,
      icon: Icons.security,
      children: [
        ListTile(
          leading: const Icon(Icons.security, color: Colors.green),
          title: Text(l10n.endToEndEncryption),
          subtitle: Text(l10n.encryptionEnabled),
          trailing: const Icon(Icons.verified, color: Colors.green),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.vpn_key),
          title: const Text('Change encryption passphrase'),
          subtitle: const Text('Re-wrap your Account Master Key (AMK)'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _showChangePassphraseDialog(context),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.upgrade),
          title: const Text('Migrate legacy encryption'),
          subtitle: const Text('Re-encrypt local data with AMK and push'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () async {
            try {
              final repo = ref.read(notesRepositoryProvider);
              final queued = await ref
                  .read(accountKeyServiceProvider)
                  .migrateLegacyContentAndEnqueue(
                    db: ref.read(appDbProvider),
                    repo: repo,
                  );
              // Trigger a sync
              await ref.read(syncModeProvider.notifier).manualSync();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Queued $queued items for rewrap and sync'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
              }
            }
          },
        ),
        SettingsToggleTile(
          title: l10n.analyticsOptIn,
          subtitle: l10n.analyticsDesc,
          leading: const Icon(Icons.analytics),
          value: analyticsEnabled,
          onChanged: (value) {
            ref
                .read(analyticsSettingsProvider.notifier)
                .setAnalyticsEnabled(value);
          },
        ),
      ],
    );
  }

  void _showChangePassphraseDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change encryption passphrase'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current passphrase',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New passphrase',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new passphrase',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                validator: (v) => v == newCtrl.text ? null : 'Does not match',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await ref.read(accountKeyServiceProvider).changePassphrase(
                      oldPassphrase: oldCtrl.text,
                      newPassphrase: newCtrl.text,
                    );
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passphrase updated')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    }
  }
}
