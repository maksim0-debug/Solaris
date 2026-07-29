import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../env/env.dart';
import '../l10n/app_localizations.dart';
import '../models/update_info.dart';
import '../models/update_status.dart';
import '../providers/app_info_provider.dart';
import '../providers/update_provider.dart';
import 'custom_build_warning_dialog.dart';

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
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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
    final currentVersion = versionAsync.value ?? fallbackAppVersion;

    _updateAnimationState(updateStatus.phase);

    final labelText = _getLabelText(context, updateStatus, currentVersion);
    final statusColor = _getDotColor(updateStatus.phase);
    final isIdle = updateStatus.phase == UpdatePhase.idle;

    return GestureDetector(
      onTap: () => _handleTap(context, ref, updateStatus, currentVersion),
      child: Tooltip(
        message: labelText,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isIdle
                    ? Colors.white.withOpacity(0.12)
                    : statusColor.withOpacity(0.45),
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
                    final isPulsingPhase =
                        !isIdle &&
                        updateStatus.phase != UpdatePhase.error &&
                        updateStatus.phase != UpdatePhase.installing;
                    return Opacity(
                      opacity: isPulsingPhase ? _pulseAnimation.value : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(
                                isIdle ? 0.15 : 0.6,
                              ),
                              blurRadius: isIdle ? 2 : 4,
                              spreadRadius: isIdle ? 0 : 1,
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
        return Colors.white38;
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
        return Colors.blueAccent;
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
        return Colors.blueAccent;
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => const _UpdateReactiveDialog(),
    ).then((_) {
      if (context.mounted) {
        ref.read(updateProvider.notifier).resetUpToDateNotice();
      }
    });
  }
}

/// Reactive dialog container observing [updateProvider] to transition seamlessly
/// between checking, available, ready, error, and idle states without closing.
class _UpdateReactiveDialog extends ConsumerStatefulWidget {
  const _UpdateReactiveDialog();

  @override
  ConsumerState<_UpdateReactiveDialog> createState() =>
      _UpdateReactiveDialogState();
}

class _UpdateReactiveDialogState extends ConsumerState<_UpdateReactiveDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (ref.read(updateProvider).phase == UpdatePhase.checking) {
      _spinController.repeat();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _updateAnimationState(UpdatePhase phase) {
    if (phase == UpdatePhase.checking) {
      if (!_spinController.isAnimating) {
        _spinController.repeat();
      }
    } else {
      if (_spinController.isAnimating) {
        _spinController.stop();
      }
    }
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme == 'https' || uri.scheme == 'http') {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          developer.log(
            'Could not launch URL in external browser: $url',
            name: 'UpdateReactiveDialog',
          );
        }
      } else {
        developer.log(
          'Rejected non-HTTP/HTTPS URL scheme: $url',
          name: 'UpdateReactiveDialog',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error launching external URL ($url): $e',
        name: 'UpdateReactiveDialog',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _triggerManualCheck(BuildContext context) {
    if (!Env.isOfficialRelease) {
      showCustomBuildUpdateWarningDialog(
        context,
        isConfirmation: true,
        onConfirm: () {
          ref.read(updateProvider.notifier).checkForUpdate(isManual: true);
        },
      );
    } else {
      ref.read(updateProvider.notifier).checkForUpdate(isManual: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateStatus>(updateProvider, (previous, next) {
      _updateAnimationState(next.phase);
    });

    final status = ref.watch(updateProvider);
    final versionAsync = ref.watch(appVersionProvider);
    final currentVersion = versionAsync.value ?? fallbackAppVersion;
    final l10n = AppLocalizations.of(context);
    final currentVerText =
        l10n?.updateCurrentVersion(currentVersion) ??
        'Current version: v$currentVersion';

    switch (status.phase) {
      case UpdatePhase.checking:
        return _StyledDialog(
          icon: LucideIcons.refreshCw,
          iconColor: Colors.amberAccent,
          isSpinningIcon: true,
          spinAnimation: _spinController,
          title: l10n?.updateChecking ?? 'Checking for updates...',
          subtitle: currentVerText,
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.updateChecking ?? 'Checking for updates...',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          leftAction: TextButton.icon(
            onPressed: () => _launchExternalUrl(UpdateInfo.defaultReleasesUrl),
            icon: const Icon(LucideIcons.externalLink, size: 12),
            label: Text(l10n?.updateViewOnGithub ?? 'GitHub Releases'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white60,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n?.dpapiErrorActionOk ?? 'Close',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          ],
        );

      case UpdatePhase.available:
        final updateInfo = status.updateInfo;
        if (updateInfo == null) {
          return const SizedBox.shrink();
        }
        final sizeMb = (updateInfo.assetSize / (1024 * 1024)).toStringAsFixed(
          1,
        );
        return _StyledDialog(
          icon: LucideIcons.arrowUpCircle,
          iconColor: Colors.orangeAccent,
          title:
              l10n?.updateAvailableVersion(updateInfo.version) ??
              'Update: v${updateInfo.version}',
          subtitle: currentVerText,
          content: Column(
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
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      LucideIcons.externalLink,
                      size: 12,
                      color: Colors.orangeAccent,
                    ),
                    label: Text(
                      l10n?.updateViewOnGithub ?? 'GitHub Release',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    backgroundColor: Colors.white.withOpacity(0.08),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPressed: () =>
                        _launchExternalUrl(updateInfo.releasePageUrl),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                l10n?.updateReleaseNotes ?? 'Release Notes',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 360),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: updateInfo.releaseNotes.isNotEmpty
                        ? updateInfo.releaseNotes
                        : 'No release notes provided.',
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      h1: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      listBullet: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n?.updateLater ?? 'Later',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(updateProvider.notifier).startDownload();
              },
              icon: const Icon(LucideIcons.download, size: 14),
              label: Text(l10n?.updateAvailable ?? 'Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );

      case UpdatePhase.ready:
        return _StyledDialog(
          icon: LucideIcons.checkCircle2,
          iconColor: Colors.greenAccent,
          title: l10n?.updateReady ?? 'Ready to install ✓',
          subtitle: currentVerText,
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
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n?.updateLater ?? 'Later',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ref.read(updateProvider.notifier).installAndRestart();
              },
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text(l10n?.updateInstallRestart ?? 'Install & Restart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );

      case UpdatePhase.error:
        return _StyledDialog(
          icon: LucideIcons.alertTriangle,
          iconColor: Colors.redAccent,
          title: l10n?.updateError ?? 'Update Error ⚠',
          subtitle: currentVerText,
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              status.errorMessage ?? 'An error occurred during update process.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(updateProvider.notifier).resetError();
                Navigator.pop(context);
              },
              child: Text(
                l10n?.dpapiErrorActionOk ?? 'Close',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(updateProvider.notifier).resetError();
                _triggerManualCheck(context);
              },
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text(l10n?.updateRetry ?? 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );

      case UpdatePhase.downloading:
      case UpdatePhase.verifying:
      case UpdatePhase.installing:
        final pctVal = (status.downloadProgress * 100).toInt().clamp(0, 100);
        final pctStr = '$pctVal%';
        final isVerifying = status.phase == UpdatePhase.verifying;
        final isInstalling = status.phase == UpdatePhase.installing;
        final dialogTitle = isVerifying
            ? (l10n?.updateVerifying ?? 'Verifying integrity...')
            : isInstalling
            ? (l10n?.updateInstallingTitle ?? 'Updating...')
            : (l10n?.updateDownloadingPercent(pctVal.toString()) ??
                  'Downloading: $pctStr');

        final dialogIcon = isVerifying
            ? LucideIcons.shieldCheck
            : isInstalling
            ? LucideIcons.refreshCw
            : LucideIcons.download;

        final dialogIconColor = isVerifying
            ? Colors.cyanAccent
            : isInstalling
            ? Colors.blueAccent
            : Colors.lightBlueAccent;

        final statusText = isVerifying
            ? (l10n?.updateVerifying ?? 'Verifying integrity...')
            : isInstalling
            ? (l10n?.updateInstallingStatus ?? 'Installing update...')
            : (l10n?.updateDownloadingPackage ??
                  'Downloading update package...');

        final backgroundNotice =
            l10n?.updateBackgroundNotice ??
            'You can close this window. Process will continue in the background.';

        return _StyledDialog(
          icon: dialogIcon,
          iconColor: dialogIconColor,
          title: dialogTitle,
          subtitle: currentVerText,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (status.phase == UpdatePhase.downloading)
                    Text(
                      pctStr,
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: status.phase == UpdatePhase.downloading
                      ? status.downloadProgress
                      : null,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  color: dialogIconColor,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    LucideIcons.info,
                    size: 13,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      backgroundNotice,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                l10n?.dpapiErrorActionOk ?? 'Close',
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          ],
        );

      case UpdatePhase.idle:
        if (status.isUpToDateNotice) {
          return _StyledDialog(
            icon: LucideIcons.checkCircle2,
            iconColor: Colors.greenAccent,
            title: l10n?.updateNoUpdatesTitle ?? 'No updates found',
            subtitle: currentVerText,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.updateNoUpdatesFound ??
                      'No updates found. You are running the latest version.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            leftAction: TextButton.icon(
              onPressed: () =>
                  _launchExternalUrl(UpdateInfo.defaultReleasesUrl),
              icon: const Icon(LucideIcons.externalLink, size: 12),
              label: Text(l10n?.updateViewOnGithub ?? 'GitHub Releases'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  ref.read(updateProvider.notifier).resetUpToDateNotice();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(l10n?.dialogOk ?? 'OK'),
              ),
            ],
          );
        } else {
          return _StyledDialog(
            icon: LucideIcons.info,
            iconColor: Colors.orangeAccent,
            title: 'Solaris v$currentVersion',
            subtitle: currentVerText,
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
            leftAction: TextButton.icon(
              onPressed: () =>
                  _launchExternalUrl(UpdateInfo.defaultReleasesUrl),
              icon: const Icon(LucideIcons.externalLink, size: 12),
              label: Text(l10n?.updateViewOnGithub ?? 'GitHub Releases'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n?.dpapiErrorActionOk ?? 'Close',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _triggerManualCheck(context);
                },
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: Text(l10n?.updateCheckForUpdates ?? 'Check for updates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          );
        }
    }
  }
}

/// Custom dark theme styled dialog container matching Solaris visual aesthetic.
class _StyledDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget content;
  final Widget? leftAction;
  final List<Widget> actions;
  final bool isSpinningIcon;
  final Animation<double>? spinAnimation;

  const _StyledDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.content,
    this.leftAction,
    required this.actions,
    this.isSpinningIcon = false,
    this.spinAnimation,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: iconColor, size: 20);
    if (isSpinningIcon && spinAnimation != null) {
      iconWidget = RotationTransition(turns: spinAnimation!, child: iconWidget);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: iconWidget,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (subtitle != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      subtitle!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        content,
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (leftAction != null)
                              Flexible(child: leftAction!)
                            else
                              const SizedBox.shrink(),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 2,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: actions,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
