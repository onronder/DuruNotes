import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:duru_notes/core/feature_flags.dart';
import 'package:duru_notes/core/monitoring/app_logger.dart';
import 'package:duru_notes/services/analytics/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission types that can be requested
enum PermissionType {
  notification,
  location,
  locationAlways,
  microphone,
  camera,
  storage,
  photos,
}

/// Status of a permission request
enum PermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
  unknown,
}

/// Unified permission manager for the entire application
/// 
/// This singleton class centralizes all permission handling,
/// providing a consistent interface for requesting and checking permissions
/// across different platforms and permission types.
class PermissionManager {
  PermissionManager._();
  
  // Singleton instance
  static final PermissionManager instance = PermissionManager._();
  
  // Dependencies
  final AppLogger _logger = LoggerFactory.instance;
  final AnalyticsService _analytics = AnalyticsFactory.instance;
  final FeatureFlags _featureFlags = FeatureFlags.instance;
  
  // Cache for permission statuses to avoid repeated checks
  final Map<PermissionType, PermissionStatus> _permissionCache = {};
  
  // Stream controllers for permission observers
  final Map<PermissionType, List<Function(PermissionStatus)>> _observers = {};
  
  /// Request a specific permission type
  Future<PermissionStatus> request(PermissionType type) async {
    // Check if we should use the unified permission manager
    if (!_featureFlags.useUnifiedPermissionManager) {
      // Fall back to legacy implementation
      return _legacyRequest(type);
    }
    
    try {
      _analytics.startTiming('permission_request');
      
      PermissionStatus status;
      
      switch (type) {
        case PermissionType.notification:
          status = await _requestNotifications();
          break;
        case PermissionType.location:
          status = await _requestLocation();
          break;
        case PermissionType.locationAlways:
          status = await _requestLocationAlways();
          break;
        case PermissionType.microphone:
          status = await _requestMicrophone();
          break;
        case PermissionType.camera:
          status = await _requestCamera();
          break;
        case PermissionType.storage:
          status = await _requestStorage();
          break;
        case PermissionType.photos:
          status = await _requestPhotos();
          break;
      }
      
      // Update cache
      _permissionCache[type] = status;
      
      // Notify observers
      _notifyObservers(type, status);
      
      _analytics.endTiming(
        'permission_request',
        properties: {
          'type': type.name,
          'status': status.name,
          'success': status == PermissionStatus.granted,
        },
      );
      
      _analytics.event(
        'permission_requested',
        properties: {
          'type': type.name,
          'granted': status == PermissionStatus.granted,
          'status': status.name,
        },
      );
      
      return status;
    } catch (e, stack) {
      _logger.error(
        'Failed to request permission',
        error: e,
        stackTrace: stack,
        data: {'type': type.name},
      );
      
      _analytics.endTiming(
        'permission_request',
        properties: {
          'type': type.name,
          'success': false,
          'error': e.toString(),
        },
      );
      
      return PermissionStatus.unknown;
    }
  }
  
  /// Check if a permission is granted
  Future<bool> hasPermission(PermissionType type) async {
    final status = await getStatus(type);
    return status == PermissionStatus.granted || 
           status == PermissionStatus.limited ||
           status == PermissionStatus.provisional;
  }
  
  /// Get the current status of a permission
  Future<PermissionStatus> getStatus(PermissionType type) async {
    // Check cache first
    if (_permissionCache.containsKey(type)) {
      return _permissionCache[type]!;
    }
    
    try {
      PermissionStatus status;
      
      switch (type) {
        case PermissionType.notification:
          status = await _getNotificationStatus();
          break;
        case PermissionType.location:
          status = await _getLocationStatus();
          break;
        case PermissionType.locationAlways:
          status = await _getLocationAlwaysStatus();
          break;
        case PermissionType.microphone:
          status = await _getMicrophoneStatus();
          break;
        case PermissionType.camera:
          status = await _getCameraStatus();
          break;
        case PermissionType.storage:
          status = await _getStorageStatus();
          break;
        case PermissionType.photos:
          status = await _getPhotosStatus();
          break;
      }
      
      // Update cache
      _permissionCache[type] = status;
      
      return status;
    } catch (e, stack) {
      _logger.error(
        'Failed to check permission status',
        error: e,
        stackTrace: stack,
        data: {'type': type.name},
      );
      return PermissionStatus.unknown;
    }
  }
  
  /// Observe permission status changes
  void observePermission(
    PermissionType type,
    Function(PermissionStatus) callback,
  ) {
    _observers[type] ??= [];
    _observers[type]!.add(callback);
  }
  
  /// Stop observing permission status changes
  void removeObserver(
    PermissionType type,
    Function(PermissionStatus) callback,
  ) {
    _observers[type]?.remove(callback);
  }
  
  /// Clear permission cache
  void clearCache() {
    _permissionCache.clear();
  }
  
  /// Open app settings for manual permission management
  Future<bool> openAppSettings() async {
    try {
      final opened = await ph.openAppSettings();
      
      _analytics.event('app_settings_opened', properties: {
        'reason': 'permission_management',
      });
      
      // Clear cache as permissions may have changed
      clearCache();
      
      return opened;
    } catch (e) {
      _logger.error('Failed to open app settings', error: e);
      return false;
    }
  }
  
  // Platform-specific permission handlers
  
  Future<PermissionStatus> _requestNotifications() async {
    if (Platform.isIOS) {
      return _requestIOSNotifications();
    }
    return _requestAndroidNotifications();
  }
  
  Future<PermissionStatus> _requestIOSNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final result = await plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    
    if (result == true) {
      return PermissionStatus.granted;
    } else if (result == false) {
      return PermissionStatus.denied;
    }
    return PermissionStatus.unknown;
  }
  
  Future<PermissionStatus> _requestAndroidNotifications() async {
    final status = await ph.Permission.notification.request();
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _requestLocation() async {
    final status = await ph.Permission.location.request();
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _requestLocationAlways() async {
    // First ensure we have basic location permission
    final basicStatus = await ph.Permission.location.status;
    if (!basicStatus.isGranted) {
      await ph.Permission.location.request();
    }
    
    final status = await ph.Permission.locationAlways.request();
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _requestMicrophone() async {
    final status = await ph.Permission.microphone.request();
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _requestCamera() async {
    final status = await ph.Permission.camera.request();
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _requestStorage() async {
    if (Platform.isAndroid) {
      // Android 13+ uses different permissions
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt >= 33) {
        // Use media permissions instead
        return await _requestPhotos();
      }
    }
    
    final status = await ph.Permission.storage.request();
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _requestPhotos() async {
    final status = await ph.Permission.photos.request();
    return _convertPermissionStatus(status);
  }
  
  // Status check methods
  
  Future<PermissionStatus> _getNotificationStatus() async {
    if (Platform.isIOS) {
      // iOS doesn't provide a way to check notification status via permission_handler
      // Assume granted if app is running
      return PermissionStatus.granted;
    }
    
    final status = await ph.Permission.notification.status;
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _getLocationStatus() async {
    final status = await ph.Permission.location.status;
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _getLocationAlwaysStatus() async {
    final status = await ph.Permission.locationAlways.status;
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _getMicrophoneStatus() async {
    final status = await ph.Permission.microphone.status;
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _getCameraStatus() async {
    final status = await ph.Permission.camera.status;
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _getStorageStatus() async {
    final status = await ph.Permission.storage.status;
    return _convertPermissionStatus(status);
  }
  
  Future<PermissionStatus> _getPhotosStatus() async {
    final status = await ph.Permission.photos.status;
    return _convertPermissionStatus(status);
  }
  
  // Helper methods
  
  PermissionStatus _convertPermissionStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
        return PermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return PermissionStatus.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return PermissionStatus.restricted;
      case ph.PermissionStatus.limited:
        return PermissionStatus.limited;
      case ph.PermissionStatus.provisional:
        return PermissionStatus.provisional;
    }
  }
  
  void _notifyObservers(PermissionType type, PermissionStatus status) {
    final observers = _observers[type];
    if (observers != null) {
      for (final observer in observers) {
        observer(status);
      }
    }
  }
  
  // Legacy fallback for gradual migration
  
  Future<PermissionStatus> _legacyRequest(PermissionType type) async {
    // Fallback to direct permission_handler usage
    ph.Permission permission;
    
    switch (type) {
      case PermissionType.notification:
        permission = ph.Permission.notification;
        break;
      case PermissionType.location:
        permission = ph.Permission.location;
        break;
      case PermissionType.locationAlways:
        permission = ph.Permission.locationAlways;
        break;
      case PermissionType.microphone:
        permission = ph.Permission.microphone;
        break;
      case PermissionType.camera:
        permission = ph.Permission.camera;
        break;
      case PermissionType.storage:
        permission = ph.Permission.storage;
        break;
      case PermissionType.photos:
        permission = ph.Permission.photos;
        break;
    }
    
    final status = await permission.request();
    return _convertPermissionStatus(status);
  }
  
  /// Get a human-readable description for a permission type
  String getPermissionDescription(PermissionType type) {
    switch (type) {
      case PermissionType.notification:
        return 'Send you reminders and important updates';
      case PermissionType.location:
        return 'Create location-based reminders';
      case PermissionType.locationAlways:
        return 'Trigger reminders even when app is in background';
      case PermissionType.microphone:
        return 'Record audio notes and transcribe voice';
      case PermissionType.camera:
        return 'Scan documents and capture images';
      case PermissionType.storage:
        return 'Save and access your notes offline';
      case PermissionType.photos:
        return 'Attach images to your notes';
    }
  }
  
  /// Get an icon for a permission type
  IconData getPermissionIcon(PermissionType type) {
    switch (type) {
      case PermissionType.notification:
        return Icons.notifications;
      case PermissionType.location:
      case PermissionType.locationAlways:
        return Icons.location_on;
      case PermissionType.microphone:
        return Icons.mic;
      case PermissionType.camera:
        return Icons.camera_alt;
      case PermissionType.storage:
        return Icons.storage;
      case PermissionType.photos:
        return Icons.photo_library;
    }
  }
}

// Extension for easier permission checking
extension PermissionManagerExtensions on PermissionManager {
  /// Request multiple permissions at once
  Future<Map<PermissionType, PermissionStatus>> requestMultiple(
    List<PermissionType> types,
  ) async {
    final results = <PermissionType, PermissionStatus>{};
    
    for (final type in types) {
      results[type] = await request(type);
    }
    
    return results;
  }
  
  /// Check if all specified permissions are granted
  Future<bool> hasAllPermissions(List<PermissionType> types) async {
    for (final type in types) {
      if (!await hasPermission(type)) {
        return false;
      }
    }
    return true;
  }
}
