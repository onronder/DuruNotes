import 'package:flutter/material.dart';
import 'package:duru_notes_app/core/security/password_validator.dart';

/// Visual password strength meter with real-time validation feedback
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.validationResult,
    this.showCriteria = true,
    this.showScore = false,
  });

  final PasswordValidationResult validationResult;
  final bool showCriteria;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strength bar and label
        Row(
          children: [
            Expanded(
              child: _buildStrengthBar(theme),
            ),
            const SizedBox(width: 12),
            _buildStrengthLabel(theme),
          ],
        ),
        
        if (showScore) ...[
          const SizedBox(height: 4),
          Text(
            'Score: ${validationResult.score}/100',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        
        if (showCriteria) ...[
          const SizedBox(height: 12),
          _buildCriteriaList(theme),
        ],
        
        if (validationResult.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSuggestions(theme),
        ],
      ],
    );
  }

  /// Build the visual strength progress bar
  Widget _buildStrengthBar(ThemeData theme) {
    final strength = validationResult.strength;
    final score = validationResult.score;
    
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: score / 100.0,
          backgroundColor: Colors.transparent,
          valueColor: AlwaysStoppedAnimation<Color>(
            _getStrengthColor(strength),
          ),
        ),
      ),
    );
  }

  /// Build the strength label
  Widget _buildStrengthLabel(ThemeData theme) {
    final strength = validationResult.strength;
    final description = PasswordValidator.getStrengthDescription(strength);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStrengthColor(strength).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStrengthColor(strength).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        description,
        style: theme.textTheme.bodySmall?.copyWith(
          color: _getStrengthColor(strength),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Build the list of password criteria with check marks
  Widget _buildCriteriaList(ThemeData theme) {
    final criteria = PasswordValidator.getCriteria();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements:',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...criteria.map((criterion) => _buildCriterionItem(criterion, theme)),
      ],
    );
  }

  /// Build individual criterion item
  Widget _buildCriterionItem(PasswordCriterion criterion, ThemeData theme) {
    final isMet = !validationResult.failedCriteria.contains(criterion.description);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isMet 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              criterion.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isMet 
                    ? theme.colorScheme.onSurface 
                    : theme.colorScheme.onSurfaceVariant,
                decoration: isMet ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build suggestions for improvement
  Widget _buildSuggestions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Suggestions:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...validationResult.suggestions.take(3).map((suggestion) => 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                '• $suggestion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get color based on password strength
  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFf44336); // Red
      case PasswordStrength.medium:
        return const Color(0xFFff9800); // Orange
      case PasswordStrength.strong:
        return const Color(0xFF4caf50); // Green
      case PasswordStrength.veryStrong:
        return const Color(0xFF2e7d32); // Dark Green
    }
  }
}

/// Compact version of password strength meter for inline use
class CompactPasswordStrengthMeter extends StatelessWidget {
  const CompactPasswordStrengthMeter({
    super.key,
    required this.validationResult,
  });

  final PasswordValidationResult validationResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = validationResult.strength;
    final score = validationResult.score;
    
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: score / 100.0,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStrengthColor(strength),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          PasswordValidator.getStrengthDescription(strength),
          style: theme.textTheme.bodySmall?.copyWith(
            color: _getStrengthColor(strength),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFf44336);
      case PasswordStrength.medium:
        return const Color(0xFFff9800);
      case PasswordStrength.strong:
        return const Color(0xFF4caf50);
      case PasswordStrength.veryStrong:
        return const Color(0xFF2e7d32);
    }
  }
}
