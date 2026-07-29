import 'dart:io';

enum SsrfValidationTarget {
  webhook, // Allows LAN IP ranges (192.168.x.x, 10.x.x.x, 172.16.x.x) and mDNS (.local) when allowLanWebhooks is true
  strict, // Strictly blocks all private and local IP ranges
}

class SsrfValidator {
  /// Validates whether an IP address is blocked against SSRF and DNS Rebinding rules.
  /// Returns `true` if blocked, `false` if safe to connect.
  static bool isBlockedIp(
    InternetAddress address, {
    SsrfValidationTarget targetType = SsrfValidationTarget.webhook,
    bool allowLanWebhooks = true,
  }) {
    // 1. Normalize IPv4-Mapped IPv6 addresses (e.g. ::ffff:127.0.0.1 -> 127.0.0.1)
    InternetAddress target = address;
    if (target.type == InternetAddressType.IPv6 &&
        target.rawAddress.length == 16) {
      final b = target.rawAddress;
      final isMapped =
          b[0] == 0 &&
          b[1] == 0 &&
          b[2] == 0 &&
          b[3] == 0 &&
          b[4] == 0 &&
          b[5] == 0 &&
          b[6] == 0 &&
          b[7] == 0 &&
          b[8] == 0 &&
          b[9] == 0 &&
          b[10] == 0xFF &&
          b[11] == 0xFF;
      if (isMapped) {
        target = InternetAddress.fromRawAddress(target.rawAddress.sublist(12));
      }
    }

    final bytes = target.rawAddress;

    // 2. Validate IPv4 addresses
    if (target.type == InternetAddressType.IPv4) {
      if (bytes.length < 4) return true;
      final b0 = bytes[0];
      final b1 = bytes[1];

      // ALWAYS BLOCKED for IPv4
      if (b0 == 127) return true; // Loopback (127.0.0.0/8)
      if (b0 == 169 && b1 == 254)
        return true; // Link-Local / Cloud Metadata (169.254.0.0/16)
      if (b0 == 0) return true; // Current network (0.0.0.0/8)
      if (b0 >= 224) return true; // Multicast / Reserved (224.0.0.0/4)

      // Private LAN ranges
      final isLan =
          (b0 == 10) ||
          (b0 == 172 && (b1 >= 16 && b1 <= 31)) ||
          (b0 == 192 && b1 == 168);

      if (isLan) {
        if (targetType == SsrfValidationTarget.webhook && allowLanWebhooks) {
          return false; // Allowed for local LAN webhooks (Home Assistant, Node-RED)
        }
        return true; // Blocked in strict mode or when LAN webhooks disabled
      }
    }

    // 3. Validate IPv6 addresses
    if (target.type == InternetAddressType.IPv6) {
      if (target.isLoopback) return true; // ::1
      if (target.isMulticast) return true; // ff00::/8

      // Link-Local (fe80::/10) and Unique Local Address (fc00::/7) for mDNS (.local)
      final isLinkLocalOrUla =
          target.isLinkLocal || ((bytes[0] & 0xfe) == 0xfc);
      if (isLinkLocalOrUla) {
        if (targetType == SsrfValidationTarget.webhook && allowLanWebhooks) {
          return false; // Allowed for local mDNS LAN webhooks
        }
        return true; // Blocked in strict mode
      }
    }

    return false;
  }
}
