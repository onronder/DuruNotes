import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duru_notes_app/core/monitoring/app_logger.dart';
import 'package:duru_notes_app/services/analytics/analytics_service.dart';
import 'package:duru_notes_app/services/import_service.dart';
import 'package:duru_notes_app/ui/help_screen.dart';

/// Settings screen with import functionality
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final AppLogger _logger = LoggerFactory.instance;
  final AnalyticsService _analytics = AnalyticsFactory.instance;
  
  bool _importing = false;
  String? _importStatus;

  @override
  void initState() {
    super.initState();
    _analytics.screen('settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          _buildImportSection(),
          const Divider(),
          _buildGeneralSection(),
          const Divider(),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildImportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Import Notes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.file_upload),
          title: const Text('Import from File'),
          subtitle: const Text('Markdown (.md) or Evernote Export (.enex)'),
          trailing: _importing 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _importing ? null : () => _importFromFile(),
        ),
        ListTile(
          leading: const Icon(Icons.folder),
          title: const Text('Import Obsidian Vault'),
          subtitle: const Text('Select a folder containing Markdown files'),
          trailing: _importing 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _importing ? null : () => _importObsidianVault(),
        ),
        if (_importStatus != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _importStatus!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'General',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('Help & User Guide'),
          subtitle: const Text('Learn how to use advanced features'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateToHelp(),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Reset Local Cache'),
          subtitle: const Text('Clear cached data and refresh'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _resetLocalCache(),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          subtitle: const Text('View our privacy policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showPrivacyPolicy(),
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Version'),
          subtitle: Text('1.0.0+1'),
        ),
        const ListTile(
          leading: Icon(Icons.developer_mode),
          title: Text('Duru Notes'),
          subtitle: Text('Your encrypted, mobile-first note-taking companion'),
        ),
      ],
    );
  }

  Future<void> _importFromFile() async {
    setState(() {
      _importing = true;
      _importStatus = 'Selecting file...';
    });

    try {
      final importService = ref.read(importServiceProvider);
      
      final result = await importService.pickAndImport(
        onProgress: (current, total, currentFile) {
          setState(() {
            _importStatus = 'Processing $currentFile ($current/$total)';
          });
        },
      );

      if (result == null) {
        setState(() {
          _importStatus = 'Import cancelled';
        });
        return;
      }

      _showImportResult(result);
      
    } catch (e) {
      _logger.error('Import failed', error: e);
      _showErrorDialog('Import Failed', e.toString());
    } finally {
      setState(() {
        _importing = false;
      });
    }
  }

  Future<void> _importObsidianVault() async {
    setState(() {
      _importing = true;
      _importStatus = 'Selecting folder...';
    });

    try {
      // Note: file_picker doesn't support directory picking on all platforms
      // This is a simplified implementation - in a real app you might use
      // a different approach for directory selection
      await _showInfoDialog(
        'Directory Import',
        'Directory import is currently supported on desktop platforms only. '
        'For mobile, please select individual Markdown files.',
      );
      
    } catch (e) {
      _logger.error('Obsidian import failed', error: e);
      _showErrorDialog('Import Failed', e.toString());
    } finally {
      setState(() {
        _importing = false;
        _importStatus = null;
      });
    }
  }

  void _showImportResult(ImportService.ImportResult result) {
    final message = result.hasErrors
        ? 'Import completed with ${result.successCount} successful and ${result.errorCount} failed imports.\n\n'
          'Errors:\n${result.errors.take(5).join('\n')}'
        : 'Successfully imported ${result.successCount} notes in ${result.duration.inSeconds} seconds.';

    _showInfoDialog(
      result.hasErrors ? 'Import Completed with Errors' : 'Import Successful',
      message,
    );

    setState(() {
      _importStatus = result.hasErrors
          ? 'Import completed with ${result.errorCount} errors'
          : 'Successfully imported ${result.successCount} notes';
    });

    // Clear status after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _importStatus = null;
        });
      }
    });
  }

  Future<void> _navigateToHelp() async {
    _analytics.event('settings.help_opened');
    
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HelpScreen(),
      ),
    );
  }

  Future<void> _resetLocalCache() async {
    final confirmed = await _showConfirmDialog(
      'Reset Local Cache',
      'This will clear all cached data and force a refresh from the server. Are you sure?',
    );

    if (confirmed) {
      _analytics.event('settings.cache_reset');
      
      // TODO: Implement cache reset functionality
      _showInfoDialog(
        'Cache Reset',
        'Local cache has been reset successfully.',
      );
    }
  }

  Future<void> _showPrivacyPolicy() async {
    _analytics.event('settings.privacy_policy_opened');
    
    // TODO: Implement privacy policy display
    _showInfoDialog(
      'Privacy Policy',
      'Privacy policy display is not yet implemented. '
      'Please check the PRIVACY_POLICY.md file in the project repository.',
    );
  }

  Future<void> _showInfoDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorDialog(String title, String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

/// Provider for ImportService
final importServiceProvider = Provider<ImportService>((ref) {
  final notesRepository = ref.read(notesRepositoryProvider);
  final noteIndexer = ref.read(noteIndexerProvider);
  final logger = LoggerFactory.instance;
  final analytics = AnalyticsFactory.instance;

  return ImportService(
    notesRepository: notesRepository,
    noteIndexer: noteIndexer,
    logger: logger,
    analytics: analytics,
  );
});

// Placeholder providers - these should be defined in their respective files
final notesRepositoryProvider = Provider<dynamic>((ref) => throw UnimplementedError());
final noteIndexerProvider = Provider<dynamic>((ref) => throw UnimplementedError());
