/// GDPR Compliance Certificate Viewer
///
/// Displays the complete anonymization report and compliance certificate
/// in a user-friendly format.
///
/// **Features**:
/// - Human-readable compliance certificate
/// - Phase-by-phase breakdown
/// - Key destruction details
/// - Cryptographic proof hash
/// - Export capabilities
library;

import 'package:duru_notes/core/gdpr/anonymization_types.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Extension for compliance certificate localization
extension ComplianceCertificateL10n on AppLocalizations {
  String get complianceCertificate => 'Compliance Certificate';
  String get anonymizationId => 'Anonymization ID';
  String get anonymizationStarted => 'Started';
  String get anonymizationCompleted => 'Completed';
  String get anonymizationDuration => 'Duration';
  String get anonymizationStatus => 'Status';
  String get anonymizationPhases => 'Anonymization Phases';
  String get keyDestruction => 'Key Destruction';
  String get complianceProof => 'Compliance Proof';
  String get proofHash => 'Proof Hash (SHA-256)';
  String get copyToClipboard => 'Copy to Clipboard';
  String get copiedToClipboard => 'Copied to clipboard';
  String get exportCertificate => 'Export Certificate';
  String get viewFullReport => 'View Full Report';
}

/// Widget to display GDPR compliance certificate
class GDPRComplianceCertificateViewer extends StatefulWidget {
  const GDPRComplianceCertificateViewer({
    super.key,
    required this.report,
  });

  /// Anonymization report to display
  final GDPRAnonymizationReport report;

  @override
  State<GDPRComplianceCertificateViewer> createState() =>
      _GDPRComplianceCertificateViewerState();
}

class _GDPRComplianceCertificateViewerState
    extends State<GDPRComplianceCertificateViewer> {
  bool _showFullJson = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: 800,
        ),
        child: Column(
          children: [
            _buildHeader(theme, l10n, colorScheme),
            Expanded(
              child: _showFullJson
                  ? _buildFullJsonView(theme, l10n, colorScheme)
                  : _buildCertificateView(theme, l10n, colorScheme),
            ),
            _buildActions(theme, l10n, colorScheme),
          ],
        ),
      ),
    );
  }

  /// Build header
  Widget _buildHeader(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.report.success
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.report.success
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.report.success
                  ? Icons.verified_user
                  : Icons.error_outline,
              color: widget.report.success
                  ? colorScheme.primary
                  : colorScheme.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.complianceCertificate,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.report.success
                      ? 'GDPR Article 17 Compliance Verified'
                      : 'Anonymization Incomplete',
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

  /// Build certificate view
  Widget _buildCertificateView(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(theme, l10n, colorScheme),
          const SizedBox(height: 24),
          _buildPhasesSection(theme, l10n, colorScheme),
          if (widget.report.keyDestructionReport != null) ...[
            const SizedBox(height: 24),
            _buildKeyDestructionSection(theme, l10n, colorScheme),
          ],
          const SizedBox(height: 24),
          _buildComplianceProofSection(theme, l10n, colorScheme),
        ],
      ),
    );
  }

  /// Build full JSON view
  Widget _buildFullJsonView(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          widget.report.toPrettyJson(),
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// Build overview section
  Widget _buildOverviewSection(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          icon: Icons.fingerprint,
          label: l10n.anonymizationId,
          value: widget.report.anonymizationId,
          theme: theme,
          colorScheme: colorScheme,
          monospace: true,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.access_time,
          label: l10n.anonymizationStarted,
          value: dateFormat.format(widget.report.startedAt),
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.check_circle_outline,
          label: l10n.anonymizationCompleted,
          value: widget.report.completedAt != null
              ? dateFormat.format(widget.report.completedAt!)
              : 'In Progress',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.timer,
          label: l10n.anonymizationDuration,
          value: widget.report.duration != null
              ? '${widget.report.duration!.inSeconds} seconds'
              : 'N/A',
          theme: theme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: widget.report.success
              ? Icons.check_circle
              : Icons.error,
          label: l10n.anonymizationStatus,
          value: widget.report.success ? 'SUCCESS' : 'FAILED',
          theme: theme,
          colorScheme: colorScheme,
          valueColor: widget.report.success
              ? colorScheme.primary
              : colorScheme.error,
        ),
      ],
    );
  }

  /// Build phases section
  Widget _buildPhasesSection(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final phases = [
      widget.report.phase1Validation,
      widget.report.phase2Metadata,
      widget.report.phase3KeyDestruction,
      widget.report.phase4Tombstoning,
      widget.report.phase5MetadataClearing,
      widget.report.phase6SyncInvalidation,
      widget.report.phase7ComplianceProof,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.anonymizationPhases,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...phases.map((phase) => _buildPhaseCard(
              phase,
              theme,
              colorScheme,
            )),
      ],
    );
  }

  /// Build phase card
  Widget _buildPhaseCard(
    PhaseReport phase,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isPointOfNoReturn = phase.phaseNumber == 3;
    final status = phase.success
        ? '✅ SUCCESS'
        : (phase.completed ? '❌ FAILED' : '⏳ PENDING');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: phase.success
            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
            : (phase.completed
                ? colorScheme.errorContainer.withValues(alpha: 0.2)
                : colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  )),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPointOfNoReturn
              ? colorScheme.error.withValues(alpha: 0.5)
              : (phase.success
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outlineVariant),
          width: isPointOfNoReturn ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: phase.success
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : (phase.completed
                          ? colorScheme.error.withValues(alpha: 0.1)
                          : colorScheme.surfaceContainerHighest),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${phase.phaseNumber}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: phase.success
                          ? colorScheme.primary
                          : (phase.completed
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.phaseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: phase.success
                            ? colorScheme.primary
                            : (phase.completed
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPointOfNoReturn)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'POINT OF NO RETURN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          if (phase.duration != null) ...[
            const SizedBox(height: 8),
            Text(
              'Duration: ${phase.duration!.inMilliseconds}ms',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (phase.errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...phase.errors.map(
              (error) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build key destruction section
  Widget _buildKeyDestructionSection(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final keyReport = widget.report.keyDestructionReport!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.keyDestruction,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: SelectableText(
            keyReport.toSummary(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  /// Build compliance proof section
  Widget _buildComplianceProofSection(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.complianceProof,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified_user,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.proofHash,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                widget.report.proofHash ?? 'PENDING',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build info row
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required ColorScheme colorScheme,
    bool monospace = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: monospace ? 'monospace' : null,
              color: valueColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Build action buttons
  Widget _buildActions(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showFullJson = !_showFullJson;
              });
            },
            icon: Icon(
              _showFullJson ? Icons.description : Icons.code,
              size: 18,
            ),
            label: Text(
              _showFullJson ? 'View Certificate' : l10n.viewFullReport,
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: widget.report.toComplianceCertificate(),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.copiedToClipboard),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l10n.copyToClipboard),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
