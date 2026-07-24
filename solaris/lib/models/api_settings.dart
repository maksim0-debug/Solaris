import 'dart:io';

/// Value object representing API configuration settings.
class ApiSettings {
  final int port;
  final bool isLanAccessEnabled;
  final String accessToken;
  final int rateLimitPerMinute;

  const ApiSettings({
    this.port = 45321,
    this.isLanAccessEnabled = false,
    this.accessToken = '',
    this.rateLimitPerMinute = 120,
  });

  InternetAddress get bindAddress => isLanAccessEnabled
      ? InternetAddress.anyIPv4
      : InternetAddress.loopbackIPv4;

  ApiSettings copyWith({
    int? port,
    bool? isLanAccessEnabled,
    String? accessToken,
    int? rateLimitPerMinute,
  }) {
    return ApiSettings(
      port: port ?? this.port,
      isLanAccessEnabled: isLanAccessEnabled ?? this.isLanAccessEnabled,
      accessToken: accessToken ?? this.accessToken,
      rateLimitPerMinute: rateLimitPerMinute ?? this.rateLimitPerMinute,
    );
  }
}
