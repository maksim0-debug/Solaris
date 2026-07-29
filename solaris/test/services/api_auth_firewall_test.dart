import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/windows_firewall_service.dart';

void main() {
  group('Phase 3: Auth, CSWSH Guard & Firewall Tests', () {
    late ApiRouter router;

    setUp(() {
      router = ApiRouter();
      router.expectedToken = 'sol_test_secret_token_987654321';
      router.requireLocalToken = true;
      router.isLanEnabled = false;
    });

    group('Constant-Time Auth & Non-Empty Token Guard', () {
      test('constantTimeEquals correctly validates matching tokens', () {
        expect(
          constantTimeEquals(
            'sol_test_secret_token_987654321',
            'sol_test_secret_token_987654321',
          ),
          isTrue,
        );
      });

      test('constantTimeEquals rejects mismatched tokens', () {
        expect(
          constantTimeEquals(
            'invalid_token',
            'sol_test_secret_token_987654321',
          ),
          isFalse,
        );
        expect(
          constantTimeEquals(
            'sol_test_secret_token_98765432',
            'sol_test_secret_token_987654321',
          ),
          isFalse,
        );
      });

      test(
        'Non-Empty Token Guard rejects empty inputs or empty expected token',
        () {
          expect(
            constantTimeEquals('', 'sol_test_secret_token_987654321'),
            isFalse,
          );
          expect(
            constantTimeEquals('sol_test_secret_token_987654321', ''),
            isFalse,
          );
          expect(constantTimeEquals('', ''), isFalse);
        },
      );
    });

    group('WindowsFirewallService Unit Tests', () {
      final firewallService = WindowsFirewallService();

      test('getRuleName formats correct prefix and port', () {
        expect(
          WindowsFirewallService.getRuleName(45321),
          equals('Solaris_Control_API_Port_45321'),
        );
        expect(
          WindowsFirewallService.getRuleName(45322),
          equals('Solaris_Control_API_Port_45322'),
        );
      });

      test('isRuleConfigured executes cleanly without exceptions', () async {
        final result = await firewallService.isRuleConfigured(port: 45321);
        expect(result, isA<bool>());
      });

      test(
        'ensureRuleAdded on Windows handles non-elevated environment gracefully',
        () async {
          final result = await firewallService.ensureRuleAdded(port: 45321);
          expect(result, isA<bool>());
        },
      );
    });
  });
}
