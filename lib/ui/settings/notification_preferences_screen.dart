import 'dart:async';

import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/core/providers/infrastructure_providers.dart'
    show loggerProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen for managing notification preferences
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  AppLogger get _logger => ref.read(loggerProvider);
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic> _preferences = {};

  // Default preferences
  bool _notificationsEnabled = true;
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietHoursStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietHoursEnd = const TimeOfDay(hour: 7, minute: 0);
  bool _dndEnabled = false;

  // Event preferences
  final Map<String, bool> _eventPreferences = {
    'email_received': true,
    'web_clip_saved': true,
    'note_shared': true,
    'reminder_due': true,
    'note_mentioned': true,
    'folder_shared': true,
    'sync_conflict': true,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('notification_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        if (!mounted) return;
        setState(() {
          _preferences = response;
          _notificationsEnabled = (response['enabled'] as bool?) ?? true;
          _pushEnabled = (response['push_enabled'] as bool?) ?? true;
          _emailEnabled = (response['email_enabled'] as bool?) ?? false;
          _quietHoursEnabled =
              (response['quiet_hours_enabled'] as bool?) ?? false;
          _dndEnabled = (response['dnd_enabled'] as bool?) ?? false;

          // Parse quiet hours
          if (response['quiet_hours_start'] != null) {
            final timeStr = response['quiet_hours_start'] as String;
            final parts = timeStr.split(':');
            _quietHoursStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }

          if (response['quiet_hours_end'] != null) {
            final timeStr = response['quiet_hours_end'] as String;
            final parts = timeStr.split(':');
            _quietHoursEnd = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }

          // Parse event preferences
          final eventPrefs =
              response['event_preferences'] as Map<String, dynamic>? ?? {};
          eventPrefs.forEach((key, value) {
            if (_eventPreferences.containsKey(key) && value is Map) {
              _eventPreferences[key] = (value['enabled'] as bool?) ?? true;
            }
          });
        });
        _logger.info(
          'Notification preferences loaded',
          data: {
            'hasQuietHours': _quietHoursEnabled,
            'dndEnabled': _dndEnabled,
            'eventPreferenceCount': _eventPreferences.length,
          },
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to load notification preferences',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      _showErrorSnackBar(
        'We could not load your notification preferences. Please try again.',
        onRetry: () => unawaited(_loadPreferences()),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _savePreferences() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Build event preferences object
      final eventPrefs = <String, dynamic>{};
      _eventPreferences.forEach((key, value) {
        eventPrefs[key] = {'enabled': value};
      });

      final data = {
        'user_id': user.id,
        'enabled': _notificationsEnabled,
        'push_enabled': _pushEnabled,
        'email_enabled': _emailEnabled,
        'quiet_hours_enabled': _quietHoursEnabled,
        'quiet_hours_start':
            '${_quietHoursStart.hour.toString().padLeft(2, '0')}:${_quietHoursStart.minute.toString().padLeft(2, '0')}',
        'quiet_hours_end':
            '${_quietHoursEnd.hour.toString().padLeft(2, '0')}:${_quietHoursEnd.minute.toString().padLeft(2, '0')}',
        'dnd_enabled': _dndEnabled,
        'event_preferences': eventPrefs,
        'timezone': DateTime.now().timeZoneName,
      };

      if (_preferences.isEmpty) {
        // Insert new preferences
        await _supabase.from('notification_preferences').insert(data);
      } else {
        // Update existing preferences
        await _supabase
            .from('notification_preferences')
            .update(data)
            .eq('user_id', user.id);
      }

      _logger.info(
        'Notification preferences saved',
        data: {
          'notificationsEnabled': _notificationsEnabled,
          'pushEnabled': _pushEnabled,
          'emailEnabled': _emailEnabled,
          'quietHoursEnabled': _quietHoursEnabled,
          'dndEnabled': _dndEnabled,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved successfully')),
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'Failed to save notification preferences',
        error: error,
        stackTrace: stackTrace,
        data: {
          'notificationsEnabled': _notificationsEnabled,
          'pushEnabled': _pushEnabled,
          'emailEnabled': _emailEnabled,
          'quietHoursEnabled': _quietHoursEnabled,
          'dndEnabled': _dndEnabled,
        },
      );
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      _showErrorSnackBar(
        'Unable to save your notification preferences. Please try again.',
        onRetry: () => unawaited(_savePreferences()),
      );
    }
  }

  void _showErrorSnackBar(String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietHoursStart : _quietHoursEnd,
    );

    if (time != null) {
      setState(() {
        if (isStart) {
          _quietHoursStart = time;
        } else {
          _quietHoursEnd = time;
        }
      });
      _savePreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _savePreferences),
        ],
      ),
      body: ListView(
        children: [
          // Master toggle
          _buildSection(
            title: 'Notifications',
            children: [
              SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive notifications from DuruNotes'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _savePreferences();
                },
              ),
            ],
          ),

          // Delivery channels
          _buildSection(
            title: 'Delivery Channels',
            children: [
              SwitchListTile(
                title: const Text('Push Notifications'),
                subtitle: const Text(
                  'Receive push notifications on this device',
                ),
                value: _pushEnabled,
                onChanged: _notificationsEnabled
                    ? (value) {
                        setState(() => _pushEnabled = value);
                        _savePreferences();
                      }
                    : null,
              ),
              SwitchListTile(
                title: const Text('Email Notifications'),
                subtitle: const Text('Receive notifications via email'),
                value: _emailEnabled,
                onChanged: _notificationsEnabled
                    ? (value) {
                        setState(() => _emailEnabled = value);
                        _savePreferences();
                      }
                    : null,
              ),
            ],
          ),

          // Event types
          _buildSection(
            title: 'Notification Types',
            children: [
              _buildEventToggle(
                'Email Received',
                'email_received',
                'New emails in your inbox',
              ),
              _buildEventToggle(
                'Web Clips',
                'web_clip_saved',
                'Web pages saved to your notes',
              ),
              _buildEventToggle(
                'Shared Notes',
                'note_shared',
                'Notes shared with you',
              ),
              _buildEventToggle('Reminders', 'reminder_due', 'Note reminders'),
              _buildEventToggle(
                'Mentions',
                'note_mentioned',
                'When someone mentions you',
              ),
              _buildEventToggle(
                'Shared Folders',
                'folder_shared',
                'Folders shared with you',
              ),
              _buildEventToggle(
                'Sync Conflicts',
                'sync_conflict',
                'Sync conflict notifications',
              ),
            ],
          ),

          // Quiet hours
          _buildSection(
            title: 'Quiet Hours',
            children: [
              SwitchListTile(
                title: const Text('Enable Quiet Hours'),
                subtitle: const Text(
                  'Pause notifications during specific hours',
                ),
                value: _quietHoursEnabled,
                onChanged: _notificationsEnabled
                    ? (value) {
                        setState(() => _quietHoursEnabled = value);
                        _savePreferences();
                      }
                    : null,
              ),
              if (_quietHoursEnabled && _notificationsEnabled) ...[
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(_quietHoursStart.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(true),
                ),
                ListTile(
                  title: const Text('End Time'),
                  subtitle: Text(_quietHoursEnd.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectTime(false),
                ),
              ],
            ],
          ),

          // Do Not Disturb
          _buildSection(
            title: 'Do Not Disturb',
            children: [
              SwitchListTile(
                title: const Text('Do Not Disturb'),
                subtitle: const Text('Temporarily disable all notifications'),
                value: _dndEnabled,
                onChanged: _notificationsEnabled
                    ? (value) async {
                        setState(() => _dndEnabled = value);

                        if (value) {
                          // Show duration picker
                          final duration = await showDialog<Duration>(
                            context: context,
                            builder: (context) => _DndDurationDialog(),
                          );

                          if (duration != null) {
                            final until = DateTime.now().add(duration);
                            await _supabase
                                .from('notification_preferences')
                                .update({
                              'dnd_enabled': true,
                              'dnd_until': until.toIso8601String(),
                            }).eq('user_id', _supabase.auth.currentUser!.id);
                          } else {
                            setState(() => _dndEnabled = false);
                          }
                        } else {
                          await _supabase
                              .from('notification_preferences')
                              .update({
                            'dnd_enabled': false,
                            'dnd_until': null
                          }).eq('user_id', _supabase.auth.currentUser!.id);
                        }
                      }
                    : null,
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ...children,
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildEventToggle(String title, String eventType, String subtitle) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: _eventPreferences[eventType] ?? true,
      onChanged: _notificationsEnabled
          ? (value) {
              setState(() => _eventPreferences[eventType] = value);
              _savePreferences();
            }
          : null,
    );
  }
}

/// Dialog for selecting Do Not Disturb duration
class _DndDurationDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Do Not Disturb Duration'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 1)),
          child: const Text('1 hour'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 2)),
          child: const Text('2 hours'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 4)),
          child: const Text('4 hours'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(hours: 8)),
          child: const Text('8 hours'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(days: 1)),
          child: const Text('Until tomorrow'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, const Duration(days: 7)),
          child: const Text('1 week'),
        ),
      ],
    );
  }
}
