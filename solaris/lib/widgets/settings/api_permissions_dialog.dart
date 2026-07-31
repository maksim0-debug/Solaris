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
    builder: (dialogContext) =>
        ApiPermissionsDialog(initialConfig: initialConfig),
  );
}

/// Interactive Flutter GUI dialog for managing granular API permissions and read-only mode.
class ApiPermissionsDialog extends ConsumerStatefulWidget {
  final ApiPermissionsConfig initialConfig;

  const ApiPermissionsDialog({super.key, required this.initialConfig});

  @override
  ConsumerState<ApiPermissionsDialog> createState() =>
      _ApiPermissionsDialogState();
}

class _ApiPermissionsDialogState extends ConsumerState<ApiPermissionsDialog> {
  late bool _isReadOnly;
  late bool _allowReadMonitors;
  late bool _allowReadSolar;
  late bool _allowReadWeather;
  late bool _allowReadSleep;
  late bool _allowReadCircadian;
  late Set<ApiActionCategory> _allowedCategories;
  late Set<String>? _allowedActions;

  @override
  void initState() {
    super.initState();
    _isReadOnly = widget.initialConfig.isReadOnly;
    _allowReadMonitors = widget.initialConfig.allowReadMonitors;
    _allowReadSolar = widget.initialConfig.allowReadSolar;
    _allowReadWeather = widget.initialConfig.allowReadWeather;
    _allowReadSleep = widget.initialConfig.allowReadSleep;
    _allowReadCircadian = widget.initialConfig.allowReadCircadian;
    _allowedCategories = Set<ApiActionCategory>.from(
      widget.initialConfig.allowedCategories,
    );
    if (widget.initialConfig.allowedActions != null) {
      _allowedActions = Set<String>.from(widget.initialConfig.allowedActions!);
    } else {
      _allowedActions = null;
    }
  }

  /// Calculates the Tri-State value for a category checkbox (true, false, or null for partial).
  bool? _getCategoryCheckboxValue(ApiActionCategory category) {
    if (!_allowedCategories.contains(category)) {
      return false;
    }
    if (_allowedActions == null) {
      return true;
    }
    final categoryActions = ApiPermissionsConfig.getActionsForCategory(
      category,
    );
    if (categoryActions.isEmpty) return true;

    final allowedInCatCount = categoryActions
        .where((action) => _allowedActions!.contains(action))
        .length;

    if (allowedInCatCount == 0) {
      return false;
    } else if (allowedInCatCount == categoryActions.length) {
      return true;
    } else {
      return null; // Partial selection (Tri-State null)
    }
  }

  /// Toggles an entire category on or off.
  void _toggleCategory(ApiActionCategory category, bool? newValue) {
    setState(() {
      final categoryActions = ApiPermissionsConfig.getActionsForCategory(
        category,
      );

      if (newValue == true) {
        _allowedCategories.add(category);
        if (_allowedActions != null) {
          _allowedActions!.addAll(categoryActions);
          if (_allowedActions!.length ==
              ApiPermissionsConfig.getAllCanonicalActions().length) {
            _allowedActions = null; // Clean Storage Protocol
          }
        }
      } else {
        _allowedCategories.remove(category);
        if (_allowedActions == null) {
          _allowedActions = Set<String>.from(
            ApiPermissionsConfig.getAllCanonicalActions(),
          );
        }
        _allowedActions!.removeAll(categoryActions);
      }
    });
  }

  /// Evaluates whether a specific canonical action is enabled in the UI state.
  bool _isActionAllowedInUi(String actionKey) {
    final category = ApiPermissionsConfig.getCategoryForAction(actionKey);
    if (category == null || !_allowedCategories.contains(category)) {
      return false;
    }
    if (_allowedActions == null) {
      return true;
    }
    return _allowedActions!.contains(actionKey);
  }

  /// Toggles an individual canonical action.
  void _toggleAction(String actionKey, bool enabled) {
    setState(() {
      final category = ApiPermissionsConfig.getCategoryForAction(actionKey);

      if (_allowedActions == null) {
        _allowedActions = Set<String>.from(
          ApiPermissionsConfig.getAllCanonicalActions(),
        );
      }

      if (enabled) {
        _allowedActions!.add(actionKey);
        if (category != null) {
          _allowedCategories.add(category);
        }
        if (_allowedActions!.length ==
            ApiPermissionsConfig.getAllCanonicalActions().length) {
          _allowedActions = null; // Clean Storage Protocol
        }
      } else {
        _allowedActions!.remove(actionKey);
        if (category != null) {
          final categoryActions = ApiPermissionsConfig.getActionsForCategory(
            category,
          );
          final hasRemainingInCat = categoryActions.any(
            (a) => _allowedActions!.contains(a),
          );
          if (!hasRemainingInCat) {
            _allowedCategories.remove(category);
          }
        }
      }
    });
  }

  /// Maps canonical string action keys to generated localization strings.
  String _getLocalizedActionName(AppLocalizations l10n, String actionKey) {
    switch (actionKey) {
      case 'set_brightness':
        return l10n.apiPermissionsActionSetBrightness;
      case 'set_temperature':
        return l10n.apiPermissionsActionSetTemperature;
      case 'set_monitor_offset':
        return l10n.apiPermissionsActionSetMonitorOffset;
      case 'set_brightness_preset':
        return l10n.apiPermissionsActionSetBrightnessPreset;
      case 'set_temperature_preset':
        return l10n.apiPermissionsActionSetTemperaturePreset;
      case 'set_user_preset':
        return l10n.apiPermissionsActionSetUserPreset;
      case 'cycle_preset':
        return l10n.apiPermissionsActionCyclePreset;
      case 'get_app_overrides':
        return l10n.apiPermissionsActionGetAppOverrides;
      case 'manage_app_overrides':
        return l10n.apiPermissionsActionManageAppOverrides;
      case 'reset_builtin_app_overrides':
        return l10n.apiPermissionsActionResetBuiltinAppOverrides;
      case 'set_auto_brightness':
        return l10n.apiPermissionsActionSetAutoBrightness;
      case 'set_auto_temperature':
        return l10n.apiPermissionsActionSetAutoTemperature;
      case 'set_smart_circadian':
        return l10n.apiPermissionsActionSetSmartCircadian;
      case 'set_smart_circadian_submodules':
        return l10n.apiPermissionsActionSetSmartCircadianSubmodules;
      case 'set_game_mode':
        return l10n.apiPermissionsActionSetGameMode;
      case 'set_game_mode_brightness':
        return l10n.apiPermissionsActionSetGameModeBrightness;
      case 'manage_game_mode_whitelist':
      case 'set_whitelist':
      case 'set_blacklist':
        return l10n.apiPermissionsActionManageGameModeWhitelist;
      case 'set_weather_adjustments':
        return l10n.apiPermissionsActionSetWeatherAdjustment;
      case 'set_weather_temperature_adjustment':
        return l10n.apiPermissionsActionSetWeatherTemperatureAdjustment;
      case 'set_weather_intensity':
        return l10n.apiPermissionsActionSetWeatherIntensity;
      case 'set_manual_location':
      case 'set_location':
        return l10n.apiPermissionsActionSetManualLocation;
      case 'set_weather_provider':
      case 'set_location_provider':
        return l10n.apiPermissionsActionSetWeatherProvider;
      case 'trigger_sun_sync':
      case 'sync_sun_times':
        return l10n.apiPermissionsActionTriggerSunSync;
      case 'push_sleep_status':
      case 'set_sleep_status':
        return l10n.apiPermissionsActionPushSleepStatus;
      case 'manage_webhooks':
        return l10n.apiPermissionsActionManageWebhooks;
      case 'set_map_animations':
      case 'trigger_map_animation':
        return l10n.apiPermissionsActionSetMapAnimations;
      case 'on_system_resume':
        return l10n.apiPermissionsActionOnSystemResume;
      case 'on_hardware_error':
        return l10n.apiPermissionsActionOnHardwareError;
      default:
        return actionKey;
    }
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
      allowedActions: _allowedActions,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                      icon: const Icon(
                        LucideIcons.x,
                        color: Colors.white54,
                        size: 18,
                      ),
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
                              _isReadOnly
                                  ? LucideIcons.lock
                                  : LucideIcons.unlock,
                              color: _isReadOnly
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF4ADE80),
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
                                      color: _isReadOnly
                                          ? const Color(0xFFFCA5A5)
                                          : Colors.white,
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
                        onChanged: (val) =>
                            setState(() => _allowReadMonitors = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowSolar,
                        value: _allowReadSolar,
                        onChanged: (val) =>
                            setState(() => _allowReadSolar = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowWeather,
                        value: _allowReadWeather,
                        onChanged: (val) =>
                            setState(() => _allowReadWeather = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowSleep,
                        value: _allowReadSleep,
                        onChanged: (val) =>
                            setState(() => _allowReadSleep = val),
                      ),
                      _buildSwitchTile(
                        title: l10n.apiPermissionsAllowCircadian,
                        value: _allowReadCircadian,
                        onChanged: (val) =>
                            setState(() => _allowReadCircadian = val),
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
                              title:
                                  l10n.apiPermissionsControlCategoriesSection,
                            ),
                            const SizedBox(height: 10),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.monitors,
                              label: l10n.apiPermissionsCategoryMonitors,
                              l10n: l10n,
                            ),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.presets,
                              label: l10n.apiPermissionsCategoryPresets,
                              l10n: l10n,
                            ),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.circadian,
                              label: l10n.apiPermissionsCategoryCircadian,
                              l10n: l10n,
                            ),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.gaming,
                              label: l10n.apiPermissionsCategoryGaming,
                              l10n: l10n,
                            ),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.environment,
                              label: l10n.apiPermissionsCategoryEnvironment,
                              l10n: l10n,
                            ),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.sleep,
                              label: l10n.apiPermissionsCategorySleep,
                              l10n: l10n,
                            ),
                            _buildCategoryExpansionAccordion(
                              category: ApiActionCategory.system,
                              label: l10n.apiPermissionsCategorySystem,
                              l10n: l10n,
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
                  border: const Border(top: BorderSide(color: Colors.white10)),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
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

  Widget _buildCategoryExpansionAccordion({
    required ApiActionCategory category,
    required String label,
    required AppLocalizations l10n,
  }) {
    final categoryActions = ApiPermissionsConfig.getActionsForCategory(
      category,
    );
    final triStateVal = _getCategoryCheckboxValue(category);
    final allowedCount = categoryActions
        .where((a) => _isActionAllowedInUi(a))
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 16, right: 12, bottom: 8),
        iconColor: const Color(0xFFFDBA74),
        collapsedIconColor: Colors.white54,
        leading: Checkbox(
          tristate: true,
          value: triStateVal,
          activeColor: const Color(0xFFFDBA74),
          checkColor: Colors.black,
          onChanged: _isReadOnly
              ? null
              : (bool? val) {
                  _toggleCategory(category, val);
                },
        ),
        title: Text(
          label,
          style: TextStyle(
            color: _isReadOnly ? Colors.white30 : Colors.white.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          l10n.apiKeysGranularActionChip(allowedCount, categoryActions.length),
          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
        ),
        children: categoryActions.map((actionKey) {
          final isAllowed = _isActionAllowedInUi(actionKey);
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.015),
              borderRadius: BorderRadius.circular(6),
            ),
            child: CheckboxListTile(
              enabled: !_isReadOnly && _allowedCategories.contains(category),
              title: Text(
                _getLocalizedActionName(l10n, actionKey),
                style: TextStyle(
                  color: _isReadOnly || !_allowedCategories.contains(category)
                      ? Colors.white30
                      : Colors.white.withOpacity(0.8),
                  fontSize: 12.5,
                ),
              ),
              subtitle: Text(
                actionKey,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
              value: isAllowed,
              activeColor: const Color(0xFFFDBA74),
              checkColor: Colors.black,
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              onChanged: (_isReadOnly || !_allowedCategories.contains(category))
                  ? null
                  : (bool? val) {
                      if (val != null) {
                        _toggleAction(actionKey, val);
                      }
                    },
            ),
          );
        }).toList(),
      ),
    );
  }
}
