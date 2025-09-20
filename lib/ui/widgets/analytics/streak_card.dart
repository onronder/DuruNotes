import 'package:flutter/material.dart';

/// Card widget for displaying streak information
class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  
  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Productivity Streak',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStreakItem(
                    context,
                    'Current',
                    currentStreak,
                    Colors.orange,
                    true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStreakItem(
                    context,
                    'Longest',
                    longestStreak,
                    Colors.blue,
                    false,
                  ),
                ),
              ],
            ),
            if (currentStreak > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: currentStreak / (longestStreak > 0 ? longestStreak : 1),
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: 8,
              ),
              const SizedBox(height: 8),
              Text(
                _getStreakMessage(currentStreak, longestStreak),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStreakItem(
    BuildContext context,
    String label,
    int days,
    Color color,
    bool isHighlighted,
  ) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            days.toString(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            days == 1 ? 'day' : 'days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getStreakMessage(int current, int longest) {
    if (current == 0) {
      return 'Start completing tasks to build your streak!';
    } else if (current >= longest) {
      return '🎉 You\'re on your longest streak ever!';
    } else if (current >= longest * 0.8) {
      return 'Almost at your record! Keep going!';
    } else if (current >= 7) {
      return 'Great job! You\'re on a roll!';
    } else {
      return 'Keep it up! Consistency is key.';
    }
  }
}
