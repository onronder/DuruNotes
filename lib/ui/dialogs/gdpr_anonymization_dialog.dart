/// GDPR-compliant user anonymization dialog
///
/// This dialog implements the three-tier confirmation system required
/// before initiating the irreversible anonymization process.
///
/// **GDPR Compliance**:
/// - Article 7: Explicit, informed consent
/// - Article 17: Right to Erasure
/// - ISO 29100:2024: User consent validation
///
/// **Security Features**:
/// - Three-tier confirmation system
/// - Confirmation token validation
/// - Point of No Return warnings
/// - Progress tracking with real-time updates
library;

import 'package:duru_notes/core/animation_config.dart';
import 'package:duru_notes/core/gdpr/anonymization_types.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/l10n/app_localizations.dart';
import 'package:duru_notes/services/providers/services_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension for GDPR-related localization strings
extension GDPRAnonymizationL10n on AppLocalizations {
  String get gdprAnonymizeAccount => 'Anonymize Account';
  String get gdprAnonymizeAccountSubtitle =>
      'Permanently anonymize all your data';
  String get gdprWarningTitle => 'IRREVERSIBLE ACTION';
  String get gdprWarningMessage =>
      'This action will permanently destroy all encryption keys, making your encrypted data permanently inaccessible. This process CANNOT be undone.';
  String get gdprConfirmation1Title => 'Data Backup Complete';
  String get gdprConfirmation1Message =>
      'I have backed up all important data from this account';
  String get gdprConfirmation2Title => 'Understand Irreversibility';
  String get gdprConfirmation2Message =>
      'I understand that after Phase 3 (Key Destruction), this process cannot be stopped or reversed';
  String get gdprConfirmation3Title => 'Final Confirmation';
  String get gdprConfirmation3Message => 'Type "DELETE MY ACCOUNT" to proceed';
  String get gdprConfirmationCode => 'Confirmation';
  String get gdprConfirmationCodeHint => 'DELETE MY ACCOUNT';
  String get gdprPointOfNoReturn => 'Point of No Return';
  String get gdprPointOfNoReturnWarning =>
      'You are about to reach the Point of No Return. After Phase 3 completes, the process CANNOT be stopped.';
  String get gdprProceed => 'Proceed with Anonymization';
  String get gdprCancel => 'Cancel';
  String get gdprProcessing => 'Processing...';
  String get gdprViewDetails => 'View Details';
}

/// Result of the anonymization dialog
class AnonymizationDialogResult {
  const AnonymizationDialogResult({required this.confirmed, this.report});

  /// Whether user confirmed and completed the anonymization
  final bool confirmed;

  /// Anonymization report (if successful)
  final GDPRAnonymizationReport? report;
}

/// Multi-step confirmation dialog for GDPR anonymization
///
/// Implements three-tier confirmation system:
/// 1. Data backup confirmation
/// 2. Irreversibility understanding
/// 3. Confirmation token validation
class GDPRAnonymizationDialog extends ConsumerStatefulWidget {
  const GDPRAnonymizationDialog({super.key, required this.userId});

  /// User ID to anonymize
  final String userId;

  @override
  ConsumerState<GDPRAnonymizationDialog> createState() =>
      _GDPRAnonymizationDialogState();
}

class _GDPRAnonymizationDialogState
    extends ConsumerState<GDPRAnonymizationDialog>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _confirmationTokenController = TextEditingController();
  final _tokenFocusNode = FocusNode();

  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _shakeController;

  final _logger = LoggerFactory.instance;

  // Confirmation state
  bool _dataBackupConfirmed = false;
  bool _irreversibilityConfirmed = false;
  bool _acknowledgesRisks = false;
  String _confirmationToken = '';

  // Process state
  bool _isProcessing = false;
  DateTime? _lastSubmitAttempt;
  AnonymizationProgress? _currentProgress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: AnimationConfig.standard,
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _confirmationTokenController.dispose();
    _tokenFocusNode.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Validate all confirmations
  bool _validateConfirmations() {
    if (!_dataBackupConfirmed) {
      _showError('Please confirm that you have backed up your data');
      return false;
    }

    if (!_irreversibilityConfirmed) {
      _showError('Please confirm that you understand this is irreversible');
      return false;
    }

    if (!_acknowledgesRisks) {
      _showError('Please acknowledge all risks and consequences');
      return false;
    }

    if (_confirmationToken.isEmpty) {
      _showError('Please enter the confirmation code');
      _shakeConfirmationField();
      return false;
    }

    final expectedToken = UserConfirmations.generateConfirmationToken(
      widget.userId,
    );
    if (_confirmationToken != expectedToken) {
      _showError('Confirmation code does not match. Please try again.');
      _shakeConfirmationField();
      return false;
    }

    return true;
  }

  /// Shake the confirmation field for visual feedback
  Future<void> _shakeConfirmationField() async {
    await HapticFeedback.heavyImpact();
    _shakeController.reset();
    await _shakeController.forward();
  }

  /// Show error message
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    HapticFeedback.heavyImpact();
  }

  /// Start anonymization process
  Future<void> _startAnonymization() async {
    // Prevent duplicate submissions
    final now = DateTime.now();
    if (_isProcessing ||
        (_lastSubmitAttempt != null &&
            now.difference(_lastSubmitAttempt!).inMilliseconds < 2000)) {
      return;
    }

    if (!_validateConfirmations()) {
      return;
    }

    // Set processing state
    setState(() {
      _isProcessing = true;
      _lastSubmitAttempt = now;
      _errorMessage = null;
    });

    try {
      _logger.info(
        'Starting GDPR anonymization',
        data: {'userId': widget.userId},
      );

      final confirmations = UserConfirmations(
        dataBackupComplete: _dataBackupConfirmed,
        understandsIrreversibility: _irreversibilityConfirmed,
        finalConfirmationToken: _confirmationToken,
        acknowledgesRisks: _acknowledgesRisks,
        allowProductionOverride:
            false, // Safety: Requires manual override in production
      );

      // Get the service
      final service = ref.read(gdprAnonymizationServiceProvider);

      // Execute anonymization with progress callbacks
      final report = await service.anonymizeUserAccount(
        userId: widget.userId,
        confirmations: confirmations,
        onProgress: (AnonymizationProgress progress) {
          if (mounted) {
            setState(() {
              _currentProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        _logger.info(
          'GDPR anonymization completed',
          data: {
            'anonymizationId': report.anonymizationId,
            'success': report.success,
          },
        );

        // Wait a moment to show completion, then close
        await Future<void>.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          await HapticFeedback.mediumImpact();
          Navigator.of(
            context,
          ).pop(AnonymizationDialogResult(confirmed: true, report: report));
        }
      }
    } catch (e, stack) {
      _logger.error('GDPR anonymization failed', error: e, stackTrace: stack);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Anonymization failed: ${e.toString()}';
        });

        await HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // Wrap dialog in Material to ensure proper localization context
    return Material(
      type: MaterialType.transparency,
      child: Localizations(
        locale: Localizations.localeOf(context),
        delegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        child: Builder(
          builder: (BuildContext localizedContext) {
            return PopScope(
              canPop: !_isProcessing,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _scaleController,
                  curve: Curves.easeOutBack,
                ),
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _slideController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: Dialog(
                    backgroundColor: colorScheme.surface,
                    surfaceTintColor: colorScheme.surfaceTint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 600,
                        maxHeight: 700,
                      ),
                      child: _isProcessing
                          ? _buildProgressView(theme, l10n, colorScheme)
                          : _buildConfirmationView(theme, l10n, colorScheme),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build confirmation view (before processing)
  Widget _buildConfirmationView(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildHeader(theme, l10n, colorScheme),
        _buildWarningBanner(theme, l10n, colorScheme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmationCheckbox(
                    value: _dataBackupConfirmed,
                    title: l10n.gdprConfirmation1Title,
                    message: l10n.gdprConfirmation1Message,
                    onChanged: (value) {
                      setState(() => _dataBackupConfirmed = value ?? false);
                      HapticFeedback.selectionClick();
                    },
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _buildConfirmationCheckbox(
                    value: _irreversibilityConfirmed,
                    title: l10n.gdprConfirmation2Title,
                    message: l10n.gdprConfirmation2Message,
                    onChanged: (value) {
                      setState(
                        () => _irreversibilityConfirmed = value ?? false,
                      );
                      HapticFeedback.selectionClick();
                    },
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _buildConfirmationCheckbox(
                    value: _acknowledgesRisks,
                    title: 'Acknowledge All Risks',
                    message:
                        'I acknowledge all risks and consequences of this irreversible action. I understand that all encrypted data will become permanently inaccessible.',
                    onChanged: (value) {
                      setState(() => _acknowledgesRisks = value ?? false);
                      HapticFeedback.selectionClick();
                    },
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 24),
                  _buildConfirmationTokenField(theme, l10n, colorScheme),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorMessage(theme, colorScheme),
                  ],
                ],
              ),
            ),
          ),
        ),
        _buildActions(theme, l10n, colorScheme),
      ],
    );
  }

  /// Build progress view (during processing)
  Widget _buildProgressView(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final progress = _currentProgress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.gdprProcessing,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Phase ${progress.currentPhase}/7: ${progress.phaseName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (progress != null) ...[
                  // Progress indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progress.overallProgress,
                          strokeWidth: 8,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          color: progress.pointOfNoReturnReached
                              ? colorScheme.error
                              : colorScheme.primary,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '${progress.overallProgressPercent}%',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: progress.pointOfNoReturnReached
                                  ? colorScheme.error
                                  : colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Phase ${progress.currentPhase}/7',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Status message
                  Text(
                    progress.statusMessage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Point of No Return warning
                  if (progress.pointOfNoReturnReached) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: colorScheme.error,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.gdprPointOfNoReturnWarning,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build dialog header
  Widget _buildHeader(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
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
            child: Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gdprAnonymizeAccount,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.gdprAnonymizeAccountSubtitle,
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

  /// Build warning banner
  Widget _buildWarningBanner(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.gdprWarningTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.gdprWarningMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  /// Build confirmation checkbox
  Widget _buildConfirmationCheckbox({
    required bool value,
    required String title,
    required String message,
    required ValueChanged<bool?> onChanged,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  /// Build confirmation token field
  Widget _buildConfirmationTokenField(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final expectedToken = UserConfirmations.generateConfirmationToken(
      widget.userId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gdprConfirmation3Title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Type "$expectedToken" to confirm (case-insensitive)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final value = _shakeController.value;
            final offset = value < 0.5
                ? Offset(value * 0.2, 0)
                : Offset((1 - value) * 0.2, 0);
            return Transform.translate(offset: offset, child: child);
          },
          child: TextFormField(
            controller: _confirmationTokenController,
            focusNode: _tokenFocusNode,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              labelText: 'Type to confirm',
              hintText: expectedToken,
              prefixIcon: const Icon(Icons.warning_amber_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _confirmationToken = value.trim();
                _errorMessage = null;
              });
            },
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please type "$expectedToken" to confirm';
              }
              // Case-insensitive comparison
              if (value!.trim().toUpperCase() != expectedToken.toUpperCase()) {
                return 'Please type exactly: $expectedToken';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  /// Build error message
  Widget _buildErrorMessage(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActions(
    ThemeData theme,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    final allConfirmed =
        _dataBackupConfirmed &&
        _irreversibilityConfirmed &&
        _acknowledgesRisks &&
        _confirmationToken.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isProcessing
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(const AnonymizationDialogResult(confirmed: false)),
            child: Text(l10n.gdprCancel),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FilledButton.tonal(
              onPressed: _isProcessing || !allConfirmed
                  ? null
                  : _startAnonymization,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colorScheme.onError,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.gdprProceed,
                      overflow: TextOverflow.ellipsis,
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
