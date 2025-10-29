import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all application errors.
///
/// This sealed class hierarchy provides type-safe error handling
/// throughout the application with proper context and debugging information.
sealed class AppError {
  const AppError({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
    this.context,
  });

  /// A human-readable error message.
  final String message;

  /// An optional error code for programmatic handling.
  final String? code;

  /// The original error that caused this error, if any.
  final Object? originalError;

  /// The stack trace at the point of error, if available.
  final StackTrace? stackTrace;

  /// Additional context data for debugging.
  final Map<String, dynamic>? context;

  /// Returns true if this error is recoverable (can be retried).
  bool get isRecoverable => true;

  /// Returns a user-friendly message for display in the UI.
  String get userMessage => message;

  /// Converts the error to a loggable format.
  Map<String, dynamic> toLogData() {
    return {
      'type': runtimeType.toString(),
      'message': message,
      if (code != null) 'code': code,
      if (context != null) ...context!,
      if (originalError != null) 'originalError': originalError.toString(),
    };
  }

  @override
  String toString() =>
      '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

/// Network-related errors (API calls, connectivity issues).
class NetworkError extends AppError {
  const NetworkError({
    required super.message,
    this.statusCode,
    this.responseBody,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  /// Create NetworkError from PostgrestException
  factory NetworkError.fromPostgrestException(
    PostgrestException e, [
    StackTrace? stackTrace,
  ]) {
    final statusCode = int.tryParse(e.code ?? '');
    return NetworkError(
      message: e.message,
      code: e.code,
      statusCode: statusCode,
      responseBody: e.details?.toString(),
      originalError: e,
      stackTrace: stackTrace,
    );
  }

  /// The HTTP status code, if applicable.
  final int? statusCode;

  /// The response body, if available.
  final String? responseBody;

  @override
  bool get isRecoverable => statusCode != 404 && statusCode != 401;

  @override
  String get userMessage {
    if (statusCode == 404) return 'The requested resource was not found';
    if (statusCode == 500) return 'Server error. Please try again later';
    if (statusCode == 503) return 'Service temporarily unavailable';
    if (originalError.toString().contains('SocketException')) {
      return 'No internet connection. Please check your network';
    }
    return 'Network error. Please try again';
  }
}

/// Authentication and authorization errors.
class AuthError extends AppError {
  const AuthError({
    required super.message,
    required this.type,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  /// Creates an AuthError from a Supabase AuthException.
  factory AuthError.fromAuthException(AuthException e, [StackTrace? stack]) {
    final lower = e.message.toLowerCase();
    var type = AuthErrorType.unauthorized;

    if (lower.contains('weak') ||
        lower.contains('pwned') ||
        lower.contains('choose a different one')) {
      type = AuthErrorType.weakPassword;
    } else if (lower.contains('invalid login')) {
      type = AuthErrorType.invalidCredentials;
    } else if (lower.contains('expired')) {
      type = AuthErrorType.sessionExpired;
    } else if (lower.contains('not verified')) {
      type = AuthErrorType.emailNotVerified;
    } else if (lower.contains('too many')) {
      type = AuthErrorType.tooManyAttempts;
    }

    return AuthError(
      message: e.message,
      type: type,
      code: e.statusCode,
      originalError: e,
      stackTrace: stack,
    );
  }

  /// The type of auth error.
  final AuthErrorType type;

  @override
  bool get isRecoverable => type != AuthErrorType.invalidCredentials;

  @override
  String get userMessage {
    switch (type) {
      case AuthErrorType.invalidCredentials:
        return 'Invalid email or password';
      case AuthErrorType.sessionExpired:
        return 'Your session has expired. Please sign in again';
      case AuthErrorType.unauthorized:
        return 'You are not authorized to perform this action';
      case AuthErrorType.emailNotVerified:
        return 'Please verify your email address';
      case AuthErrorType.tooManyAttempts:
        return 'Too many attempts. Please try again later';
      case AuthErrorType.weakPassword:
        return 'Password too weak. Use at least 12 characters with letters, numbers, and symbols.';
    }
  }
}

/// Types of authentication errors.
enum AuthErrorType {
  invalidCredentials,
  sessionExpired,
  unauthorized,
  emailNotVerified,
  tooManyAttempts,
  weakPassword,
}

/// Validation errors for user input.
class ValidationError extends AppError {
  const ValidationError({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  /// Field-specific validation errors.
  final Map<String, List<String>>? fieldErrors;

  @override
  bool get isRecoverable => false;

  @override
  String get userMessage {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      final firstField = fieldErrors!.entries.first;
      final firstError = firstField.value.first;
      return firstError;
    }
    return message;
  }

  /// Checks if a specific field has errors.
  bool hasFieldError(String field) {
    return fieldErrors?.containsKey(field) ?? false;
  }

  /// Gets errors for a specific field.
  List<String> getFieldErrors(String field) {
    return fieldErrors?[field] ?? [];
  }
}

/// Storage-related errors (file operations, database).
class StorageError extends AppError {
  const StorageError({
    required super.message,
    required this.type,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  /// The type of storage error.
  final StorageErrorType type;

  @override
  String get userMessage {
    switch (type) {
      case StorageErrorType.quotaExceeded:
        return 'Storage quota exceeded. Please free up some space';
      case StorageErrorType.fileNotFound:
        return 'File not found';
      case StorageErrorType.permissionDenied:
        return 'Permission denied to access storage';
      case StorageErrorType.corruptedData:
        return 'Data appears to be corrupted';
      case StorageErrorType.unsupportedFormat:
        return 'Unsupported file format';
    }
  }
}

/// Types of storage errors.
enum StorageErrorType {
  quotaExceeded,
  fileNotFound,
  permissionDenied,
  corruptedData,
  unsupportedFormat,
}

/// Rate limiting errors.
class RateLimitError extends AppError {
  const RateLimitError({
    required super.message,
    this.resetAt,
    this.retryAfter,
    this.limit,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  /// When the rate limit will be reset.
  final DateTime? resetAt;

  /// How long to wait before retrying.
  final Duration? retryAfter;

  /// The limit that was exceeded.
  final int? limit;

  @override
  bool get isRecoverable => true;

  @override
  String get userMessage {
    if (retryAfter != null) {
      final seconds = retryAfter!.inSeconds;
      if (seconds < 60) {
        return 'Too many requests. Please wait $seconds seconds';
      } else {
        final minutes = (seconds / 60).ceil();
        return 'Too many requests. Please wait $minutes minutes';
      }
    }
    return 'Too many requests. Please try again later';
  }
}

/// Timeout errors for long-running operations.
class TimeoutError extends AppError {
  const TimeoutError({
    required super.message,
    required this.timeout,
    required this.operation,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  /// The duration that was exceeded.
  final Duration timeout;

  /// The operation that timed out.
  final String operation;

  @override
  bool get isRecoverable => true;

  @override
  String get userMessage => 'Operation timed out. Please try again';
}

/// Errors that should not happen in normal operation.
class UnexpectedError extends AppError {
  const UnexpectedError({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  bool get isRecoverable => false;

  @override
  String get userMessage =>
      'An unexpected error occurred. Please try again or contact support';
}

/// Cancellation error for user-cancelled operations.
class CancellationError extends AppError {
  const CancellationError({
    super.message = 'Operation cancelled',
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  bool get isRecoverable => false;

  @override
  String get userMessage => 'Operation cancelled';
}

/// Helper class to create appropriate errors from exceptions.
class ErrorFactory {
  /// Creates an appropriate AppError from an exception.
  static AppError fromException(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) {
      return error;
    }

    if (error is PostgrestException) {
      return NetworkError.fromPostgrestException(error, stackTrace);
    }

    if (error is AuthException) {
      return AuthError.fromAuthException(error, stackTrace);
    }

    if (error is StorageException) {
      return StorageError(
        message: error.message,
        type: StorageErrorType.permissionDenied,
        code: error.statusCode,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Handle specific exception types
    if (error is SocketException) {
      return NetworkError(
        message: 'No internet connection',
        code: 'OFFLINE',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return TimeoutError(
        message: error.message ?? 'Operation timed out',
        timeout: error.duration ?? const Duration(seconds: 30),
        operation: 'network_request',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return ValidationError(
        message: 'Invalid data format: ${error.message}',
        originalError: error,
        stackTrace: stackTrace,
        context: {'field': 'data'},
      );
    }

    final errorString = error.toString();

    // Check for common error patterns in string representation
    if (errorString.contains('SocketException') ||
        errorString.contains('Connection refused')) {
      return NetworkError(
        message: 'Network connection failed',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('TimeoutException')) {
      return TimeoutError(
        message: 'Operation timed out',
        timeout: const Duration(seconds: 30),
        operation: 'unknown',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('rate limit') ||
        errorString.contains('429') ||
        errorString.contains('too many requests')) {
      return RateLimitError(
        message: 'Rate limit exceeded',
        retryAfter: const Duration(seconds: 60),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default to unexpected error
    return UnexpectedError(
      message: errorString,
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}
