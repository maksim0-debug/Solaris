import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service for managing Windows Defender Firewall rules for Solaris Control API.
class WindowsFirewallService {
  static const String rulePrefix = 'Solaris_Control_API_';
  
  /// Gets the rule name for a specific port.
  static String getRuleName(int port) => '${rulePrefix}Port_$port';

  /// Checks if a firewall inbound rule is configured for the given port.
  Future<bool> isRuleConfigured({int port = 45321}) async {
    if (!Platform.isWindows) return true;

    final ruleName = getRuleName(port);
    try {
      final result = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'show',
        'rule',
        'name=$ruleName',
      ]);

      if (result.exitCode == 0) {
        final stdoutStr = result.stdout.toString();
        if (!stdoutStr.contains('No rules match') && stdoutStr.contains(ruleName)) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('WindowsFirewallService: Error checking rule: $e');
    }
    return false;
  }

  /// Ensures an inbound rule allowing TCP traffic on [port] is added to Windows Firewall.
  /// Uses a 3-stage UAC elevation fallback protocol.
  Future<bool> ensureRuleAdded({int port = 45321}) async {
    if (!Platform.isWindows) return true;

    final isAlreadyConfigured = await isRuleConfigured(port: port);
    if (isAlreadyConfigured) return true;

    final ruleName = getRuleName(port);

    // 1. Direct netsh attempt (works if app runs as Administrator)
    try {
      final directResult = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'add',
        'rule',
        'name=$ruleName',
        'dir=in',
        'action=allow',
        'protocol=TCP',
        'localport=$port',
      ]);

      if (directResult.exitCode == 0) {
        debugPrint('WindowsFirewallService: Direct netsh rule added successfully for port $port');
        return true;
      }
    } catch (e) {
      debugPrint('WindowsFirewallService: Direct netsh call failed: $e');
    }

    // 2. PowerShell RunAs (UAC Elevation prompt for normal non-admin user)
    try {
      final psCommand =
          "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"New-NetFirewallRule -DisplayName ''$ruleName'' -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow\"'";
      final psResult = await Process.run('powershell', ['-Command', psCommand]);

      if (psResult.exitCode == 0) {
        // Polling verification: check rule status up to 5 seconds to ensure Windows Firewall service registered it
        for (int i = 0; i < 10; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final verified = await isRuleConfigured(port: port);
          if (verified) {
            debugPrint('WindowsFirewallService: Elevated PowerShell rule verified for port $port');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('WindowsFirewallService: Elevated PowerShell RunAs failed: $e');
    }

    debugPrint('WindowsFirewallService: Failed to add firewall rule (UAC denied or command failed)');
    return false;
  }

  /// Removes firewall rules created by Solaris for [port] or all Solaris rules.
  Future<void> removeAllSolarisRules({int port = 45321}) async {
    if (!Platform.isWindows) return;

    final ruleName = getRuleName(port);
    try {
      final netshResult = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'delete',
        'rule',
        'name=$ruleName',
      ]);
      if (netshResult.exitCode == 0) {
        debugPrint('WindowsFirewallService: Fast netsh rule removed for port $port');
        return;
      }
    } catch (e) {
      debugPrint('WindowsFirewallService: Fast netsh rule removal failed: $e');
    }

    try {
      final psCommand = "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -Command \"Remove-NetFirewallRule -DisplayName ''$rulePrefix*'' -ErrorAction SilentlyContinue\"'";
      await Process.run('powershell', ['-Command', psCommand]);
      debugPrint('WindowsFirewallService: Removed all Solaris firewall rules via PowerShell');
    } catch (e) {
      debugPrint('WindowsFirewallService: Error removing firewall rules: $e');
    }
  }
}
