import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/circadian_chart.dart';
import 'package:solaris/services/monitor_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settingsMap = ref.watch(settingsProvider);
    final monitorId = ref.watch(settingsMonitorIdProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final monitorsAsync = ref.watch(monitorListProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: LucideIcons.settings,
            title: l10n.settings,
            subtitle: l10n.settingsSubtitle,
          ),
          const SizedBox(height: 24),
          
          // Monitor Selector
          _MonitorSelector(
            currentId: monitorId,
            monitors: (monitorsAsync.value ?? []).cast<MonitorInfo>(),
            onChanged: (id) => ref.read(settingsMonitorIdProvider.notifier).select(id),
          ),
          const SizedBox(height: 24),

          // Chart Preview
          const CircadianChartWidget(),
          const SizedBox(height: 24),

          const SizedBox(height: 24),


          // App Settings (Autorun)
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        LucideIcons.monitor,
                        color: Color(0xFFFDBA74),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settings,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l10n.autorunSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.autorun,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.autorunSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settingsMap['all']!.isAutorunEnabled, // Autorun is global-ish, use 'all'
                      onChanged: (val) => settingsNotifier.updateAutorun(val),
                      activeColor: const Color(0xFFFDBA74),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Info Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            opacity: 0.03,
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 18,
                  color: Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.realtimeApplyNotice,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFDBA74), size: 28),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonitorSelector extends StatelessWidget {
  final String currentId;
  final List<MonitorInfo> monitors;
  final void Function(String) onChanged;

  const _MonitorSelector({
    required this.currentId,
    required this.monitors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Text(
              l10n.selectMonitor,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MonitorChip(
                  label: l10n.allMonitors,
                  isSelected: currentId == 'all',
                  onTap: () => onChanged('all'),
                  icon: LucideIcons.layers,
                ),
                ...monitors.map((m) => _MonitorChip(
                  label: m.friendlyName,
                  isSelected: currentId == m.deviceName,
                  onTap: () => onChanged(m.deviceName),
                  icon: LucideIcons.monitor,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitorChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _MonitorChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFFFDBA74) : Colors.white10;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFFDBA74).withOpacity(0.5) : Colors.white.withOpacity(0.05),
                width: 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(0xFFFDBA74).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.black87 : Colors.white60,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black87 : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
