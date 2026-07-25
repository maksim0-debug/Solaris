import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_key_entry.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/widgets/settings/api_permissions_dialog.dart';

/// Modal dialog for creating a new API key with custom name and initial permissions.
Future<ApiKeyEntry?> showCreateApiKeyDialog(
  BuildContext context, {
  required int existingKeysCount,
}) async {
  return showDialog<ApiKeyEntry>(
    context: context,
    builder: (dialogContext) => CreateApiKeyDialog(existingKeysCount: existingKeysCount),
  );
}

class CreateApiKeyDialog extends StatefulWidget {
  final int existingKeysCount;

  const CreateApiKeyDialog({
    super.key,
    required this.existingKeysCount,
  });

  @override
  State<CreateApiKeyDialog> createState() => _CreateApiKeyDialogState();
}

class _CreateApiKeyDialogState extends State<CreateApiKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  ApiPermissionsConfig _permissions = const ApiPermissionsConfig();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _configurePermissions() async {
    final updated = await showApiPermissionsDialog(
      context,
      initialConfig: _permissions,
    );
    if (updated != null && mounted) {
      setState(() {
        _permissions = updated;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final rawName = _nameController.text.trim();
      final defaultIndex = widget.existingKeysCount + 1;
      final newEntry = ApiKeyEntry.create(
        name: rawName,
        permissions: _permissions,
        defaultIndex: defaultIndex,
      );
      Navigator.of(context).pop(newEntry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final defaultIndex = widget.existingKeysCount + 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFDBA74).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: const Border(
                    bottom: BorderSide(color: Colors.white10),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDBA74).withOpacity(0.12),
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
                      child: Text(
                        l10n.createApiKeyDialogTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white54, size: 18),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),

              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Key Name Field
                      Text(
                        l10n.createApiKeyNameFieldLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        autofocus: true,
                        maxLength: 50,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'API Key $defaultIndex',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFDBA74)),
                          ),
                          counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Permissions summary card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _permissions.isReadOnly ? LucideIcons.lock : LucideIcons.shieldCheck,
                              color: _permissions.isReadOnly ? const Color(0xFFEF4444) : const Color(0xFF4ADE80),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _permissions.isReadOnly
                                        ? l10n.apiPermissionsSummaryReadOnly
                                        : l10n.apiPermissionsSummaryCustom(
                                            _permissions.allowedCategories.length,
                                          ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.apiPermissionsDialogTitle,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _configurePermissions,
                              icon: const Icon(LucideIcons.settings2, size: 14),
                              label: Text(
                                l10n.apiPermissionsConfigureButton,
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFDBA74),
                                side: const BorderSide(color: Color(0xFFFDBA74)),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

              // Actions Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  border: const Border(
                    top: BorderSide(color: Colors.white10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(
                        l10n.cancel,
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submit,
                      icon: const Icon(LucideIcons.plus, size: 16),
                      label: Text(l10n.apiKeysCreateButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFDBA74),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        ),
      ),
    );
  }
}
