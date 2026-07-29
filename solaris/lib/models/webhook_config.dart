import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:solaris/utils/key_obfuscator.dart';

/// Source of application state changes to track and prevent echo loops.
enum StateChangeSource {
  userGui, // User changed settings via Solaris GUI
  api, // Changed via REST or WebSocket API
  automation, // Automated calculation (Sun/Weather/Circadian)
  system, // System event (Game Mode, Power Resume)
}

/// Outbound Webhook Event Types (21 total events).
enum WebhookEventType {
  // Solar events
  onSunrise('on_sunrise'),
  onSunset('on_sunset'),
  onCivilTwilightBegin('on_civil_twilight_begin'),
  onCivilTwilightEnd('on_civil_twilight_end'),
  onGoldenHourBegin('on_golden_hour_begin'),
  onGoldenHourEnd('on_golden_hour_end'),
  onDayPhaseChanged('on_day_phase_changed'),

  // Weather & Location (Privacy-First)
  onWeatherUpdated('on_weather_updated'),
  onLocationChanged('on_location_changed'),

  // Control & Presets
  onBrightnessPresetChanged('on_brightness_preset_changed'),
  onTemperaturePresetChanged('on_temperature_preset_changed'),
  onAutoBrightnessToggled('on_auto_brightness_toggled'),
  onAutoTemperatureToggled('on_auto_temperature_toggled'),
  onBrightnessThresholdCrossed('on_brightness_threshold_crossed'),

  // Gaming Mode
  onGameModeActivated('on_game_mode_activated'),
  onGameModeDeactivated('on_game_mode_deactivated'),

  // Smart Circadian & Sleep
  onWindDownStarted('on_wind_down_started'),
  onSleepStatusChanged('on_sleep_status_changed'),

  // System & Hardware
  onMonitorConnected('on_monitor_connected'),
  onMonitorDisconnected('on_monitor_disconnected'),
  onApiServerStarted('on_api_server_started'),
  onSystemResume('on_system_resume'),
  onHardwareError('on_hardware_error');

  final String wireName;
  const WebhookEventType(this.wireName);

  static WebhookEventType? fromString(String name) {
    for (final val in WebhookEventType.values) {
      if (val.wireName == name || val.name == name) return val;
    }
    return null;
  }
}

/// Model representing an Outbound Webhook configuration.
class WebhookConfig {
  final String id;
  final String url;
  final String? name;
  final Set<WebhookEventType> events;
  final bool isEnabled;
  final String? secretKey;
  final Map<String, String>? customHeaders;
  final int failureCount;
  final DateTime? lastTriggeredAt;
  final DateTime createdAt;

  WebhookConfig({
    required this.id,
    required this.url,
    this.name,
    required this.events,
    this.isEnabled = true,
    this.secretKey,
    this.customHeaders,
    this.failureCount = 0,
    this.lastTriggeredAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  WebhookConfig copyWith({
    String? id,
    String? url,
    String? name,
    Set<WebhookEventType>? events,
    bool? isEnabled,
    String? secretKey,
    Map<String, String>? customHeaders,
    int? failureCount,
    DateTime? lastTriggeredAt,
    DateTime? createdAt,
    bool clearSecretKey = false,
    bool clearCustomHeaders = false,
  }) {
    return WebhookConfig(
      id: id ?? this.id,
      url: url ?? this.url,
      name: name ?? this.name,
      events: events ?? this.events,
      isEnabled: isEnabled ?? this.isEnabled,
      secretKey: clearSecretKey ? null : (secretKey ?? this.secretKey),
      customHeaders: clearCustomHeaders
          ? null
          : (customHeaders ?? this.customHeaders),
      failureCount: failureCount ?? this.failureCount,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, String>? encryptedHeaders = customHeaders?.map(
      (k, v) => MapEntry(k, v.isNotEmpty ? KeyObfuscator.encrypt(v) : v),
    );

    return {
      'id': id,
      'url': url,
      'name': name,
      'events': events.map((e) => e.wireName).toList(),
      'isEnabled': isEnabled,
      'secretKey': secretKey != null && secretKey!.isNotEmpty
          ? KeyObfuscator.encrypt(secretKey!)
          : secretKey,
      'customHeaders': encryptedHeaders,
      'failureCount': failureCount,
      'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory WebhookConfig.fromJson(Map<String, dynamic> json) {
    String? decryptedSecret = json['secretKey'] as String?;
    if (decryptedSecret != null && decryptedSecret.isNotEmpty) {
      try {
        decryptedSecret = KeyObfuscator.decrypt(decryptedSecret);
      } on DpapiPasswordChangedException catch (e) {
        debugPrint('DPAPI Password Changed for WebhookConfig secret: $e');
        decryptedSecret = null;
      } catch (e) {
        debugPrint('DPAPI Decrypt error for WebhookConfig secret: $e');
        decryptedSecret = null;
      }
    }

    Map<String, String>? decryptedHeaders;
    if (json['customHeaders'] != null) {
      final rawHeaders = json['customHeaders'] as Map<String, dynamic>;
      decryptedHeaders = {};
      rawHeaders.forEach((k, v) {
        final valStr = v.toString();
        if (valStr.isNotEmpty) {
          try {
            decryptedHeaders![k] = KeyObfuscator.decrypt(valStr);
          } on DpapiPasswordChangedException {
            decryptedHeaders![k] = '';
          } catch (_) {
            decryptedHeaders![k] = valStr;
          }
        } else {
          decryptedHeaders![k] = '';
        }
      });
    }

    final eventsList =
        (json['events'] as List<dynamic>?)
            ?.map((e) => WebhookEventType.fromString(e.toString()))
            .whereType<WebhookEventType>()
            .toSet() ??
        <WebhookEventType>{};

    return WebhookConfig(
      id: json['id'] as String,
      url: json['url'] as String,
      name: json['name'] as String?,
      events: eventsList,
      isEnabled: json['isEnabled'] as bool? ?? true,
      secretKey: decryptedSecret,
      customHeaders: decryptedHeaders,
      failureCount: json['failureCount'] as int? ?? 0,
      lastTriggeredAt: json['lastTriggeredAt'] != null
          ? DateTime.tryParse(json['lastTriggeredAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'] as String) ??
                DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  /// Calculates HMAC-SHA256 signature for payload using secret key.
  String? calculateSignature(
    String deliveryId,
    String timestamp,
    String rawBody,
  ) {
    if (secretKey == null || secretKey!.isEmpty) return null;
    final payloadToSign = '$deliveryId.$timestamp.$rawBody';
    final hmac = Hmac(sha256, utf8.encode(secretKey!));
    final digest = hmac.convert(utf8.encode(payloadToSign));
    return 'sha256=$digest';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebhookConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          url == other.url &&
          isEnabled == other.isEnabled &&
          failureCount == other.failureCount;

  @override
  int get hashCode =>
      id.hashCode ^ url.hashCode ^ isEnabled.hashCode ^ failureCount.hashCode;
}
