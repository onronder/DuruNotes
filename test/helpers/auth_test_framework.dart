/* COMMENTED OUT - 5 errors - uses old APIs
 * This class uses old models/APIs that no longer exist.
 * Needs rewrite to use new architecture.
 */

/*
/// Authentication testing framework for HMAC/JWT security testing
///
/// Provides utilities for testing authentication mechanisms including:
/// - HMAC signature generation and validation
/// - JWT token creation and verification
/// - Authentication flow testing
/// - Key rotation scenarios
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AuthTestFramework {
  /// Generate HMAC-SHA256 signature for testing
  static String generateTestHMAC(String secret, String message) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return base64.encode(digest.bytes);
  }

  /// Generate HMAC with timestamp for replay attack prevention
  static Map<String, String> generateTimestampedHMAC(
    String secret,
    String message, {
    DateTime? timestamp,
  }) {
    timestamp ??= DateTime.now();
    final timestampStr = timestamp.millisecondsSinceEpoch.toString();
    final fullMessage = '$message.$timestampStr';
    final signature = generateTestHMAC(secret, fullMessage);

    return {
      'signature': signature,
      'timestamp': timestampStr,
    };
  }

  /// Validate HMAC signature
  static bool validateHMAC(
    String secret,
    String message,
    String signature,
  ) {
    final expectedSignature = generateTestHMAC(secret, message);
    return _constantTimeCompare(expectedSignature, signature);
  }

  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Decode JWT token for testing (without signature verification)
  static Map<String, dynamic> decodeTestJWT(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid JWT format: expected 3 parts, got ${parts.length}');
    }

    // Decode header
    final headerJson = _decodeBase64Url(parts[0]);
    final header = json.decode(headerJson) as Map<String, dynamic>;

    // Decode payload
    final payloadJson = _decodeBase64Url(parts[1]);
    final payload = json.decode(payloadJson) as Map<String, dynamic>;

    return {
      'header': header,
      'payload': payload,
      'signature': parts[2],
    };
  }

  /// Decode base64url string
  static String _decodeBase64Url(String input) {
    String normalized = base64Url.normalize(input);
    return utf8.decode(base64Url.decode(normalized));
  }

  /// Create a test JWT token
  static String createTestJWT({
    required Map<String, dynamic> payload,
    required String secret,
    Map<String, dynamic>? header,
  }) {
    header ??= {
      'alg': 'HS256',
      'typ': 'JWT',
    };

    // Encode header
    final headerJson = json.encode(header);
    final headerBase64 = base64Url.encode(utf8.encode(headerJson));

    // Add standard claims if not present
    payload['iat'] ??= DateTime.now().millisecondsSinceEpoch ~/ 1000;
    payload['exp'] ??= DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

    // Encode payload
    final payloadJson = json.encode(payload);
    final payloadBase64 = base64Url.encode(utf8.encode(payloadJson));

    // Create signature
    final message = '$headerBase64.$payloadBase64';
    final key = utf8.encode(secret);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(utf8.encode(message));
    final signature = base64Url.encode(digest.bytes);

    return '$headerBase64.$payloadBase64.$signature';
  }

  /// Validate JWT expiration
  static bool isJWTExpired(Map<String, dynamic> jwtData) {
    final payload = jwtData['payload'] as Map<String, dynamic>;
    final exp = payload['exp'] as int?;

    if (exp == null) return false; // No expiration

    final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expirationTime);
  }

  /// Test authentication flow
  static Future<AuthTestResult> testAuthFlow({
    required String endpoint,
    required String method,
    required Map<String, String> headers,
    dynamic body,
    required Function(dynamic response) validator,
    Duration? timeout,
  }) async {
    final uri = Uri.parse(endpoint);
    final client = http.Client();

    try {
      final request = http.Request(method, uri);
      request.headers.addAll(headers);

      if (body != null) {
        if (body is Map || body is List) {
          request.headers['Content-Type'] = 'application/json';
          request.body = json.encode(body);
        } else {
          request.body = body.toString();
        }
      }

      final streamedResponse = await client.send(request).timeout(
            timeout ?? const Duration(seconds: 30),
          );

      final response = await http.Response.fromStream(streamedResponse);
      final responseData = response.statusCode >= 200 && response.statusCode < 300
          ? json.decode(response.body)
          : null;

      bool isValid = false;
      String? validationError;

      try {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          validator(responseData);
          isValid = true;
        }
      } catch (e) {
        validationError = e.toString();
      }

      return AuthTestResult(
        statusCode: response.statusCode,
        headers: response.headers,
        body: responseData,
        isValid: isValid,
        validationError: validationError,
        responseTime: streamedResponse.headers['x-response-time'],
      );
    } finally {
      client.close();
    }
  }

  /// Test HMAC key rotation
  static Future<bool> testKeyRotation({
    required String endpoint,
    required String oldKey,
    required String newKey,
    required String message,
  }) async {
    // Test with old key
    final oldSignature = generateTestHMAC(oldKey, message);
    final oldResult = await testAuthFlow(
      endpoint: endpoint,
      method: 'POST',
      headers: {
        'X-HMAC-Signature': oldSignature,
      },
      body: {'message': message},
      validator: (response) {
        if (response['status'] != 'success') {
          throw Exception('Old key rejected during rotation period');
        }
      },
    );

    // Test with new key
    final newSignature = generateTestHMAC(newKey, message);
    final newResult = await testAuthFlow(
      endpoint: endpoint,
      method: 'POST',
      headers: {
        'X-HMAC-Signature': newSignature,
      },
      body: {'message': message},
      validator: (response) {
        if (response['status'] != 'success') {
          throw Exception('New key rejected');
        }
      },
    );

    return oldResult.isValid && newResult.isValid;
  }

  /// Test rate limiting
  static Future<RateLimitTestResult> testRateLimit({
    required String endpoint,
    required Map<String, String> headers,
    required int requestCount,
    Duration? delay,
  }) async {
    final results = <AuthTestResult>[];
    int successCount = 0;
    int rateLimitedCount = 0;

    for (int i = 0; i < requestCount; i++) {
      final result = await testAuthFlow(
        endpoint: endpoint,
        method: 'GET',
        headers: headers,
        body: null,
        validator: (response) {},
      );

      results.add(result);

      if (result.statusCode == 200) {
        successCount++;
      } else if (result.statusCode == 429) {
        rateLimitedCount++;
      }

      if (delay != null && i < requestCount - 1) {
        await Future.delayed(delay);
      }
    }

    return RateLimitTestResult(
      totalRequests: requestCount,
      successfulRequests: successCount,
      rateLimitedRequests: rateLimitedCount,
      results: results,
    );
  }

  /// Generate test API key
  static String generateTestApiKey({
    String? prefix,
    int length = 32,
  }) {
    final random = List.generate(length, (i) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      return chars[(DateTime.now().millisecondsSinceEpoch + i) % chars.length];
    }).join();

    return prefix != null ? '$prefix$random' : random;
  }

  /// Test OAuth flow
  static Future<OAuthTestResult> testOAuthFlow({
    required String authorizationUrl,
    required String tokenUrl,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    String? scope,
  }) async {
    // This is a simplified OAuth test flow
    // In real tests, you'd need to handle the redirect and authorization code

    // Step 1: Build authorization URL
    final authUri = Uri.parse(authorizationUrl).replace(queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      if (scope != null) 'scope': scope,
    });

    // Step 2: Simulate token exchange (would need actual code in real test)
    final tokenResponse = await http.post(
      Uri.parse(tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': 'test_authorization_code',
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
      },
    );

    if (tokenResponse.statusCode == 200) {
      final tokenData = json.decode(tokenResponse.body);
      return OAuthTestResult(
        accessToken: tokenData['access_token'],
        refreshToken: tokenData['refresh_token'],
        expiresIn: tokenData['expires_in'],
        tokenType: tokenData['token_type'],
        scope: tokenData['scope'],
      );
    } else {
      throw Exception('OAuth token exchange failed: ${tokenResponse.statusCode}');
    }
  }
}

/// Result of an authentication test
class AuthTestResult {
  final int statusCode;
  final Map<String, String> headers;
  final dynamic body;
  final bool isValid;
  final String? validationError;
  final String? responseTime;

  AuthTestResult({
    required this.statusCode,
    required this.headers,
    this.body,
    required this.isValid,
    this.validationError,
    this.responseTime,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isRateLimited => statusCode == 429;
}

/// Result of rate limit testing
class RateLimitTestResult {
  final int totalRequests;
  final int successfulRequests;
  final int rateLimitedRequests;
  final List<AuthTestResult> results;

  RateLimitTestResult({
    required this.totalRequests,
    required this.successfulRequests,
    required this.rateLimitedRequests,
    required this.results,
  });

  double get successRate => successfulRequests / totalRequests * 100;
  double get rateLimitRate => rateLimitedRequests / totalRequests * 100;
}

/// Result of OAuth testing
class OAuthTestResult {
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String tokenType;
  final String? scope;

  OAuthTestResult({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
    required this.tokenType,
    this.scope,
  });
}*/
