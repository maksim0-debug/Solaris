import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/brightness_target.dart';
import 'package:solaris/models/regulation_group.dart';
import 'package:solaris/models/smart_circadian_data.dart';
import 'package:solaris/models/temperature_target.dart';
import 'package:solaris/providers/regulation_breakdown_provider.dart';
import 'package:solaris/utils/brightness_display_format.dart';
import 'package:solaris/widgets/circadian_breakdown_tooltip.dart';
import 'package:solaris/widgets/temperature_breakdown_tooltip.dart';
import 'package:solaris/widgets/weather_icon_helper.dart';

class RegulationBreakdownPanel extends ConsumerWidget {
  const RegulationBreakdownPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(regulationBreakdownProvider);
    final l10n = AppLocalizations.of(context)!;
    final showBrightness = selection.brightness.any(
      (group) =>
          group.members.any((m) => m.target != null && !m.target!.isManual),
    );
    final showTemperature = selection.temperature.any(
      (group) => group.members.any(
        (m) => m.target != null && !m.target!.isManual && !m.target!.isDisabled,
      ),
    );
    if (!showBrightness && !showTemperature) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBrightness)
            _Section<BrightnessTarget>(
              title: l10n.brightnessRegulationTitle,
              groups: selection.brightness,
              selection: selection,
              status: (entry) => entry.target?.isManual == true
                  ? l10n.manualRegulationPaused
                  : null,
              explanation: (group, name, shared, child) {
                final entry = group.representative;
                return CircadianBreakdownTooltip(
                  target: entry.target!,
                  offset: entry.offset,
                  minimumBrightness: entry.minimum,
                  appliedBrightness: shared ? null : entry.appliedValue,
                  appliedValues: shared
                      ? [
                          for (final member in group.members)
                            if (member.appliedValue != null)
                              (name: member.name, value: member.appliedValue!),
                        ]
                      : const [],
                  monitorName: name,
                  isMonitorGroup: shared,
                  child: child,
                );
              },
              adjustments: (entry) =>
                  _brightnessAdjustments(l10n, entry.target!.data),
            ),
          if (showBrightness && showTemperature) const SizedBox(height: 16),
          if (showTemperature)
            _Section<TemperatureTarget>(
              title: l10n.temperatureRegulationTitle,
              groups: selection.temperature,
              selection: selection,
              status: (entry) => entry.target?.isDisabled == true
                  ? l10n.temperatureSourceDisabled
                  : entry.target?.isManual == true
                  ? l10n.manualRegulationPaused
                  : null,
              explanation: (group, name, shared, child) {
                final entry = group.representative;
                final target = entry.target!;
                return TemperatureBreakdownTooltip(
                  target: target,
                  smartData: target.data,
                  currentTemperature: target.value,
                  isSmartCircadianEnabled: true,
                  monitorName: name,
                  isMonitorGroup: shared,
                  appliedTemperature: shared
                      ? null
                      : entry.appliedValue?.round(),
                  appliedValues: shared
                      ? [
                          for (final member in group.members)
                            if (member.appliedValue != null)
                              (name: member.name, value: member.appliedValue!),
                        ]
                      : const [],
                  child: child,
                );
              },
              adjustments: (entry) =>
                  _temperatureAdjustments(l10n, entry.target!.data),
            ),
        ],
      ),
    );
  }
}

typedef _Explanation<T> =
    Widget Function(
      RegulationGroup<T> group,
      String label,
      bool shared,
      Widget child,
    );

class _Section<T> extends StatelessWidget {
  const _Section({
    required this.title,
    required this.groups,
    required this.selection,
    required this.explanation,
    required this.adjustments,
    required this.status,
  });

  final String title;
  final List<RegulationGroup<T>> groups;
  final RegulationBreakdownSelection selection;
  final _Explanation<T> explanation;
  final List<Widget> Function(MonitorRegulationEntry<T>) adjustments;
  final String? Function(MonitorRegulationEntry<T>) status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final single = groups.length == 1;
    String label(RegulationGroup<T> group) =>
        selection.allSelected &&
            selection.selectedCount > 1 &&
            group.members.length == selection.selectedCount
        ? l10n.allMonitors
        : group.members.map((m) => m.name).join(', ');
    Widget info(RegulationGroup<T> group) => explanation(
      group,
      label(group),
      group.members.length > 1,
      const Icon(LucideIcons.info, size: 14, color: Colors.white38),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white38,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (single && groups.single.representative.target != null)
              info(groups.single),
          ],
        ),
        for (final group in groups) ...[
          const SizedBox(height: 8),
          if (!single)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label(group),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ),
                if (group.representative.target != null) ...[
                  const SizedBox(width: 8),
                  info(group),
                ],
              ],
            ),
          if (single && group.members.length > 1)
            Text(
              label(group),
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          if (group.representative.target == null)
            Text(
              l10n.calculationUnavailable,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            )
          else if (status(group.representative) != null)
            Text(
              status(group.representative)!,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            )
          else
            for (final adjustment in adjustments(group.representative))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: adjustment,
              ),
        ],
      ],
    );
  }
}

String _signed(num value) => '${value > 0 ? '+' : ''}$value';

List<Widget> _brightnessAdjustments(
  AppLocalizations l10n,
  SmartCircadianData data,
) {
  String impact(String feature, double change, {int? remaining}) {
    final value = formatBrightnessValue(change, signed: true);
    return remaining == null
        ? l10n.circadianImpact(feature, value)
        : l10n.circadianImpactWithTime(
            feature,
            value,
            remaining,
            l10n.minutesAbbreviation,
          );
  }

  return [
    if (data.weatherAbsoluteImpact >= 0.005)
      _Adjustment(
        icon: getWeatherIcon(data.weatherCode),
        label: l10n.weatherBrightnessReduction(
          formatBrightnessValue(data.weatherAbsoluteImpact),
        ),
        color: const Color(0xFF94A3B8),
      ),
    if (data.isWindDownActive)
      _Adjustment(
        icon: LucideIcons.moon,
        label: data.windDownMinutesRemaining != null
            ? impact(
                l10n.featureWindDownShort,
                -data.windDownAbsoluteImpact,
                remaining: data.windDownMinutesRemaining,
              )
            : data.minutesUntilWakeUp != null
            ? l10n.circadianImpactWithStatus(
                l10n.featureWindDownShort,
                formatBrightnessValue(
                  -data.windDownAbsoluteImpact,
                  signed: true,
                ),
                l10n.remainingUntilWakeUp,
              )
            : impact(l10n.featureWindDownShort, -data.windDownAbsoluteImpact),
      ),
    if (data.isTimeShiftActive)
      _Adjustment(
        icon: LucideIcons.sunrise,
        label: impact(
          l10n.featureTimeShiftShort,
          data.elevationShiftBrightnessImpact + data.timeShiftBrightnessImpact,
          remaining: data.timeShiftMinutesRemaining,
        ),
      ),
    if (data.isSleepPressureActive)
      _Adjustment(
        icon: LucideIcons.hourglass,
        label: impact(
          l10n.featureSleepPressureShort,
          -data.sleepPressureAbsoluteImpact,
        ),
      ),
    if (data.isSleepDebtActive)
      _Adjustment(
        icon: LucideIcons.battery,
        label: impact(
          l10n.featureSleepDebtShort,
          -data.sleepDebtAbsoluteImpact,
        ),
      ),
  ];
}

List<Widget> _temperatureAdjustments(
  AppLocalizations l10n,
  SmartCircadianData data,
) => [
  if (data.weatherTemperatureImpact != 0)
    _Adjustment(
      icon: getWeatherIcon(data.weatherCode),
      label:
          '${l10n.temperatureBreakdownWeather}: ${_signed(data.weatherTemperatureImpact)} K',
      color: const Color(0xFF94A3B8),
    ),
  if (data.isTimeShiftActive && data.timeShiftTemperatureImpact != 0)
    _Adjustment(
      icon: LucideIcons.sunrise,
      label:
          '${l10n.featureTimeShiftShort}: ${_signed(data.timeShiftTemperatureImpact)} K${data.timeShiftMinutesRemaining != null && data.timeShiftMinutesRemaining! > 0 ? ' (${data.timeShiftMinutesRemaining} ${l10n.minutesAbbreviation})' : ''}',
    ),
  if (data.windDownTemperatureImpact != 0)
    _Adjustment(
      icon: LucideIcons.moon,
      label:
          '${l10n.featureWindDownShort}: ${_signed(data.windDownTemperatureImpact)} K',
    ),
  if (data.sleepPressureTemperatureImpact != 0)
    _Adjustment(
      icon: LucideIcons.hourglass,
      label:
          '${l10n.featureSleepPressureShort}: ${_signed(data.sleepPressureTemperatureImpact)} K',
    ),
  if (data.sleepDebtTemperatureImpact != 0)
    _Adjustment(
      icon: LucideIcons.battery,
      label:
          '${l10n.featureSleepDebtShort}: ${_signed(data.sleepDebtTemperatureImpact)} K',
    ),
];

class _Adjustment extends StatelessWidget {
  const _Adjustment({
    required this.icon,
    required this.label,
    this.color = const Color(0xFF818CF8),
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFC4B5FD),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
