import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n/app_localizations.dart';
import '../models/update_info.dart';
import '../models/update_status.dart';
import '../providers/app_info_provider.dart';
import '../providers/update_provider.dart';

/// Interactive update status widget integrated into the Dashboard status bar.
///
/// Dynamically updates its label, dot indicator animation, color and tap action
/// based on the current [UpdatePhase].
class UpdateStatusWidget extends ConsumerStatefulWidget {
  const UpdateStatusWidget({super.key});

  @override
  ConsumerState<UpdateStatusWidget> createState() => _UpdateStatusWidgetState();
}

class _UpdateStatusWidgetState extends ConsumerState<UpdateStatusWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateAnimationState(UpdatePhase phase) {
    switch (phase) {
      case UpdatePhase.checking:
      case UpdatePhase.available:
      case UpdatePhase.downloading:
      case UpdatePhase.verifying:
      case UpdatePhase.ready:
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
        break;
      case UpdatePhase.idle:
      case UpdatePhase.installing:
      case UpdatePhase.error:
        if (_pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.value = 1.0;
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateStatus = ref.watch(updateProvider);
    final versionAsync = ref.watch(appVersionProvider);
    final currentVersion = versionAsync.value ?? '1.0.17';

    _updateAnimationState(updateStatus.phase);

    final labelText = _getLabelText(context, updateStatus, currentVersion);
    final dotColor = _getDotColor(updateStatus.phase);

    return GestureDetector(
      onTap: () => _handleTap(context, ref, updateStatus, currentVersion),
      child: Tooltip(
        message: labelText,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: dotColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    labelText,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _getTextColor(updateStatus.phase),
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final isPulsingPhase = updateStatus.phase != UpdatePhase.idle &&
                        updateStatus.phase != UpdatePhase.error &&
                        updateStatus.phase != UpdatePhase.installing;
                    return Opacity(
                      opacity: isPulsingPhase ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: dotColor.withOpacity(0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLabelText(
    BuildContext context,
    UpdateStatus status,
    String currentVersion,
  ) {
    final l10n = AppLocalizations.of(context);
    final fallbackVersion = 'v$currentVersion';

    switch (status.phase) {
      case UpdatePhase.idle:
        return l10n?.appVersion(currentVersion) ?? 'Solaris $fallbackVersion ★';
      case UpdatePhase.checking:
        return l10n?.updateChecking ?? 'Checking for updates...';
      case UpdatePhase.available:
        final newVer = status.updateInfo?.version ?? '';
        return l10n?.updateAvailableVersion(newVer) ?? 'Update: v$newVer ⬆';
      case UpdatePhase.downloading:
        final pct = (status.downloadProgress * 100).toInt().toString();
        return l10n?.updateDownloadingPercent(pct) ?? 'Downloading: $pct% ↓';
      case UpdatePhase.verifying:
        return l10n?.updateVerifying ?? 'Verifying integrity...';
      case UpdatePhase.ready:
        return l10n?.updateReady ?? 'Ready to install ✓';
      case UpdatePhase.installing:
        return 'Updating...';
      case UpdatePhase.error:
        return l10n?.updateError ?? 'Update error ⚠';
    }
  }

  Color _getDotColor(UpdatePhase phase) {
    switch (phase) {
      case UpdatePhase.idle:
        return Colors.orange;
      case UpdatePhase.checking:
        return Colors.amber;
      case UpdatePhase.available:
        return Colors.orangeAccent;
      case UpdatePhase.downloading:
        return Colors.lightBlueAccent;
      case UpdatePhase.verifying:
        return Colors.cyanAccent;
      case UpdatePhase.ready:
        return Colors.greenAccent;
      case UpdatePhase.installing:
        return Colors.blue;
      case UpdatePhase.error:
        return Colors.redAccent;
    }
  }

  Color _getTextColor(UpdatePhase phase) {
    switch (phase) {
      case UpdatePhase.idle:
        return Colors.white70;
      case UpdatePhase.checking:
        return Colors.amberAccent;
      case UpdatePhase.available:
        return Colors.orangeAccent;
      case UpdatePhase.downloading:
        return Colors.lightBlueAccent;
      case UpdatePhase.verifying:
        return Colors.cyanAccent;
      case UpdatePhase.ready:
        return Colors.greenAccent;
      case UpdatePhase.installing:
        return Colors.lightBlue;
      case UpdatePhase.error:
        return Colors.redAccent;
    }
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    UpdateStatus status,
    String currentVersion,
  ) {
    switch (status.phase) {
      case UpdatePhase.idle:
        _showIdleDialog(context, ref, currentVersion);
        break;
      case UpdatePhase.available:
        if (status.updateInfo != null) {
          _showAvailableDialog(context, ref, status.updateInfo!);
        }
        break;
      case UpdatePhase.ready:
        _showReadyDialog(context, ref);
        break;
      case UpdatePhase.error:
        _showErrorDialog(context, ref, status.errorMessage);
        break;
      case UpdatePhase.checking:
      case UpdatePhase.downloading:
      case UpdatePhase.verifying:
      case UpdatePhase.installing:
        // Operational phases — non-interactive during action
        break;
    }
  }

  void _showIdleDialog(
    BuildContext context,
    WidgetRef ref,
    String currentVersion,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _StyledDialog(
        icon: LucideIcons.info,
        iconColor: Colors.orangeAccent,
        title: 'Solaris v$currentVersion',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.appVersion(currentVersion) ?? 'Solaris is up to date.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n?.dpapiErrorActionOk ?? 'Close',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(updateProvider.notifier).checkForUpdate(isManual: true);
            },
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: Text(l10n?.updateCheckForUpdates ?? 'Check for updates'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvailableDialog(
    BuildContext context,
    WidgetRef ref,
    UpdateInfo updateInfo,
  ) {
    final l10n = AppLocalizations.of(context);
    final sizeMb = (updateInfo.assetSize / (1024 * 1024)).toStringAsFixed(1);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _StyledDialog(
        icon: LucideIcons.arrowUpCircle,
        iconColor: Colors.orangeAccent,
        title: l10n?.updateAvailableVersion(updateInfo.version) ??
            'Update: v${updateInfo.version}',
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    avatar: const Icon(LucideIcons.hardDrive, size: 12),
                    label: Text(
                      l10n?.updateFileSize('$sizeMb MB') ?? '$sizeMb MB',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.08),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n?.updateReleaseNotes ?? 'Release Notes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: updateInfo.releaseNotes.isNotEmpty
                        ? updateInfo.releaseNotes
                        : 'No release notes provided.',
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white70, fontSize: 12),
                      h1: const TextStyle(color: Colors.white, fontSize: 14),
                      h2: const TextStyle(color: Colors.white, fontSize: 13),
                      listBullet: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(updateProvider.notifier).dismissUpdate();
            },
            child: Text(
              l10n?.updateLater ?? 'Later',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(updateProvider.notifier).startDownload();
            },
            icon: const Icon(LucideIcons.download, size: 14),
            label: Text(l10n?.updateAvailable ?? 'Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReadyDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _StyledDialog(
        icon: LucideIcons.checkCircle2,
        iconColor: Colors.greenAccent,
        title: l10n?.updateReady ?? 'Ready to install ✓',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.updateRestartWarning ??
                  'Application will restart to apply the update.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n?.updateLater ?? 'Later',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(updateProvider.notifier).installAndRestart();
            },
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: Text(l10n?.updateInstallRestart ?? 'Install & Restart'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(
    BuildContext context,
    WidgetRef ref,
    String? errorMessage,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _StyledDialog(
        icon: LucideIcons.alertTriangle,
        iconColor: Colors.redAccent,
        title: l10n?.updateError ?? 'Update Error ⚠',
        content: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Text(
            errorMessage ?? 'An error occurred during update process.',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(updateProvider.notifier).resetError();
            },
            child: Text(
              l10n?.dpapiErrorActionOk ?? 'Close',
              style: const TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              ref.read(updateProvider.notifier).checkForUpdate(isManual: true);
            },
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: Text(l10n?.updateRetry ?? 'Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom dark theme styled dialog container matching Solaris visual aesthetic.
class _StyledDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget content;
  final List<Widget> actions;

  const _StyledDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
