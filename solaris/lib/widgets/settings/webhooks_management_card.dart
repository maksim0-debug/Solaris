import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/models/webhook_config.dart';
import 'package:solaris/providers.dart';
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
            backgroundColor: const Color(0xFF1E2230),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              existing == null ? 'Add Outbound Webhook' : 'Edit Webhook',
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Target Webhook URL *',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'https://homeassistant.local:8123/api/webhook/solaris',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Home Assistant / Node-RED',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: secretController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'HMAC Secret Key (Optional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'Secret for X-Solaris-Signature verification',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subscribed Events:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(color: Colors.blueAccent),
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
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  final url = urlController.text.trim();
                  if (url.isEmpty || Uri.tryParse(url)?.hasAbsolutePath != true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid absolute URL (e.g. http://...)'),
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
                child: Text(existing == null ? 'Add Webhook' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDlqDialog() async {
    final dlqEntries =
        await ref.read(webhookServiceProvider.notifier).getDLQEntries();

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(

        backgroundColor: const Color(0xFF1E2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.report_problem_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 10),
            Text(
              'Dead Letter Queue (${dlqEntries.length})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 350,
          child: dlqEntries.isEmpty
              ? const Center(
                  child: Text(
                    'Dead Letter Queue is empty! All webhooks delivered cleanly.',
                    style: TextStyle(color: Colors.white54),
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
                        'Event: ${item.eventName} -> ${item.url}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Attempts: ${item.attemptCount} | Error: ${item.lastError ?? "Unknown"}\n'
                        'Delivery ID: ${item.deliveryId}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          if (dlqEntries.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              label: const Text('Clear DLQ', style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                await ref.read(webhookServiceProvider.notifier).clearDLQ();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.webhook_rounded,
                          color: Colors.purpleAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Outbound Webhooks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${webhooks.length} configured | WAL Queue: ${webhookState.pendingCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'View Dead Letter Queue (DLQ)',
                        icon: Badge(
                          label: Text('${webhookState.dlqCount}'),
                          isLabelVisible: webhookState.dlqCount > 0,
                          child: const Icon(Icons.inbox_rounded, color: Colors.amberAccent),
                        ),
                        onPressed: _showDlqDialog,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Webhook'),
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
                  child: const Center(
                    child: Text(
                      'No Outbound Webhooks configured.\nClick "Add Webhook" to integrate with Home Assistant, Node-RED, or n8n.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.4),
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
                                ? (isFailed ? Icons.warning_rounded : Icons.check_circle_rounded)
                                : Icons.pause_circle_rounded,
                            color: wh.isEnabled
                                ? (isFailed ? Colors.redAccent : Colors.greenAccent)
                                : Colors.grey,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      wh.name ?? 'Webhook',
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
                                        '${wh.events.length} events',
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
                                tooltip: 'Send Test Ping',
                                icon: const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 20),
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Sending test ping payload...')),
                                  );
                                  final success = await ref
                                      .read(webhookServiceProvider.notifier)
                                      .sendTestPing(wh.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? '🟢 Test ping delivered successfully!'
                                              : '🔴 Test ping failed to deliver.',
                                        ),
                                        backgroundColor: success ? Colors.green : Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Edit Webhook',
                                icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                                onPressed: () => _showAddEditWebhookDialog(wh),
                              ),
                              IconButton(
                                tooltip: 'Delete Webhook',
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  ref.read(settingsProvider.notifier).deleteWebhook(wh.id);
                                },
                              ),
                              Switch(
                                value: wh.isEnabled,
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
