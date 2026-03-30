import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/providers/google_fit_provider.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/sleep_regime_card.dart';
import 'package:intl/intl.dart';

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sleepState = ref.watch(sleepProvider);
    final googleFitState = ref.watch(googleFitProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: LucideIcons.moon,
            title: l10n.sleep, 
            subtitle: l10n.sleepSubtitle,
          ),
          const SizedBox(height: 24),

          // Google Fit Sync Card
          _GoogleFitSyncCard(googleFitState: googleFitState, isLoading: sleepState.isLoading, error: sleepState.error),
          const SizedBox(height: 32),

          // Sleep Regimes / History
          if (sleepState.regimes.isEmpty && !sleepState.isLoading)
             Center(child: Text(l10n.sleepDataSubtitle, style: const TextStyle(color: Colors.white24)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.detectedRegimes,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                ...sleepState.regimes.asMap().entries.map((entry) {
                  final regime = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SleepRegimeCard(
                      regime: regime,
                      initiallyExpanded: false, // All collapsed by default as requested
                    ),
                  );
                }),
              ],
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFC4B5FD), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoogleFitSyncCard extends ConsumerWidget {
  const _GoogleFitSyncCard({required this.googleFitState, required this.isLoading, this.error});
  final GoogleFitState googleFitState;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.refreshCw, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Text(
                l10n.googleFitSync,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              if (googleFitState.status == GoogleFitStatus.connected && !isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(l10n.connectedStatusSmall, style: const TextStyle(color: Colors.green, fontSize: 12)),
                ),
              if (isLoading)
                 const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                  ),
            ],
          ),
          const SizedBox(height: 20),
          if (googleFitState.status != GoogleFitStatus.connected)
            ElevatedButton(
              onPressed: () => ref.read(googleFitProvider.notifier).signIn(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(l10n.connectGoogleFit),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.lastFetchLabel, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    Text(
                      googleFitState.lastFetchTime != null 
                        ? DateFormat('HH:mm, d MMM').format(googleFitState.lastFetchTime!)
                        : l10n.never,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : () => ref.read(sleepProvider.notifier).syncWithGoogleFit(),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: Text(l10n.syncNow),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                ),
              ],
            ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFF87171), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

