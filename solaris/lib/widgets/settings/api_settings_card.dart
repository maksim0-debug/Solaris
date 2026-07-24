import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

/// Interactive Flutter GUI Card for managing Solaris Control API, Key Authentication & LAN Firewall.
class ApiSettingsCard extends ConsumerStatefulWidget {
  const ApiSettingsCard({super.key});

  @override
  ConsumerState<ApiSettingsCard> createState() => _ApiSettingsCardState();
}

class _ApiSettingsCardState extends ConsumerState<ApiSettingsCard> {
  bool _isTokenVisible = false;
  late TextEditingController _portController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  String _generateSecureToken() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final bytes = utf8.encode('solaris_token_${random}_1000');
    final hash = base64Url.encode(bytes).replaceAll('=', '');
    return 'sol_${hash.substring(0, hash.length > 32 ? 32 : hash.length)}';
  }

  Future<void> _openDocumentation(int port) async {
    final docsUri = Uri.parse('http://localhost:$port/api/v1/docs');
    try {
      if (await canLaunchUrl(docsUri)) {
        await launchUrl(docsUri, mode: LaunchMode.externalApplication);
      } else {
        await Process.run('cmd', ['/c', 'start', docsUri.toString()]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open documentation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final serverState = ref.watch(localIpcServiceProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('Error loading settings: $err'),
      data: (settingsMap) {
        final settings = settingsMap['all'];
        if (settings == null) return const SizedBox.shrink();

        final isEnabled = settings.isLocalIpcServerEnabled;
        final isLanEnabled = settings.isApiLanAccessEnabled;
        final port = settings.apiServerPort;
        final token = settings.apiAccessToken;

        if (_portController.text != port.toString()) {
          _portController.text = port.toString();
        }
        if (_tokenController.text != token) {
          _tokenController.text = token;
        }

        return GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.api_rounded,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Solaris Control API v1',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serverState.isRunning
                              ? (isLanEnabled
                                  ? '🟢 Active (LAN: 0.0.0.0:$port)'
                                  : '🟢 Active (Localhost: 127.0.0.1:$port)')
                              : '🔴 Disabled',
                          style: TextStyle(
                            fontSize: 13,
                            color: serverState.isRunning
                                ? Colors.greenAccent
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (val) async {
                      ref
                          .read(settingsProvider.notifier)
                          .updateLocalIpcServerEnabled(val);
                      if (val) {
                        await ref.read(localIpcServiceProvider.notifier).start();
                      } else {
                        await ref.read(localIpcServiceProvider.notifier).stop();
                      }
                    },
                  ),
                ],
              ),

              if (isEnabled) ...[
                const Divider(height: 32, color: Colors.white10),

                // Network Mode Selector (Localhost / LAN)
                const Text(
                  'Network Access Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Localhost Only (127.0.0.1)'),
                      icon: Icon(Icons.computer_rounded, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('LAN Access (0.0.0.0)'),
                      icon: Icon(Icons.lan_rounded, size: 18),
                    ),
                  ],
                  selected: {isLanEnabled},
                  onSelectionChanged: (Set<bool> selection) async {
                    final enableLan = selection.first;

                    // 1. Immediately update UI state for zero-latency response
                    ref
                        .read(settingsProvider.notifier)
                        .updateApiLanAccessEnabled(enableLan);

                    if (enableLan) {
                      // Request UAC Firewall rule creation
                      final firewallService = ref.read(windowsFirewallServiceProvider);
                      final success = await firewallService.ensureRuleAdded(port: port);

                      if (!success) {
                        // Rollback state if UAC is rejected
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiLanAccessEnabled(false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Error: Windows Firewall UAC permission denied. LAN access canceled.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                        return;
                      }

                      // Auto-generate token if empty on LAN enable
                      if (token.isEmpty) {
                        final newToken = _generateSecureToken();
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiAccessToken(newToken);
                      }
                    } else {
                      // Clean firewall rules when disabling LAN
                      final firewallService = ref.read(windowsFirewallServiceProvider);
                      await firewallService.removeAllSolarisRules(port: port);
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Server Port Field
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'API Server Port',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.numbers, size: 18),
                            ),
                            onSubmitted: (val) async {
                              final newPort = int.tryParse(val) ?? 45321;
                              if (newPort != port && newPort > 1024 && newPort < 65535) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateApiServerPort(newPort);
                                await ref
                                    .read(localIpcServiceProvider.notifier)
                                    .restartServer();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Interactive Documentation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () => _openDocumentation(port),
                            icon: const Icon(Icons.menu_book_rounded, size: 18),
                            label: const Text('Open Swagger UI'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // API Access Token Field
                const Text(
                  'API Access Key (X-API-Key)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tokenController,
                        obscureText: !_isTokenVisible,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          hintText: isLanEnabled ? 'Required for LAN' : 'Optional for Localhost',
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.key_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isTokenVisible
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                _isTokenVisible = !_isTokenVisible;
                              });
                            },
                          ),
                        ),
                        onChanged: (val) {
                          ref
                              .read(settingsProvider.notifier)
                              .updateApiAccessToken(val.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Copy API Key',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: token.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: token));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('API key copied to clipboard'),
                                ),
                              );
                            },
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Generate New Key',
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: () {
                        final newToken = _generateSecureToken();
                        _tokenController.text = newToken;
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiAccessToken(newToken);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('New API key generated'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
