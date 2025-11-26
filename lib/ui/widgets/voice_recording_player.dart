import 'dart:async';

import 'package:duru_notes/providers/infrastructure_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// Widget for playing back voice recordings
///
/// Uses just_audio for streaming playback from Supabase Storage.
/// Tracks analytics events for play started and play completed.
class VoiceRecordingPlayer extends ConsumerStatefulWidget {
  const VoiceRecordingPlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    this.title,
  });

  final String audioUrl;
  final int durationSeconds;
  final String? title;

  @override
  ConsumerState<VoiceRecordingPlayer> createState() =>
      _VoiceRecordingPlayerState();
}

class _VoiceRecordingPlayerState extends ConsumerState<VoiceRecordingPlayer> {
  late final AudioPlayer _player;
  bool _hasPlayedOnce = false;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _player.setUrl(widget.audioUrl);

      setState(() {
        _isLoading = false;
      });

      // Listen for playback completion
      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _trackPlayCompleted();
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load audio';
      });
    }
  }

  void _trackPlayStarted() {
    if (!_hasPlayedOnce) {
      final analytics = ref.read(analyticsProvider);
      analytics.featureUsed(
        'voice_note_play_started',
        properties: {
          'duration_seconds': widget.durationSeconds,
          'has_title': widget.title != null,
        },
      );
      _hasPlayedOnce = true;
    }
  }

  void _trackPlayCompleted() {
    final analytics = ref.read(analyticsProvider);
    analytics.featureUsed(
      'voice_note_play_completed',
      properties: {'duration_seconds': widget.durationSeconds},
    );
  }

  Future<void> _togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      _trackPlayStarted();
      await _player.play();
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_errorMessage != null) {
      return _buildErrorState(theme);
    }

    if (_isLoading) {
      return _buildLoadingState(theme);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title (if provided)
          if (widget.title != null) ...[
            Text(
              widget.title!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Player controls
          Row(
            children: [
              // Play/Pause button
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playerState = snapshot.data;
                  final isPlaying = playerState?.playing ?? false;
                  final processingState = playerState?.processingState;

                  IconData iconData;
                  if (processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering) {
                    iconData = Icons.hourglass_empty;
                  } else if (isPlaying) {
                    iconData = Icons.pause;
                  } else {
                    iconData = Icons.play_arrow;
                  }

                  return IconButton(
                    icon: Icon(iconData),
                    iconSize: 32,
                    color: theme.colorScheme.primary,
                    onPressed:
                        (processingState == ProcessingState.loading ||
                            processingState == ProcessingState.buffering)
                        ? null
                        : _togglePlayPause,
                  );
                },
              ),

              // Progress bar
              Expanded(
                child: StreamBuilder<Duration?>(
                  stream: _player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration =
                        _player.duration ??
                        Duration(seconds: widget.durationSeconds);

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                          ),
                          child: Slider(
                            value: position.inMilliseconds.toDouble(),
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (value) async {
                              await _player.seek(
                                Duration(milliseconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontFeatures: [
                                    const FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontFeatures: [
                                    const FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Text('Loading audio...', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Failed to load audio',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
