import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/crash_report.dart';
import 'package:solaris/services/log_service.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/widgets/responsive_dialog_actions.dart';

/// Modal dialog presented when Solaris intercepts an unhandled exception.
/// Gives the user immediate access to view, open, or copy the traceback log.
class CrashDialog extends StatefulWidget {
  final CrashReport report;

  const CrashDialog({super.key, required this.report});

  @override
  State<CrashDialog> createState() => _CrashDialogState();
}

class _CrashDialogState extends State<CrashDialog> {
  bool _isCopied = false;
  bool _showFullStack = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = l10n?.crashDialogTitle ?? 'Unexpected Error';
    final subtitle =
        l10n?.crashDialogSubtitle ??
        'Solaris encountered an unhandled error. A detailed crash report has been saved to the logs folder.';
    final openFileLabel = l10n?.openLogFile ?? 'Open Log File';
    final openFolderLabel = l10n?.openLogsFolder ?? 'Open Logs Folder';
    final copyLabel = l10n?.copyCrashDetails ?? 'Copy Error';
    final copiedToast =
        l10n?.crashCopiedToast ?? 'Error details copied to clipboard';
    final closeLabel = l10n?.close ?? 'Close';
    final showTracebackLabel =
        l10n?.showTracebackDetails ?? 'Show Traceback Details';
    final hideTracebackLabel = l10n?.hideTraceback ?? 'Hide Traceback';
    final copiedLabel = l10n?.copied ?? 'Copied';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        borderRadius: 24,
        glowColor: const Color(0xFFEF4444),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.triangleAlert,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Exception Message Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.report.errorType,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.report.context,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        widget.report.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // StackTrace Preview
                InkWell(
                  onTap: () => setState(() => _showFullStack = !_showFullStack),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showFullStack
                              ? LucideIcons.chevronDown
                              : LucideIcons.chevronRight,
                          size: 16,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showFullStack
                              ? hideTracebackLabel
                              : showTracebackLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showFullStack) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        widget.report.stackTrace,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Action Buttons
                ResponsiveDialogActions(
                  leading: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: widget.report.toClipboardSummary(),
                            ),
                          );
                          setState(() => _isCopied = true);
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(
                              content: Text(copiedToast),
                              duration: const Duration(seconds: 2),
                              backgroundColor: const Color(0xFF1E1E2E),
                            ),
                          );
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _isCopied = false);
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: Icon(
                          _isCopied ? LucideIcons.check : LucideIcons.copy,
                          size: 14,
                          color: _isCopied
                              ? Colors.greenAccent
                              : Colors.white70,
                        ),
                        label: Text(
                          _isCopied ? copiedLabel : copyLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => LogService.instance.openCrashLog(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFDBA74),
                          side: BorderSide(
                            color: const Color(
                              0xFFFDBA74,
                            ).withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(LucideIcons.fileText, size: 14),
                        label: Text(
                          openFileLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => LogService.instance.openLogsFolder(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(LucideIcons.folder, size: 14),
                        label: Text(
                          openFolderLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFFEF4444,
                        ).withValues(alpha: 0.2),
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        closeLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
