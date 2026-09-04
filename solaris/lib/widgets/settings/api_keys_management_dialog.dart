import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';
import 'package:solaris/widgets/settings/create_api_key_dialog.dart';
import 'package:solaris/widgets/settings/show_new_token_dialog.dart';

/// Shows the API Keys Management modal dialog.
Future<void> showApiKeysManagementDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const ApiKeysManagementDialog(),
  );
}

class ApiKeysManagementDialog extends ConsumerWidget {
  const ApiKeysManagementDialog({super.key});

  Future<void> _handleCreateKey(
    BuildContext context,
    WidgetRef ref,
    int existingCount,
  ) async {
    final newEntry = await showCreateApiKeyDialog(
      context,
      existingKeysCount: existingCount,
    );

    if (newEntry != null && context.mounted) {
      ref.read(settingsProvider.notifier).addApiKey(newEntry);
      await showNewTokenDialog(
        context,
        token: newEntry.token,
        keyName: newEntry.name,
      );
    }
  }

  Future<void> _handleEditPermissions(
    BuildContext context,
    WidgetRef ref,
    ApiKeyEntry entry,
  ) async {
    final updatedConfig = await showApiPermissionsDialog(
      context,
      initialConfig: entry.permissions,
    );

    if (updatedConfig != null && context.mounted) {
      final updatedEntry = entry.copyWith(permissions: updatedConfig);
      ref.read(settingsProvider.notifier).updateApiKey(updatedEntry);
    }
  }

  Future<void> _handleRegenerateToken(
    BuildContext context,
    WidgetRef ref,
    ApiKeyEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: Text(
          l10n.apiKeysRegenerateConfirmTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.apiKeysRegenerateConfirmMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDBA74),
              foregroundColor: Colors.black87,
            ),
            child: Text(l10n.apiKeysRegenerateConfirmTitle),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final newToken = ref
          .read(settingsProvider.notifier)
          .regenerateApiKeyToken(entry.id);
      if (newToken.isNotEmpty && context.mounted) {
        await showNewTokenDialog(context, token: newToken, keyName: entry.name);
      }
    }
  }

  Future<void> _handleDeleteKey(
    BuildContext context,
    WidgetRef ref,
    ApiKeyEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: Text(
          l10n.apiKeysDeleteConfirmTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.apiKeysDeleteConfirmMessage(entry.name),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.webhooksDeleteTooltip),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      ref.read(settingsProvider.notifier).removeApiKey(entry.id);
    }
  }

  void _copyTokenToClipboard(BuildContext context, ApiKeyEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: entry.token));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.apiKeysCopySuccessSnackbar),
        backgroundColor: const Color(0xFF4ADE80),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$d.$m.$y';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFDBA74).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (settingsMap) {
              final settings = settingsMap['all'];
              final apiKeys = settings?.apiKeys ?? [];
              final isSingleKey = apiKeys.length <= 1;

              return Column(
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      border: const Border(
                        bottom: BorderSide(color: Colors.white10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDBA74).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.key,
                            color: Color(0xFFFDBA74),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.apiKeysManagementDialogTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.apiKeysManagementSubtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _handleCreateKey(context, ref, apiKeys.length),
                          icon: const Icon(LucideIcons.plus, size: 16),
                          label: Text(l10n.apiKeysCreateButton),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFDBA74),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            color: Colors.white54,
                            size: 18,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Table Body
                  Expanded(
                    child: SizedBox(
                      height: 380,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 64,
                            horizontalMargin: 20,
                            columnSpacing: 24,
                            columns: [
                              DataColumn(
                                label: Text(
                                  l10n.apiKeysTableHeaderName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  l10n.apiKeysTableHeaderScopes,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  l10n.apiKeysTableHeaderCreated,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  l10n.apiKeysTableHeaderActions,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                            rows: apiKeys.map((keyEntry) {
                              final isReadOnly =
                                  keyEntry.permissions.isReadOnly;
                              final catCount = isReadOnly
                                  ? keyEntry
                                        .permissions
                                        .activeReadCategoriesCount
                                  : keyEntry
                                        .permissions
                                        .allowedCategories
                                        .length;

                              return DataRow(
                                cells: [
                                  // Name Cell
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          LucideIcons.key,
                                          color: Color(0xFFFDBA74),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              keyEntry.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (keyEntry.isDpapiFallback)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  '⚠️ ${l10n.apiKeysDpapiBadge}',
                                                  style: const TextStyle(
                                                    color: Color(0xFFF59E0B),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Scopes Cell
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isReadOnly
                                            ? const Color(
                                                0xFFEF4444,
                                              ).withValues(alpha: 0.15)
                                            : const Color(
                                                0xFF4ADE80,
                                              ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isReadOnly
                                              ? const Color(
                                                  0xFFEF4444,
                                                ).withValues(alpha: 0.4)
                                              : const Color(
                                                  0xFF4ADE80,
                                                ).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isReadOnly
                                                ? LucideIcons.lock
                                                : LucideIcons.shieldCheck,
                                            size: 12,
                                            color: isReadOnly
                                                ? const Color(0xFFFCA5A5)
                                                : const Color(0xFF86EFAC),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isReadOnly
                                                ? l10n.apiKeysReadOnlyChip(
                                                    catCount,
                                                  )
                                                : (keyEntry
                                                              .permissions
                                                              .allowedActions !=
                                                          null
                                                      ? l10n.apiKeysGranularActionChip(
                                                          keyEntry
                                                              .permissions
                                                              .allowedActions!
                                                              .length,
                                                          ApiPermissionsConfig.getAllCanonicalActions()
                                                              .length,
                                                        )
                                                      : l10n.apiKeysActiveScopesChip(
                                                          catCount,
                                                        )),
                                            style: TextStyle(
                                              color: isReadOnly
                                                  ? const Color(0xFFFCA5A5)
                                                  : const Color(0xFF86EFAC),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Created Date Cell
                                  DataCell(
                                    Text(
                                      _formatDate(keyEntry.createdAt),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                  // Actions Cell
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Copy Token Button
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.copy,
                                            size: 16,
                                          ),
                                          color: Colors.white70,
                                          tooltip: l10n.apiCopyKeyTooltip,
                                          onPressed: () =>
                                              _copyTokenToClipboard(
                                                context,
                                                keyEntry,
                                              ),
                                        ),

                                        // Edit Permissions Button
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.shieldCheck,
                                            size: 16,
                                          ),
                                          color: const Color(0xFFFDBA74),
                                          tooltip: l10n
                                              .apiPermissionsConfigureButton,
                                          onPressed: () =>
                                              _handleEditPermissions(
                                                context,
                                                ref,
                                                keyEntry,
                                              ),
                                        ),

                                        // Regenerate Token Button
                                        IconButton(
                                          icon: const Icon(
                                            LucideIcons.refreshCw,
                                            size: 16,
                                          ),
                                          color: const Color(0xFF60A5FA),
                                          tooltip: l10n.apiGenerateKeyTooltip,
                                          onPressed: () =>
                                              _handleRegenerateToken(
                                                context,
                                                ref,
                                                keyEntry,
                                              ),
                                        ),

                                        // Delete Key Button with Single Key Guard
                                        isSingleKey
                                            ? Tooltip(
                                                message: l10n
                                                    .apiKeysSoleKeyDeleteWarning,
                                                child: const IconButton(
                                                  icon: Icon(
                                                    LucideIcons.trash2,
                                                    size: 16,
                                                  ),
                                                  color: Colors.white24,
                                                  onPressed:
                                                      null, // Disabled guard
                                                ),
                                              )
                                            : IconButton(
                                                icon: const Icon(
                                                  LucideIcons.trash2,
                                                  size: 16,
                                                ),
                                                color: const Color(0xFFEF4444),
                                                tooltip:
                                                    l10n.webhooksDeleteTooltip,
                                                onPressed: () =>
                                                    _handleDeleteKey(
                                                      context,
                                                      ref,
                                                      keyEntry,
                                                    ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Dialog Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      border: const Border(
                        top: BorderSide(color: Colors.white10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            l10n.dialogOk,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
