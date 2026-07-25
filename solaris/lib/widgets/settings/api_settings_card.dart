import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
          SnackBar(
            content: Text(l10n.apiOpenDocsError(e.toString())),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        final permissions = settings.apiPermissions;

        if (_portController.text != port.toString()) {
          _portController.text = port.toString();
        }
        if (_tokenController.text != token) {
          _tokenController.text = token;
        }

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDBA74).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.code,
                      color: Color(0xFFFDBA74),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.apiTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          serverState.isRunning
                              ? (isLanEnabled
                                  ? '🟢 ${l10n.apiStatusActiveLan(port)}'
                                  : '🟢 ${l10n.apiStatusActiveLocalhost(port)}')
                              : '🔴 ${l10n.apiStatusDisabled}',
                          style: TextStyle(
                            fontSize: 12,
                            color: serverState.isRunning
                                ? const Color(0xFF4ADE80)
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    activeColor: const Color(0xFFFDBA74),
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
                Text(
                  l10n.apiNetworkAccessMode,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(
                        l10n.apiModeLocalhost,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(LucideIcons.laptop, size: 14),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(
                        l10n.apiModeLan,
                        style: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(LucideIcons.wifi, size: 14),
                    ),
                  ],
                  selected: {isLanEnabled},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFFDBA74).withOpacity(0.2);
                      }
                      return Colors.white.withOpacity(0.05);
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFFFDBA74);
                      }
                      return Colors.white38;
                    }),
                    side: WidgetStateProperty.all(BorderSide.none),
                  ),
                  onSelectionChanged: (Set<bool> selection) async {
                    final enableLan = selection.first;

                    ref
                        .read(settingsProvider.notifier)
                        .updateApiLanAccessEnabled(enableLan);

                    if (enableLan) {
                      final firewallService = ref.read(windowsFirewallServiceProvider);
                      final success = await firewallService.ensureRuleAdded(port: port);

                      if (!success) {
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiLanAccessEnabled(false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.apiFirewallUacError),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                        return;
                      }

                      if (token.isEmpty) {
                        final newToken = _generateSecureToken();
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiAccessToken(newToken);
                      }
                    } else {
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
                          Text(
                            l10n.apiServerPort,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(LucideIcons.terminal, size: 16, color: Colors.white54),
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
                          Text(
                            l10n.apiDocumentation,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: () => _openDocumentation(port),
                            icon: const Icon(LucideIcons.bookOpen, size: 15, color: Colors.white70),
                            label: Text(
                              l10n.apiOpenSwagger,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.1)),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
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
                Text(
                  l10n.apiAccessKey,
                  style: const TextStyle(
                    fontSize: 13,
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
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          hintText: isLanEnabled ? l10n.apiTokenHintRequiredLan : l10n.apiTokenHintOptionalLocalhost,
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(LucideIcons.key, size: 16, color: Colors.white54),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isTokenVisible
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              size: 16,
                              color: Colors.white54,
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
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: const CircleBorder(),
                      ),
                      tooltip: l10n.apiCopyKeyTooltip,
                      icon: const Icon(LucideIcons.copy, color: Colors.white70, size: 16),
                      onPressed: token.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: token));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.apiKeyCopied),
                                ),
                              );
                            },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: const CircleBorder(),
                      ),
                      tooltip: l10n.apiGenerateKeyTooltip,
                      icon: const Icon(LucideIcons.refreshCw, color: Colors.white70, size: 16),
                      onPressed: () {
                        final newToken = _generateSecureToken();
                        _tokenController.text = newToken;
                        ref
                            .read(settingsProvider.notifier)
                            .updateApiAccessToken(newToken);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.apiKeyGenerated),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const Divider(height: 32, color: Colors.white10),

                // Granular API Permissions Security Section
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.apiPermissionsDialogTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            permissions.isReadOnly
                                ? l10n.apiPermissionsSummaryReadOnly
                                : l10n.apiPermissionsSummaryCustom(
                                    permissions.allowedCategories.length,
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              color: permissions.isReadOnly
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF4ADE80),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showApiPermissionsDialog(
                          context,
                          initialConfig: permissions,
                        );
                      },
                      icon: const Icon(LucideIcons.shieldCheck, size: 15, color: Color(0xFFFDBA74)),
                      label: Text(
                        l10n.apiPermissionsConfigureButton,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        side: BorderSide(color: const Color(0xFFFDBA74).withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
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
