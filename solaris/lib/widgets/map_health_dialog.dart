import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/map_health_report.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:url_launcher/url_launcher.dart';

class MapHealthDialog extends ConsumerWidget {
  final MapHealthReport report;

  const MapHealthDialog({super.key, required this.report});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: GlassCard(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.shieldAlert, color: Color(0xFFFDBA74), size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    l10n.mapIssueDetected,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!report.isTokenValid)
              _IssueItem(
                icon: LucideIcons.key,
                title: "Mapbox Token",
                description: l10n.mapboxTokenMissing,
              ),
            if (!report.isInternetAvailable)
              _IssueItem(
                icon: LucideIcons.wifiOff,
                title: "Internet",
                description: l10n.noInternetAccess,
              ),
            if (!report.isMapboxReachable && report.isInternetAvailable)
              const _IssueItem(
                icon: LucideIcons.serverOff,
                title: "Mapbox Servers",
                description: "Mapbox servers are currently unreachable. This might be a temporary service outage or a firewall issue.",
              ),
            if (!report.isVCRedistInstalled)
              _IssueItem(
                icon: LucideIcons.binary,
                title: "Visual C++ Redistributable",
                description: l10n.vcRedistMissing,
                action: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(
                      'https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170')),
                  icon: const Icon(LucideIcons.download, size: 14),
                  label: Text(l10n.downloadVcRedist),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDBA74),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(mapHealthProvider);
                  Navigator.of(context).pop();
                },
                icon: const Icon(LucideIcons.refreshCcw, size: 16),
                label: Text(l10n.retryDiagnostics),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white10),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _IssueItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  const _IssueItem({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.white54),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
