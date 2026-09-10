import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static String get apiBaseUrl {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    final fallbackUrl = defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';
    final value = configuredUrl.trim().isEmpty
        ? fallbackUrl
        : configuredUrl.trim();
    final uri = Uri.tryParse(value);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw StateError('API_BASE_URL은 올바른 http(s) URL이어야 합니다.');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw StateError('API_BASE_URL은 http 또는 https URL이어야 합니다.');
    }

    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}
