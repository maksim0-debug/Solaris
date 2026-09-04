import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/settings/api_keys_management_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solaris/widgets/deep_link_target.dart';

/// Interactive Flutter GUI Card for managing Solaris Control API, Key Authentication & LAN Firewall.
class ApiSettingsCard extends ConsumerStatefulWidget {
  final Map<String, GlobalKey<DeepLinkTargetState>>? anchorKeys;
  const ApiSettingsCard({super.key, this.anchorKeys});

  @override
  ConsumerState<ApiSettingsCard> createState() => _ApiSettingsCardState();
}

class _ApiSettingsCardState extends ConsumerState<ApiSettingsCard> {
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
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
          SnackBar(content: Text(l10n.apiOpenDocsError(e.toString()))),
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
        final apiKeys = settings.apiKeys;
        final requireLocalToken = settings.requireLocalToken;

        if (_portController.text != port.toString()) {
          _portController.text = port.toString();
        }

        final fallbackKeys = apiKeys.where((k) => k.isDpapiFallback).toList();

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Non-auto-hiding DPAPI Fallback Warning Banners
              for (final fallbackKey in fallbackKeys)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.alertTriangle,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.apiKeysDpapiWarningBanner(fallbackKey.name),
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          LucideIcons.x,
                          color: Colors.white54,
                          size: 16,
                        ),
                        onPressed: () {
                          ref
                              .read(settingsProvider.notifier)
                              .dismissDpapiFallbackWarning(fallbackKey.id);
                        },
                      ),
                    ],
                  ),
                ),

              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDBA74).withValues(alpha: 0.1),
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
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    activeThumbColor: const Color(0xFFFDBA74),
                    onChanged: (val) async {
                      ref
                          .read(settingsProvider.notifier)
                          .updateLocalIpcServerEnabled(val);
                      if (val) {
                        await ref
                            .read(localIpcServiceProvider.notifier)
                            .start();
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
                DeepLinkTarget(
                  key: widget.anchorKeys?['api_lan_access'],
                  id: 'api_lan_access',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>((
                                Set<WidgetState> states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(
                                    0xFFFDBA74,
                                  ).withValues(alpha: 0.2);
                                }
                                return Colors.white.withValues(alpha: 0.05);
                              }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color>((
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
                            final firewallService = ref.read(
                              windowsFirewallServiceProvider,
                            );
                            final success = await firewallService
                                .ensureRuleAdded(port: port);

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
                          } else {
                            final firewallService = ref.read(
                              windowsFirewallServiceProvider,
                            );
                            await firewallService.removeAllSolarisRules(
                              port: port,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Server Port Field & Documentation
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DeepLinkTarget(
                        key: widget.anchorKeys?['api_port'],
                        id: 'api_port',
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                prefixIcon: const Icon(
                                  LucideIcons.terminal,
                                  size: 16,
                                  color: Colors.white54,
                                ),
                              ),
                              onSubmitted: (val) async {
                                final newPort = int.tryParse(val) ?? 45321;
                                if (newPort != port &&
                                    newPort > 1024 &&
                                    newPort < 65535) {
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
                            icon: const Icon(
                              LucideIcons.bookOpen,
                              size: 15,
                              color: Colors.white70,
                            ),
                            label: Text(
                              l10n.apiOpenSwagger,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
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

                const Divider(height: 32, color: Colors.white10),

                // Multiple API Access Keys Management Section
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.apiKeysManagementDialogTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.apiKeysActiveCountSubtitle(apiKeys.length),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => showApiKeysManagementDialog(context),
                      icon: const Icon(LucideIcons.key, size: 15),
                      label: Text(l10n.apiKeysManageButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDBA74),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Require Local Token Toggle Tile
                DeepLinkTarget(
                  key: widget.anchorKeys?['api_require_token'],
                  id: 'api_require_token',
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.shieldAlert,
                          color: Color(0xFFFDBA74),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.requireLocalTokenLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.requireLocalTokenSubtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: requireLocalToken,
                          activeThumbColor: const Color(0xFFFDBA74),
                          onChanged: (val) {
                            ref
                                .read(settingsProvider.notifier)
                                .updateRequireLocalToken(val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
