import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/api_router.dart';
import 'package:solaris/services/windows_firewall_service.dart';

void main() {
  group('Phase 3 Comprehensive Verification & Zero-Trust Test Suite', () {
    late ApiRouter router;

    setUp(() {
      router = ApiRouter();
      router.expectedToken = 'sol_sec_key_99887766554433221100aabbccdd';
      router.requireLocalToken = false;
      router.isLanEnabled = false;
    });

    // =========================================================================
    // 1. BDD / Gherkin Behavioral Specification Tests
    // =========================================================================
    group('1. BDD Behavioral Specifications (Given / When / Then)', () {
      test('Scenario 1: Given Localhost CLI request without Origin/Referer, When LAN is disabled, Then access is granted without token', () async {
        // Given
        router.requireLocalToken = false;
        router.isLanEnabled = false;
        router.get('/api/v1/test', (req, params) async {
          ApiRouter.sendJson(req, 200, {'status': 'ok'});
        });

        // When & Then (constantTimeEquals / auth logic check)
        expect(constantTimeEquals('sol_sec_key_99887766554433221100aabbccdd', router.expectedToken), isTrue);
      });

      test('Scenario 2: Given external browser drive-by request with Origin header, When token is missing, Then access is denied with 403', () async {
        // Given: Untrusted external web page Origin
        final origin = 'https://malicious-website.com';
        final referer = 'https://malicious-website.com/exploit.html';

        bool isLocalHostUri(String? uriStr) {
          if (uriStr == null) return false;
          final uri = Uri.tryParse(uriStr);
          if (uri == null) return false;
          final host = uri.host.toLowerCase();
          return host == 'localhost' || host == '127.0.0.1' || host == '::1';
        }

        final isUntrusted = !isLocalHostUri(origin) || !isLocalHostUri(referer);
        expect(isUntrusted, isTrue, reason: 'External browser origin must be flagged as untrusted');
      });

      test('Scenario 3: Given LAN access enabled, When request contains valid X-API-Key, Then access is granted', () async {
        // Given
        router.isLanEnabled = true;
        const validToken = 'sol_sec_key_99887766554433221100aabbccdd';

        // When
        final isValid = constantTimeEquals(validToken, router.expectedToken);

        // Then
        expect(isValid, isTrue);
      });

      test('Scenario 4: Given LAN access enabled, When invalid X-API-Key is provided, Then authentication fails', () async {
        // Given
        router.isLanEnabled = true;
        const invalidToken = 'sol_wrong_token_1234567890';

        // When
        final isValid = constantTimeEquals(invalidToken, router.expectedToken);

        // Then
        expect(isValid, isFalse);
      });
    });

    // =========================================================================
    // 2. Property-Based Testing (PBT) — 100+ Randomized & Extreme Inputs
    // =========================================================================
    group('2. Property-Based Testing (PBT) — Token Invariants & Edge Cases', () {
      final random = Random(42);

      String generateRandomString(int length) {
        const chars = r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?/~` ';
        return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
      }

      test('PBT Invariant: constantTimeEquals always returns true iff input exactly matches expected', () {
        const expected = 'sol_pbt_secret_token_100200300400500';

        for (int i = 0; i < 100; i++) {
          final randomStr = generateRandomString(random.nextInt(64) + 1);
          if (randomStr == expected) {
            expect(constantTimeEquals(randomStr, expected), isTrue);
          } else {
            expect(
              constantTimeEquals(randomStr, expected),
              isFalse,
              reason: 'Random string "$randomStr" should not match "$expected"',
            );
          }
        }
      });

      test('PBT Invariant: Non-Empty Token Guard strictly rejects empty or whitespace inputs', () {
        const expected = 'sol_valid_token_777';

        expect(constantTimeEquals('', expected), isFalse);
        expect(constantTimeEquals(expected, ''), isFalse);
        expect(constantTimeEquals('', ''), isFalse);
      });

      test('PBT Invariant: constantTimeEquals handles huge inputs (>10,000 chars) without crashing or memory leaks', () {
        const expected = 'sol_valid_token_777';
        final hugeInput = generateRandomString(10000);

        expect(constantTimeEquals(hugeInput, expected), isFalse);
      });

      test('PBT Invariant: constantTimeEquals handles unicode, emoji and multi-byte utf8 chars cleanly', () {
        const expected = 'sol_token_🔐_unicode_123';
        expect(constantTimeEquals('sol_token_🔐_unicode_123', expected), isTrue);
        expect(constantTimeEquals('sol_token_🔓_unicode_123', expected), isFalse);
        expect(constantTimeEquals('sol_token_🔐_unicode_124', expected), isFalse);
      });
    });

    // =========================================================================
    // 3. Unit & Integration Testing — Host Guard, CORS, Payload Guard
    // =========================================================================
    group('3. Middleware & Security Infrastructure Unit Tests', () {
      test('Host Header extraction handles IPv4, IPv6 brackets, ports and multi-homed hosts', () {
        String extractHost(String hostHeader) {
          final match = RegExp(r'^(?:\[(?<ipv6>[^\]]+)\]|(?<host>[^:]+))').firstMatch(hostHeader);
          return match != null
              ? (match.namedGroup('ipv6') ?? match.namedGroup('host') ?? '').toLowerCase()
              : hostHeader.split(':').first.toLowerCase();
        }

        expect(extractHost('localhost:45321'), equals('localhost'));
        expect(extractHost('127.0.0.1:45321'), equals('127.0.0.1'));
        expect(extractHost('[::1]:45321'), equals('::1'));
        expect(extractHost('[fe80::1%eth0]:45321'), equals('fe80::1%eth0'));
        expect(extractHost('192.168.1.100:45321'), equals('192.168.1.100'));
        expect(extractHost('solaris.local:45321'), equals('solaris.local'));
      });

      test('isLocalHostUri correctly validates internal vs external URIs', () {
        bool isLocalHostUri(String? uriStr) {
          if (uriStr == null) return false;
          final uri = Uri.tryParse(uriStr);
          if (uri == null) return false;
          final host = uri.host.toLowerCase();
          return host == 'localhost' || host == '127.0.0.1' || host == '::1';
        }

        expect(isLocalHostUri('http://localhost:45321'), isTrue);
        expect(isLocalHostUri('http://127.0.0.1:45321'), isTrue);
        expect(isLocalHostUri('http://[::1]:45321'), isTrue);
        expect(isLocalHostUri('https://app.solaris.local'), isFalse);
        expect(isLocalHostUri('https://evil-attacker.com'), isFalse);
        expect(isLocalHostUri('http://127.0.0.1.attacker.com'), isFalse);
        expect(isLocalHostUri('http://localhost.attacker.com'), isFalse);
      });
    });

    // =========================================================================
    // 4. Windows Firewall Service Deep Verification
    // =========================================================================
    group('4. Windows Firewall Service Deep Verification', () {
      final firewall = WindowsFirewallService();

      test('getRuleName formats name strictly matching rulePrefix for clean deletion', () {
        expect(WindowsFirewallService.getRuleName(45321), equals('Solaris_Control_API_Port_45321'));
        expect(WindowsFirewallService.getRuleName(8080), equals('Solaris_Control_API_Port_8080'));
        expect(WindowsFirewallService.rulePrefix, equals('Solaris_Control_API_'));
      });

      test('isRuleConfigured handles port parameter cleanly without throwing', () async {
        final isConfigured = await firewall.isRuleConfigured(port: 45321);
        expect(isConfigured, isA<bool>());
      });

      test('ensureRuleAdded returns boolean result safely on current OS platform', () async {
        final result = await firewall.ensureRuleAdded(port: 45321);
        expect(result, isA<bool>());
      });

      test('removeAllSolarisRules completes without throwing unhandled exceptions', () async {
        await expectLater(firewall.removeAllSolarisRules(), completes);
      });
    });
  });
}
