import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';

/// Shows the modal dialog displaying the newly generated token once to the user.
Future<void> showNewTokenDialog(
  BuildContext context, {
  required String token,
  required String keyName,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ShowNewTokenDialog(token: token, keyName: keyName),
  );
}

class ShowNewTokenDialog extends StatelessWidget {
  final String token;
  final String keyName;

  const ShowNewTokenDialog({
    super.key,
    required this.token,
    required this.keyName,
  });

  void _copyToClipboard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.apiKeysCopySuccessSnackbar),
        backgroundColor: const Color(0xFF4ADE80),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                        LucideIcons.keyRound,
                        color: Color(0xFFFDBA74),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${l10n.showNewTokenDialogTitle} — $keyName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Security Warning Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.alertTriangle,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.showNewTokenWarning,
                              style: const TextStyle(
                                color: Color(0xFFFDE68A),
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Token Monospace Read-Only Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.key, color: Color(0xFFFDBA74), size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              token,
                              style: const TextStyle(
                                fontFamily: 'Consolas',
                                fontSize: 13,
                                color: Color(0xFF4ADE80),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.copy, color: Colors.white70, size: 18),
                            onPressed: () => _copyToClipboard(context),
                            tooltip: l10n.copyTokenButton,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyToClipboard(context),
                      icon: const Icon(LucideIcons.copy, size: 16),
                      label: Text(l10n.copyTokenButton),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFDBA74),
                        side: const BorderSide(color: Color(0xFFFDBA74)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.checkCheck, size: 16),
                      label: Text(l10n.savedTokenButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ADE80),
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
