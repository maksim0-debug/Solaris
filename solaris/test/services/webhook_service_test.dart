import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/services/ssrf_validator.dart';
import 'package:solaris/services/webhook_service.dart';

void main() {
  group('Phase 4: Webhook Engine & SSRF Protection Tests', () {
    group('SsrfValidator Unit Tests', () {
      test('Loopback IPv4 & IPv6 are strictly blocked', () {
        expect(SsrfValidator.isBlockedIp(InternetAddress('127.0.0.1')), isTrue);
        expect(
          SsrfValidator.isBlockedIp(InternetAddress('127.0.0.255')),
          isTrue,
        );
        expect(SsrfValidator.isBlockedIp(InternetAddress('::1')), isTrue);
      });

      test('Cloud metadata 169.254.169.254 is strictly blocked', () {
        expect(
          SsrfValidator.isBlockedIp(InternetAddress('169.254.169.254')),
          isTrue,
        );
      });

      test('IPv4-Mapped IPv6 loopback is correctly normalized and blocked', () {
        expect(
          SsrfValidator.isBlockedIp(InternetAddress('::ffff:127.0.0.1')),
          isTrue,
        );
      });

      test(
        'LAN IPs are allowed for webhooks when allowLanWebhooks is true',
        () {
          expect(
            SsrfValidator.isBlockedIp(
              InternetAddress('192.168.1.100'),
              targetType: SsrfValidationTarget.webhook,
              allowLanWebhooks: true,
            ),
            isFalse,
          );
          expect(
            SsrfValidator.isBlockedIp(
              InternetAddress('10.0.0.5'),
              targetType: SsrfValidationTarget.webhook,
              allowLanWebhooks: true,
            ),
            isFalse,
          );
          expect(
            SsrfValidator.isBlockedIp(
              InternetAddress('172.16.0.10'),
              targetType: SsrfValidationTarget.webhook,
              allowLanWebhooks: true,
            ),
            isFalse,
          );
        },
      );

      test(
        'LAN IPs are blocked when strict targetType or allowLanWebhooks is false',
        () {
          expect(
            SsrfValidator.isBlockedIp(
              InternetAddress('192.168.1.100'),
              targetType: SsrfValidationTarget.strict,
            ),
            isTrue,
          );
          expect(
            SsrfValidator.isBlockedIp(
              InternetAddress('192.168.1.100'),
              targetType: SsrfValidationTarget.webhook,
              allowLanWebhooks: false,
            ),
            isTrue,
          );
        },
      );

      test('Public IP addresses are allowed', () {
        expect(SsrfValidator.isBlockedIp(InternetAddress('8.8.8.8')), isFalse);
        expect(SsrfValidator.isBlockedIp(InternetAddress('1.1.1.1')), isFalse);
      });
    });

    group('WebhookConfig Model & HMAC Signature Tests', () {
      test('WebhookEventType correctly maps wire names', () {
        expect(WebhookEventType.onSunrise.wireName, equals('on_sunrise'));
        expect(WebhookEventType.onSunset.wireName, equals('on_sunset'));
        expect(
          WebhookEventType.onGameModeActivated.wireName,
          equals('on_game_mode_activated'),
        );

        expect(
          WebhookEventType.fromString('on_sunrise'),
          equals(WebhookEventType.onSunrise),
        );
        expect(
          WebhookEventType.fromString('on_game_mode_activated'),
          equals(WebhookEventType.onGameModeActivated),
        );
      });

      test('HMAC-SHA256 signature is correctly computed', () {
        final config = WebhookConfig(
          id: 'test_wh_1',
          url: 'https://homeassistant.local:8123/api/webhook/solaris',
          events: {WebhookEventType.onSunset},
          secretKey: 'my_secret_key_123',
        );

        final signature = config.calculateSignature(
          'deliv-101',
          '2026-07-24T05:00:00Z',
          '{"event":"on_sunset"}',
        );

        expect(signature, isNotNull);
        expect(signature, startsWith('sha256='));
      });

      test('HMAC signature returns null if secretKey is missing', () {
        final config = WebhookConfig(
          id: 'test_wh_2',
          url: 'https://example.com/webhook',
          events: {WebhookEventType.onSunrise},
          secretKey: null,
        );

        final signature = config.calculateSignature(
          'deliv-102',
          '2026-07-24T05:00:00Z',
          '{"event":"on_sunrise"}',
        );

        expect(signature, isNull);
      });

      test('WebhookConfig JSON serialization round-trip', () {
        final config = WebhookConfig(
          id: 'wh_test_999',
          url: 'https://n8n.local/webhook/test',
          name: 'n8n Workflow',
          events: {WebhookEventType.onSunrise, WebhookEventType.onSunset},
          isEnabled: true,
          secretKey: 'secret_val_123',
          customHeaders: {'Authorization': 'Bearer test_token'},
        );

        final jsonMap = config.toJson();
        expect(jsonMap['id'], equals('wh_test_999'));
        expect(jsonMap['url'], equals('https://n8n.local/webhook/test'));
        expect(jsonMap['events'], contains('on_sunrise'));

        final restored = WebhookConfig.fromJson(jsonMap);
        expect(restored.id, equals(config.id));
        expect(restored.url, equals(config.url));
        expect(restored.name, equals(config.name));
        expect(restored.events, contains(WebhookEventType.onSunrise));
        expect(restored.events, contains(WebhookEventType.onSunset));
      });
    });

    group('PendingWebhookTransaction Tests', () {
      test('PendingWebhookTransaction JSON serialization', () {
        final tx = PendingWebhookTransaction(
          deliveryId: 'deliv-xyz',
          webhookId: 'wh-123',
          url: 'https://node-red.local/solaris',
          eventName: 'on_sunset',
          payloadJson: '{"event":"on_sunset"}',
        );

        final jsonMap = tx.toJson();
        expect(jsonMap['deliveryId'], equals('deliv-xyz'));
        expect(jsonMap['eventName'], equals('on_sunset'));

        final restored = PendingWebhookTransaction.fromJson(jsonMap);
        expect(restored.deliveryId, equals(tx.deliveryId));
        expect(restored.url, equals(tx.url));
        expect(restored.status, equals(TransactionStatus.pending));
      });
    });
  });
}
