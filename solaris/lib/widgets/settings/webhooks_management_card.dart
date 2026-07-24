import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/theme/app_theme.dart';
import 'package:solaris/widgets/glass_card.dart';

class WebhooksManagementCard extends ConsumerStatefulWidget {
  const WebhooksManagementCard({super.key});

  @override
  ConsumerState<WebhooksManagementCard> createState() =>
      _WebhooksManagementCardState();
}

class _WebhooksManagementCardState
    extends ConsumerState<WebhooksManagementCard> {
  void _showAddEditWebhookDialog([WebhookConfig? existing]) {
    final l10n = AppLocalizations.of(context)!;
    final urlController = TextEditingController(text: existing?.url ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final secretController = TextEditingController(text: existing?.secretKey ?? '');
    final Set<WebhookEventType> selectedEvents = existing != null
        ? Set.from(existing.events)
        : Set.from(WebhookEventType.values);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              existing == null ? l10n.webhooksAddTitle : l10n.webhooksEditTitle,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.webhooksUrlLabel,
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'https://homeassistant.local:8123/api/webhook/solaris',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.webhooksNameLabel,
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: 'Home Assistant / Node-RED',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: l10n.webhooksSecretLabel,
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintText: l10n.webhooksSecretHint,
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.webhooksSubscribedEvents,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              if (selectedEvents.length == WebhookEventType.values.length) {
                                selectedEvents.clear();
                              } else {
                                selectedEvents.addAll(WebhookEventType.values);
                              }
                            });
                          },
                          child: Text(
                            selectedEvents.length == WebhookEventType.values.length
                                ? l10n.webhooksDeselectAll
                                : l10n.webhooksSelectAll,
                            style: const TextStyle(color: Color(0xFFFDBA74)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: WebhookEventType.values.map((ev) {
                          final isChecked = selectedEvents.contains(ev);
                          return CheckboxListTile(
                            dense: true,
                            activeColor: const Color(0xFFFDBA74),
                            checkColor: Colors.black,
                            title: Text(
                              ev.wireName,
                              style: TextStyle(color: Colors.white.withOpacity(0.87), fontSize: 13),
                            ),
                            value: isChecked,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedEvents.add(ev);
                                } else {
                                  selectedEvents.remove(ev);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(l10n.cancel, style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDBA74),
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isEmpty || Uri.tryParse(url)?.hasAbsolutePath != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.webhooksInvalidUrlError),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  final config = WebhookConfig(
                    id: existing?.id ?? 'wh_${DateTime.now().millisecondsSinceEpoch}',
                    url: url,
                    name: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                    events: selectedEvents,
                    secretKey: secretController.text.trim().isEmpty ? null : secretController.text.trim(),
                  );

                  if (existing == null) {
                    ref.read(settingsProvider.notifier).addWebhook(config);
                  } else {
                    ref.read(settingsProvider.notifier).updateWebhook(config);
                  }

                  Navigator.of(dialogCtx).pop();
                },
                child: Text(
                  existing == null ? l10n.webhooksAddButton : l10n.webhooksSaveChangesButton,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDlqDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final dlqEntries =
        await ref.read(webhookServiceProvider.notifier).getDLQEntries();

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text(
              l10n.webhooksDlqTitle(dlqEntries.length),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 350,
          child: dlqEntries.isEmpty
              ? Center(
                  child: Text(
                    l10n.webhooksDlqEmpty,
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.separated(
                  itemCount: dlqEntries.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (_, idx) {
                    final item = dlqEntries[idx];
                    return ListTile(
                      dense: true,
                      title: Text(
                        l10n.webhooksDlqEvent(item.eventName, item.url),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        l10n.webhooksDlqDetails(item.attemptCount, item.lastError ?? "Unknown", item.deliveryId),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (dlqEntries.isNotEmpty)
            TextButton.icon(
              icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
              label: Text(l10n.webhooksClearDlq, style: const TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                await ref.read(webhookServiceProvider.notifier).clearDLQ();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogOk, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final webhookState = ref.watch(webhookServiceProvider);

    return settingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => const SizedBox.shrink(),
      data: (settingsMap) {
        final settings = settingsMap['all'];
        if (settings == null) return const SizedBox.shrink();
        final webhooks = settings.webhooks;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDBA74).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          LucideIcons.webhook,
                          color: Color(0xFFFDBA74),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.webhooksTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.webhooksSubtitle(webhooks.length, webhookState.pendingCount),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: l10n.webhooksViewDlqTooltip,
                        icon: Badge(
                          label: Text('${webhookState.dlqCount}'),
                          isLabelVisible: webhookState.dlqCount > 0,
                          child: const Icon(LucideIcons.inbox, color: Color(0xFFFDBA74), size: 20),
                        ),
                        onPressed: _showDlqDialog,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDBA74),
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: Text(
                          l10n.webhooksAddButton,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _showAddEditWebhookDialog(),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (webhooks.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Center(
                    child: Text(
                      l10n.webhooksEmptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), height: 1.4),
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: webhooks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final wh = webhooks[idx];
                    final isFailed = wh.failureCount >= 10;

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isFailed
                              ? Colors.redAccent.withOpacity(0.5)
                              : Colors.white10,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            wh.isEnabled
                                ? (isFailed ? LucideIcons.alertTriangle : LucideIcons.checkCircle2)
                                : LucideIcons.pauseCircle,
                            color: wh.isEnabled
                                ? (isFailed ? Colors.redAccent : Colors.greenAccent)
                                : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      wh.name ?? l10n.webhooksDefaultName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        l10n.webhooksEventsCount(wh.events.length),
                                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  wh.url,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Action Buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.webhooksSendTestPingTooltip,
                                icon: const Icon(LucideIcons.send, color: Color(0xFFFDBA74), size: 18),
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.webhooksSendingTestPing),
                                    ),
                                  );
                                  final success = await ref
                                      .read(webhookServiceProvider.notifier)
                                      .sendTestPing(wh.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? '🟢 ${l10n.webhooksTestPingSuccess}'
                                              : '🔴 ${l10n.webhooksTestPingFailed}',
                                        ),
                                        backgroundColor: success ? Colors.green : Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: l10n.webhooksEditTooltip,
                                icon: const Icon(LucideIcons.edit2, color: Colors.white70, size: 18),
                                onPressed: () => _showAddEditWebhookDialog(wh),
                              ),
                              IconButton(
                                tooltip: l10n.webhooksDeleteTooltip,
                                icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                                onPressed: () {
                                  ref.read(settingsProvider.notifier).deleteWebhook(wh.id);
                                },
                              ),
                              Switch(
                                value: wh.isEnabled,
                                activeColor: const Color(0xFFFDBA74),
                                onChanged: (val) {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .updateWebhook(wh.copyWith(isEnabled: val, failureCount: 0));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
