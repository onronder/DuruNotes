import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for connectivity status
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Provider for current connectivity state
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (results) => results.contains(ConnectivityResult.none),
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Widget that displays an offline indicator when there's no internet connection
class OfflineIndicator extends ConsumerStatefulWidget {
  const OfflineIndicator({
    super.key,
    this.child,
    this.showBanner = true,
    this.showSnackbar = false,
    this.onOffline,
    this.onOnline,
  });

  final Widget? child;
  final bool showBanner;
  final bool showSnackbar;
  final VoidCallback? onOffline;
  final VoidCallback? onOnline;

  @override
  ConsumerState<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends ConsumerState<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _wasOffline = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _handleConnectivityChange(bool isOffline) {
    if (isOffline && !_wasOffline) {
      // Just went offline
      _animationController.forward();
      widget.onOffline?.call();

      if (widget.showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('No internet connection'),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Start reconnection attempts
      _startReconnectTimer();
    } else if (!isOffline && _wasOffline) {
      // Just came online
      _animationController.reverse();
      widget.onOnline?.call();

      if (widget.showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi, color: Colors.white),
                SizedBox(width: 12),
                Text('Back online'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Cancel reconnection timer
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
    }

    _wasOffline = isOffline;
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _reconnectAttempts++;

      // Check connectivity
      Connectivity().checkConnectivity().then((results) {
        if (!results.contains(ConnectivityResult.none)) {
          // We're back online
          timer.cancel();
          _reconnectAttempts = 0;
        } else if (_reconnectAttempts > 12) {
          // Stop checking after 1 minute
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);

    // Handle connectivity changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleConnectivityChange(isOffline);
    });

    if (widget.child != null) {
      return Stack(
        children: [
          widget.child!,
          if (widget.showBanner && isOffline)
            Positioned(top: 0, left: 0, right: 0, child: _buildBanner(context)),
        ],
      );
    }

    // If no child provided, just show the banner when offline
    if (widget.showBanner && isOffline) {
      return _buildBanner(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_animation),
      child: Material(
        elevation: 4,
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.orange.shade800 : Colors.orange.shade600,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No internet connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_reconnectAttempts > 0)
                Text(
                  'Retrying... ($_reconnectAttempts)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A simple offline badge widget
class OfflineBadge extends ConsumerWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    if (!isOffline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
