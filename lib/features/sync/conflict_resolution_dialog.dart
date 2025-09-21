import 'dart:convert';

import 'package:duru_notes/core/animation_config.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/features/folders/folder_icon_helpers.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/providers.dart';
import 'package:duru_notes/services/sync/folder_sync_audit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

extension ConflictResolutionL10n on AppLocalizations {
  String get conflictSyncDetectedTitle => 'Sync Conflict Detected';
  String get conflictLocalTab => 'Local';
  String get conflictRemoteTab => 'Remote';
  String get conflictMergedTab => 'Merged';
  String get conflictChooseResolution => 'Choose Resolution';
  String get conflictKeepLocal => 'Keep Local';
  String get conflictKeepRemote => 'Keep Remote';
  String get conflictMerge => 'Merge';
  String get conflictSkip => 'Skip';
  String get conflictResolve => 'Resolve';
}

/// Represents a sync conflict that needs manual resolution
class SyncConflict {
  SyncConflict({
    required this.id,
    required this.type,
    required this.localData,
    required this.remoteData,
    required this.conflictTime,
    this.additionalInfo,
  });

  final String id;
  final ConflictType type;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> remoteData;
  final DateTime conflictTime;
  final Map<String, dynamic>? additionalInfo;
}

/// Types of sync conflicts
enum ConflictType {
  folderUpdate,
  folderDelete,
  noteUpdate,
  noteDelete,
  noteMove,
}

/// Resolution strategies for conflicts
enum ResolutionStrategy { keepLocal, keepRemote, merge, skip }

/// Dialog for resolving sync conflicts manually
class ConflictResolutionDialog extends ConsumerStatefulWidget {
  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    this.onResolved,
  });

  final SyncConflict conflict;
  final Function(ResolutionStrategy strategy, Map<String, dynamic>? mergedData)?
      onResolved;

  @override
  ConsumerState<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState
    extends ConsumerState<ConflictResolutionDialog>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late TabController _tabController;

  ResolutionStrategy? _selectedStrategy;
  Map<String, dynamic>? _mergedData;
  bool _showDiff = true;
  bool _isResolving = false;

  final _logger = LoggerFactory.instance;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: AnimationConfig.standard,
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: AnimationConfig.fast,
      vsync: this,
    );
    _tabController = TabController(length: 3, vsync: this);

    _slideController.forward();
    _fadeController.forward();

    // Pre-select merge strategy if available
    if (_canMerge()) {
      _selectedStrategy = ResolutionStrategy.merge;
      _prepareMergedData();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _canMerge() {
    // Only folder updates can be merged
    return widget.conflict.type == ConflictType.folderUpdate;
  }

  void _prepareMergedData() {
    if (!_canMerge()) return;

    final local = widget.conflict.localData;
    final remote = widget.conflict.remoteData;

    // Merge strategy: Take newer timestamps, combine other fields intelligently
    _mergedData = {
      'id': local['id'] ?? remote['id'],
      'name': _selectNewer(local, remote, 'name', 'updated_at'),
      'description': _mergeDescriptions(
        local['description'] as String?,
        remote['description'] as String?,
      ),
      'color': _selectNewer(local, remote, 'color', 'updated_at'),
      'icon': _selectNewer(local, remote, 'icon', 'updated_at'),
      'parent_id': _selectNewer(local, remote, 'parent_id', 'updated_at'),
      'sort_order': _selectNewer(local, remote, 'sort_order', 'updated_at'),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  dynamic _selectNewer(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    String field,
    String timestampField,
  ) {
    final localTime = DateTime.tryParse(
      (local[timestampField] as String?) ?? '',
    );
    final remoteTime = DateTime.tryParse(
      (remote[timestampField] as String?) ?? '',
    );

    if (localTime == null) return remote[field];
    if (remoteTime == null) return local[field];

    return localTime.isAfter(remoteTime) ? local[field] : remote[field];
  }

  String? _mergeDescriptions(String? local, String? remote) {
    if (local == null || local.isEmpty) return remote;
    if (remote == null || remote.isEmpty) return local;
    if (local == remote) return local;

    // Combine descriptions with separator
    return '$local\n---\n$remote';
  }

  Future<void> _resolveConflict() async {
    if (_selectedStrategy == null) return;

    setState(() => _isResolving = true);

    try {
      // Log the resolution
      _logger.info(
        'Resolving conflict',
        data: {
          'conflictId': widget.conflict.id,
          'strategy': _selectedStrategy!.name,
          'type': widget.conflict.type.name,
        },
      );

      // Call the resolution callback
      widget.onResolved?.call(_selectedStrategy!, _mergedData);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, stack) {
      _logger.error('Failed to resolve conflict', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve conflict: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SlideTransition(
      position:
          Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: FadeTransition(
        opacity: _fadeController,
        child: Dialog(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(theme, l10n),
                _buildConflictInfo(theme, l10n),
                Flexible(child: _buildComparisonTabs(theme, l10n)),
                _buildResolutionOptions(theme, l10n),
                _buildActions(theme, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sync_problem, color: colorScheme.error, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.conflictSyncDetectedTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getConflictDescription(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConflictDescription() {
    switch (widget.conflict.type) {
      case ConflictType.folderUpdate:
        return 'Folder was modified in multiple places';
      case ConflictType.folderDelete:
        return 'Folder was deleted while being modified';
      case ConflictType.noteUpdate:
        return 'Note was modified in multiple places';
      case ConflictType.noteDelete:
        return 'Note was deleted while being modified';
      case ConflictType.noteMove:
        return 'Note was moved to different folders';
    }
  }

  Widget _buildConflictInfo(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Conflict detected at ${dateFormat.format(widget.conflict.conflictTime)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _showDiff = !_showDiff),
            icon: Icon(
              _showDiff ? Icons.visibility_off : Icons.visibility,
              size: 16,
            ),
            label: Text(_showDiff ? 'Hide Diff' : 'Show Diff'),
            style: TextButton.styleFrom(textStyle: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTabs(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.computer), text: l10n.conflictLocalTab),
            Tab(icon: const Icon(Icons.cloud), text: l10n.conflictRemoteTab),
            if (_canMerge())
              Tab(icon: const Icon(Icons.merge), text: l10n.conflictMergedTab),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDataView(widget.conflict.localData, 'Local Version', theme),
              _buildDataView(
                widget.conflict.remoteData,
                'Remote Version',
                theme,
              ),
              if (_canMerge())
                _buildDataView(_mergedData ?? {}, 'Merged Version', theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataView(
    Map<String, dynamic> data,
    String title,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.conflict.type == ConflictType.folderUpdate) ...[
            _buildFolderPreview(data, theme),
            const SizedBox(height: 16),
          ],
          if (_showDiff) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildDataFields(data, theme),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderPreview(Map<String, dynamic> data, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final rawName = (data['name'] as String?)?.trim();
    final description = (data['description'] as String?)?.trim() ?? '';
    final icon = (data['icon'] as String?) ?? Icons.folder.codePoint.toString();
    final color = (data['color'] as String?) ??
        colorScheme.primary.value.toRadixString(16);
    final name =
        (rawName == null || rawName.isEmpty) ? 'Unnamed Folder' : rawName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FolderIconHelpers.getFolderColor(
                    color,
                  )?.withValues(alpha: 0.2) ??
                  colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              FolderIconHelpers.getFolderIcon(icon),
              color: FolderIconHelpers.getFolderColor(color) ??
                  colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDataFields(Map<String, dynamic> data, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final fields = <Widget>[];

    // Highlight differences
    final localData = widget.conflict.localData;
    final remoteData = widget.conflict.remoteData;

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      // Skip internal fields
      if (key.startsWith('_') || key == 'user_id') continue;

      // Check if this field differs
      final isDifferent = localData[key] != remoteData[key];

      fields.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  _formatFieldName(key),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: isDifferent ? FontWeight.w600 : null,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: isDifferent
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                      : null,
                  decoration: isDifferent
                      ? BoxDecoration(
                          color: colorScheme.tertiaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    _formatValue(value),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDifferent
                          ? colorScheme.tertiary
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (isDifferent)
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: colorScheme.tertiary,
                ),
            ],
          ),
        ),
      );
    }

    return fields;
  }

  String _formatFieldName(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'None';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is DateTime) {
      return DateFormat.yMMMd().add_jm().format(value);
    }
    if (value is String && DateTime.tryParse(value) != null) {
      return DateFormat.yMMMd().add_jm().format(DateTime.parse(value));
    }
    return value.toString();
  }

  Widget _buildResolutionOptions(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.conflictChooseResolution,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildResolutionChip(
                ResolutionStrategy.keepLocal,
                Icons.computer,
                l10n.conflictKeepLocal,
                'Use the version from this device',
                theme,
              ),
              _buildResolutionChip(
                ResolutionStrategy.keepRemote,
                Icons.cloud,
                l10n.conflictKeepRemote,
                'Use the version from the server',
                theme,
              ),
              if (_canMerge())
                _buildResolutionChip(
                  ResolutionStrategy.merge,
                  Icons.merge,
                  l10n.conflictMerge,
                  'Combine both versions intelligently',
                  theme,
                ),
              _buildResolutionChip(
                ResolutionStrategy.skip,
                Icons.skip_next,
                l10n.conflictSkip,
                'Resolve this conflict later',
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionChip(
    ResolutionStrategy strategy,
    IconData icon,
    String label,
    String tooltip,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedStrategy == strategy;

    return Tooltip(
      message: tooltip,
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStrategy = selected ? strategy : null;
            if (strategy == ResolutionStrategy.merge && selected) {
              _prepareMergedData();
              _tabController.animateTo(2);
            }
          });
        },
        selectedColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surface,
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme, AppLocalizations l10n) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed:
                _isResolving ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isResolving || _selectedStrategy == null
                ? null
                : _resolveConflict,
            child: _isResolving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Text(l10n.conflictResolve),
          ),
        ],
      ),
    );
  }
}

/// Provider for managing conflict resolution queue
final conflictQueueProvider =
    StateNotifierProvider<ConflictQueueNotifier, List<SyncConflict>>((ref) {
  return ConflictQueueNotifier();
});

/// Notifier for managing sync conflicts
class ConflictQueueNotifier extends StateNotifier<List<SyncConflict>> {
  ConflictQueueNotifier() : super([]);

  void addConflict(SyncConflict conflict) {
    state = [...state, conflict];
  }

  void removeConflict(String conflictId) {
    state = state.where((c) => c.id != conflictId).toList();
  }

  void clearAll() {
    state = [];
  }

  bool get hasConflicts => state.isNotEmpty;
  int get conflictCount => state.length;
}
