import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/api_permissions_config.dart';

/// Shows the API Permissions configuration dialog.
Future<ApiPermissionsConfig?> showApiPermissionsDialog(
  BuildContext context, {
  required ApiPermissionsConfig initialConfig,
}) async {
  return showDialog<ApiPermissionsConfig>(
    context: context,
    builder: (dialogContext) => ApiPermissionsDialog(initialConfig: initialConfig),
  );
}

/// Interactive Flutter GUI dialog for managing granular API permissions and read-only mode.
class ApiPermissionsDialog extends ConsumerStatefulWidget {
  final ApiPermissionsConfig initialConfig;

  const ApiPermissionsDialog({
    super.key,
    required this.initialConfig,
  });

  @override
  ConsumerState<ApiPermissionsDialog> createState() => _ApiPermissionsDialogState();
}

class _ApiPermissionsDialogState extends ConsumerState<ApiPermissionsDialog> {
  late bool _isReadOnly;
  late bool _allowReadMonitors;
  late bool _allowReadSolar;
  late bool _allowReadWeather;
  late bool _allowReadSleep;
  late bool _allowReadCircadian;
  late Set<ApiActionCategory> _allowedCategories;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.initialConfig.isReadOnly;
    _allowReadMonitors = widget.initialConfig.allowReadMonitors;
    _allowReadSolar = widget.initialConfig.allowReadSolar;
    _allowReadWeather = widget.initialConfig.allowReadWeather;
    _allowReadSleep = widget.initialConfig.allowReadSleep;
    _allowReadCircadian = widget.initialConfig.allowReadCircadian;
    _allowedCategories = Set<ApiActionCategory>.from(widget.initialConfig.allowedCategories);
  }

  void _toggleCategory(ApiActionCategory category, bool enabled) {
    setState(() {
      if (enabled) {
        _allowedCategories.add(category);
      } else {
        _allowedCategories.remove(category);
      }
    });
  }

  void _save() {
    final updatedConfig = ApiPermissionsConfig(
      isReadOnly: _isReadOnly,
      allowReadMonitors: _allowReadMonitors,
      allowReadSolar: _allowReadSolar,
      allowReadWeather: _allowReadWeather,
      allowReadSleep: _allowReadSleep,
      allowReadCircadian: _allowReadCircadian,
      allowedCategories: _allowedCategories,
    );

    Navigator.of(context).pop(updatedConfig);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
              // Dialog Header
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
                        LucideIcons.shieldCheck,
                        color: Color(0xFFFDBA74),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.apiPermissionsDialogTitle,
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
                      tooltip: l10n.cancel,
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Global Read-Only Switch Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _isReadOnly
                              ? const Color(0xFFEF4444).withOpacity(0.1)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isReadOnly
                                ? const Color(0xFFEF4444).withOpacity(0.4)
                                : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isReadOnly ? LucideIcons.lock : LucideIcons.unlock,
                              color: _isReadOnly ? const Color(0xFFEF4444) : const Color(0xFF4ADE80),
                              size: 20,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.apiPermissionsReadOnlyLabel,
                                    style: TextStyle(
                                      color: _isReadOnly ? const Color(0xFFFCA5A5) : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.apiPermissionsReadOnlyHint,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isReadOnly,
                              activeColor: const Color(0xFFEF4444),
                              onChanged: (val) {
                                setState(() {
                                  _isReadOnly = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section 1: Data Sharing Read Flags
                      _buildSectionHeader(
                        icon: LucideIcons.eye,
                        title: l10n.apiPermissionsDataSharingSection,
                      ),
                      const SizedBox(height: 10),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowMonitors,
                        value: _allowReadMonitors,
                        onChanged: (val) => setState(() => _allowReadMonitors = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowSolar,
                        value: _allowReadSolar,
                        onChanged: (val) => setState(() => _allowReadSolar = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowWeather,
                        value: _allowReadWeather,
                        onChanged: (val) => setState(() => _allowReadWeather = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowSleep,
                        value: _allowReadSleep,
                        onChanged: (val) => setState(() => _allowReadSleep = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowCircadian,
                        value: _allowReadCircadian,
                        onChanged: (val) => setState(() => _allowReadCircadian = val),
                      ),

                      const SizedBox(height: 24),

                      // Section 2: Action Control Categories
                      Opacity(
                        opacity: _isReadOnly ? 0.4 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              icon: LucideIcons.sliders,
                              title: l10n.apiPermissionsControlCategoriesSection,
                            ),
                            const SizedBox(height: 10),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.monitors,
                              label: l10n.apiPermissionsCategoryMonitors,
                            ),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.presets,
                              label: l10n.apiPermissionsCategoryPresets,
                            ),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.circadian,
                              label: l10n.apiPermissionsCategoryCircadian,
                            ),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.gaming,
                              label: l10n.apiPermissionsCategoryGaming,
                            ),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.environment,
                              label: l10n.apiPermissionsCategoryEnvironment,
                            ),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.sleep,
                              label: l10n.apiPermissionsCategorySleep,
                            ),
                            _buildCategoryCheckboxTile(
                              category: ApiActionCategory.system,
                              label: l10n.apiPermissionsCategorySystem,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Buttons
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
                      onPressed: _save,
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(l10n.save),
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

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFFDBA74)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        value: value,
        activeColor: const Color(0xFFFDBA74),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildCategoryCheckboxTile({
    required ApiActionCategory category,
    required String label,
  }) {
    final isChecked = _allowedCategories.contains(category);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        enabled: !_isReadOnly,
        title: Text(
          label,
          style: TextStyle(
            color: _isReadOnly ? Colors.white30 : Colors.white70,
            fontSize: 13,
          ),
        ),
        value: isChecked,
        activeColor: const Color(0xFFFDBA74),
        checkColor: Colors.black,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        onChanged: _isReadOnly
            ? null
            : (bool? val) {
                if (val != null) {
                  _toggleCategory(category, val);
                }
              },
      ),
    );
  }
}
