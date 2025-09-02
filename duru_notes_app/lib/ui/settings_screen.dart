import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/settings/locale_notifier.dart';
import '../core/settings/sync_mode.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';

import 'help_screen.dart';

/// Comprehensive settings screen for Duru Notes
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
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
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAccountSection(context, l10n),
          const SizedBox(height: 24),
          _buildSyncSection(context, l10n),
          const SizedBox(height: 24),
          _buildAppearanceSection(context, l10n),
          const SizedBox(height: 24),
          _buildLanguageSection(context, l10n),
          const SizedBox(height: 24),
          _buildNotificationsSection(context, l10n),
          const SizedBox(height: 24),
          _buildSecuritySection(context, l10n),
          const SizedBox(height: 24),
          _buildImportExportSection(context, l10n),
          const SizedBox(height: 24),
          _buildHelpAboutSection(context, l10n),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, AppLocalizations l10n) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.account),
        Card(
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
                  title: Text(l10n.signedInAs),
                  subtitle: Text(user.email ?? 'Unknown'),
                  trailing: const Icon(Icons.verified_user, color: Colors.green),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  l10n.signOut,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => _showSignOutDialog(context, l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncSection(BuildContext context, AppLocalizations l10n) {
    final syncMode = ref.watch(syncModeProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.sync),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(l10n.syncMode),
                subtitle: Text(syncMode.displayName),
              ),
              const Divider(height: 1),
              RadioListTile<SyncMode>(
                title: Text(l10n.automaticSync),
                subtitle: Text(l10n.automaticSyncDesc),
                value: SyncMode.automatic,
                groupValue: syncMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(syncModeProvider.notifier).setMode(mode);
                  }
                },
              ),
              RadioListTile<SyncMode>(
                title: Text(l10n.manualSync),
                subtitle: Text(l10n.manualSyncDesc),
                value: SyncMode.manual,
                groupValue: syncMode,
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(syncModeProvider.notifier).setMode(mode);
                  }
                },
              ),
              if (syncMode == SyncMode.manual) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSyncing ? null : () => _performManualSync(l10n),
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_isSyncing ? l10n.syncing : l10n.syncNow),
                    ),
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
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.appearance),
        Card(
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text(l10n.lightTheme),
                value: ThemeMode.light,
                groupValue: themeMode,
                secondary: const Icon(Icons.light_mode),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.darkTheme),
                value: ThemeMode.dark,
                groupValue: themeMode,
                secondary: const Icon(Icons.dark_mode),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text(l10n.systemTheme),
                value: ThemeMode.system,
                groupValue: themeMode,
                secondary: const Icon(Icons.brightness_auto),
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSection(BuildContext context, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.language),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.selectLanguage),
                subtitle: Text(currentLocale?.displayName ?? 'System Default'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLanguageDialog(context, l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.notifications),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(l10n.notificationPermissions),
                subtitle: const Text('Manage notification settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _openNotificationSettings(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection(BuildContext context, AppLocalizations l10n) {
    final analyticsEnabled = ref.watch(analyticsSettingsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.security),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.security, color: Colors.green),
                title: Text(l10n.endToEndEncryption),
                subtitle: Text(l10n.encryptionEnabled),
                trailing: const Icon(Icons.verified, color: Colors.green),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(l10n.analyticsOptIn),
                subtitle: Text(l10n.analyticsDesc),
                secondary: const Icon(Icons.analytics),
                value: analyticsEnabled,
                onChanged: (value) {
                  ref.read(analyticsSettingsProvider.notifier).setAnalyticsEnabled(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImportExportSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.importExport),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.file_download),
                title: Text(l10n.importNotes),
                subtitle: const Text('Import from Markdown, Evernote, or Obsidian'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showImportDialog(context, l10n),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: Text(l10n.exportNotes),
                subtitle: const Text('Export to Markdown, PDF, or HTML'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showExportDialog(context, l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpAboutSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.helpAbout),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.help),
                title: Text(l10n.userGuide),
                subtitle: const Text('Learn how to use Duru Notes'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(l10n.version),
                subtitle: Text(
                  _packageInfo != null
                      ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                      : 'Loading...',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: Text(l10n.privacyPolicy),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('https://durunotes.com/privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text(l10n.termsOfService),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('https://durunotes.com/terms'),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: Text(l10n.contactSupport),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () => _launchUrl('mailto:support@durunotes.com'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSignOutDialog(BuildContext context, AppLocalizations l10n) async {
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

    if (confirmed == true && mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  Future<void> _performManualSync(AppLocalizations l10n) async {
    setState(() => _isSyncing = true);

    try {
      final success = await ref.read(syncModeProvider.notifier).manualSync();
      
      if (success) {
        // Reload the first page of notes to show synced data
        await ref.read(notesPageProvider.notifier).refresh();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? l10n.syncComplete : l10n.syncFailed),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _showLanguageDialog(BuildContext context, AppLocalizations l10n) async {
    final currentLocale = ref.read(localeProvider);
    
    await showDialog(
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
    showDialog(
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
    showDialog(
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
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement export functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Markdown export coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildImportExportButton(
              icon: Icons.picture_as_pdf,
              title: l10n.pdf,
              subtitle: 'Export as PDF documents for sharing',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement export functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildImportExportButton(
              icon: Icons.web,
              title: l10n.html,
              subtitle: 'Export as web pages with styling',
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement export functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('HTML export coming soon')),
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
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }
}
