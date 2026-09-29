import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/expanded_gamma_provider.dart';
import 'package:solaris/services/monitor_service.dart';

Future<void> showExpandedGammaDialog(
  BuildContext context, {
  bool isPendingRestart = false,
}) async {
  debugPrint(
    '🪟 [ExpandedGammaDialog] Requesting showExpandedGammaDialog (isPendingRestart=$isPendingRestart)...',
  );
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) =>
          _ExpandedGammaDialogWidget(initialPendingRestart: isPendingRestart),
    );
    debugPrint('🪟 [ExpandedGammaDialog] showDialog dismissed cleanly.');
  } catch (e, st) {
    debugPrint('❌ [ExpandedGammaDialog] Error in showDialog: $e\n$st');
  }
}

class _ExpandedGammaDialogWidget extends ConsumerStatefulWidget {
  final bool initialPendingRestart;
  const _ExpandedGammaDialogWidget({this.initialPendingRestart = false});

  @override
  ConsumerState<_ExpandedGammaDialogWidget> createState() =>
      _ExpandedGammaDialogWidgetState();
}

class _ExpandedGammaDialogWidgetState
    extends ConsumerState<_ExpandedGammaDialogWidget> {
  bool _isElevating = false;
  bool _isRestarting = false;
  bool? _unlockedInDialog;
  String? _errorMessage;

  bool get _isLoading => _isElevating || _isRestarting;

  @override
  void initState() {
    super.initState();
    debugPrint('🪟 [ExpandedGammaDialog] Widget initState mounted');
  }

  @override
  void dispose() {
    debugPrint('🪟 [ExpandedGammaDialog] Widget dispose');
    super.dispose();
  }

  void _dismissDialog() {
    debugPrint('🔘 [ExpandedGammaDialog] Dismiss/Cancel triggered.');
    if (!mounted) {
      debugPrint(
        '⚠️ [ExpandedGammaDialog] Dismiss called but widget is not mounted.',
      );
      return;
    }
    try {
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('✅ [ExpandedGammaDialog] Navigator.pop successfully called.');
    } catch (e, st) {
      debugPrint(
        '❌ [ExpandedGammaDialog] Exception during Navigator.pop: $e\n$st',
      );
    }
  }

  Future<void> _handleUnlock() async {
    if (_isLoading) return;
    debugPrint('🔐 [ExpandedGammaDialog] Unlock requested by user.');
    setState(() {
      _isElevating = true;
      _errorMessage = null;
    });

    final success = await ref.read(expandedGammaProvider.notifier).unlock();
    debugPrint(
      '🔐 [ExpandedGammaDialog] Unlock finished with success=$success',
    );

    if (!mounted) {
      debugPrint('⚠️ [ExpandedGammaDialog] Widget not mounted after unlock.');
      return;
    }

    setState(() {
      _isElevating = false;
      if (success) {
        _unlockedInDialog = true;
      } else {
        final l10n = AppLocalizations.of(context)!;
        _errorMessage = l10n.expandedGammaFailed;
      }
    });
  }

  Future<void> _handleRestart() async {
    if (_isLoading) return;
    debugPrint('🔄 [ExpandedGammaDialog] Restart requested by user.');
    setState(() {
      _isRestarting = true;
      _errorMessage = null;
    });

    final notifier = ref.read(expandedGammaProvider.notifier);
    final success = await notifier.restartComputer();
    debugPrint(
      '🔄 [ExpandedGammaDialog] Restart finished with success=$success',
    );

    if (!mounted) {
      debugPrint('⚠️ [ExpandedGammaDialog] Widget not mounted after restart.');
      return;
    }

    setState(() {
      _isRestarting = false;
      if (!success) {
        final l10n = AppLocalizations.of(context)!;
        _errorMessage = l10n.expandedGammaRestartFailed;
      }
    });

    if (!success) return;

    _dismissDialog();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gammaStatus = ref.watch(expandedGammaProvider).value;
    final bool isSuccess =
        _unlockedInDialog ??
        (widget.initialPendingRestart ||
            gammaStatus == ExpandedGammaStatus.pendingRestart);

    final Color accentColor = isSuccess
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);
    final IconData headerIcon = isSuccess
        ? LucideIcons.circleCheck
        : LucideIcons.triangleAlert;
    final String title = isSuccess
        ? l10n.expandedGammaSuccessTitle
        : l10n.expandedGammaDialogTitle;
    final String body = isSuccess
        ? l10n.expandedGammaSuccessDescription
        : l10n.expandedGammaDialogDescription;

    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
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
                      color: accentColor,
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
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  headerIcon,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
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
                          Text(
                            body,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (_isLoading) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _isRestarting
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isRestarting
                                        ? l10n.expandedGammaRestarting
                                        : l10n.expandedGammaElevating,
                                    style: TextStyle(
                                      color: _isRestarting
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFF59E0B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (isSuccess) ...[
                                TextButton(
                                  onPressed: _isLoading ? null : _dismissDialog,
                                  child: Text(
                                    l10n.expandedGammaRestartLater,
                                    style: TextStyle(
                                      color: _isLoading
                                          ? Colors.white24
                                          : Colors.white60,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleRestart,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(l10n.expandedGammaRestartNow),
                                ),
                              ] else ...[
                                TextButton(
                                  onPressed: _isLoading ? null : _dismissDialog,
                                  child: Text(
                                    l10n.cancel,
                                    style: TextStyle(
                                      color: _isLoading
                                          ? Colors.white24
                                          : Colors.white60,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleUnlock,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(l10n.expandedGammaUnlockButton),
                                ),
                              ],
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
      ),
    );
  }
}
