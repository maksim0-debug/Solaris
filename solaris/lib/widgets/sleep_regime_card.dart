import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/widgets/add_sleep_session_dialog.dart';

class SleepRegimeCard extends StatefulWidget {
  final SleepRegime regime;
  final bool initiallyExpanded;

  const SleepRegimeCard({
    super.key,
    required this.regime,
    this.initiallyExpanded = false,
  });

  @override
  State<SleepRegimeCard> createState() => _SleepRegimeCardState();
}

class _SleepRegimeCardState extends State<SleepRegimeCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Date Range & Day Count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDateRange(
                        start: widget.regime.startDate.toLocal(),
                        end: widget.regime.endDate.toLocal(),
                        locale: l10n.localeName,
                        includeYear: false,
                      ),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.daysCount(widget.regime.dayCount),
                            style: const TextStyle(
                              color: Color(0xFFC4B5FD),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isExpanded
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            color: const Color(0xFFC4B5FD),
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Middle Row: Average Bedtime
                Row(
                  children: [
                    const Icon(
                      LucideIcons.moon,
                      color: Color(0xFF8B5CF6),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '~ ${widget.regime.averageBedtimeFormatted}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bottom Row: Scatter
                Text(
                  '${l10n.scatter}: ${widget.regime.windowStart} — ${widget.regime.windowEnd}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Content: Sessions
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          ...widget.regime.nights.map((night) {
            final isAnomaly = widget.regime.anomalyDates.any(
              (d) =>
                  d.year == night.date.year &&
                  d.month == night.date.month &&
                  d.day == night.date.day,
            );
            return _SessionDetailRow(night: night, isAnomaly: isAnomaly);
          }),
        ],
      ],
    );
  }
}

class _SessionDetailRow extends ConsumerWidget {
  final NightGroup night;
  final bool isAnomaly;

  const _SessionDetailRow({required this.night, this.isAnomaly = false});

  void _onEditRow(BuildContext context) {
    if (!context.mounted) return;
    if (night.allSessions.length > 1) {
      AddSleepSessionDialog.show(
        context,
        initialSession: night.aggregatedSession,
        sessionIdsToReplaceOnSave: night.allSessions.map((s) => s.id).toList(),
      );
    } else {
      final sessionToEdit =
          night.allSessions.firstOrNull ?? night.aggregatedSession;
      AddSleepSessionDialog.show(context, initialSession: sessionToEdit);
    }
  }

  void _onDeleteRow(BuildContext context, WidgetRef ref) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final session = night.aggregatedSession;
    final dateRangeStr = _formatDateRange(
      start: session.startTime.toLocal(),
      end: session.endTime.toLocal(),
      locale: l10n.localeName,
    );

    final sessionIds = night.allSessions.map((s) => s.id).toList();

    _showDeleteSleepConfirmDialog(
      context: context,
      ref: ref,
      title: l10n.deleteSleepSessionTitle,
      confirmMessage: l10n.deleteSleepSessionConfirm(dateRangeStr),
      sessionIdsToDelete: sessionIds,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = night.aggregatedSession;

    // Calculate total duration as sum of all sessions (excluding gaps)
    final totalDuration = night.allSessions.fold<Duration>(
      Duration.zero,
      (prev, s) => prev + s.duration,
    );

    final editLabel = night.allSessions.length > 1
        ? l10n.mergeAndEditNight
        : l10n.editSleepSession;

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: GestureDetector(
        onTap: () => _onEditRow(context),
        onLongPress: () => _onDeleteRow(context, ref),
        onSecondaryTapUp: (details) => _showSleepContextMenu(
          context,
          globalPosition: details.globalPosition,
          onEdit: () => _onEditRow(context),
          onDelete: () => _onDeleteRow(context, ref),
          editLabel: editLabel,
          deleteLabel: l10n.deleteSleepSessionTitle,
        ),
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                _formatDateRange(
                                  start: session.startTime.toLocal(),
                                  end: session.endTime.toLocal(),
                                  locale: l10n.localeName,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (isAnomaly)
                                Tooltip(
                                  message: l10n.regimeAnomalyTooltip,
                                  waitDuration: const Duration(
                                    milliseconds: 200,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.18),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          LucideIcons.info,
                                          size: 10.5,
                                          color: const Color(
                                            0xFFFDE68A,
                                          ).withValues(alpha: 0.85),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          l10n.regimeAnomaly,
                                          style: TextStyle(
                                            color: const Color(
                                              0xFFFDE68A,
                                            ).withValues(alpha: 0.85),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (night.isOutdated)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.outdated.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFFFF8A80),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('HH:mm').format(session.startTime.toLocal())} — ${DateFormat('HH:mm').format(session.endTime.toLocal())}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${totalDuration.inHours}${l10n.hoursAbbreviation} ${totalDuration.inMinutes % 60}${l10n.minutesAbbreviation}',
                      style: const TextStyle(
                        color: Color(0xFFC4B5FD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Sub-sessions chips
                if (night.allSessions.length > 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: night.allSessions
                        .map((s) => _SessionChip(session: s))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionChip extends ConsumerWidget {
  final SleepSession session;

  const _SessionChip({required this.session});

  void _onEditChip(BuildContext context) {
    if (!context.mounted) return;
    AddSleepSessionDialog.show(
      context,
      initialSession: session,
      isSegment: true,
    );
  }

  void _onDeleteChip(BuildContext context, WidgetRef ref) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat('HH:mm');
    final timeRangeStr =
        '${timeFormat.format(session.startTime.toLocal())}–${timeFormat.format(session.endTime.toLocal())}';

    _showDeleteSleepConfirmDialog(
      context: context,
      ref: ref,
      title: l10n.deleteSleepSegmentTitle,
      confirmMessage: l10n.deleteSleepSegmentConfirm(timeRangeStr),
      sessionIdsToDelete: [session.id],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat('HH:mm');
    return GestureDetector(
      onTap: () => _onEditChip(context),
      onLongPress: () => _onDeleteChip(context, ref),
      onSecondaryTapUp: (details) => _showSleepContextMenu(
        context,
        globalPosition: details.globalPosition,
        onEdit: () => _onEditChip(context),
        onDelete: () => _onDeleteChip(context, ref),
        editLabel: l10n.editSleepSegment,
        deleteLabel: l10n.deleteAction,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Text(
            '${timeFormat.format(session.startTime.toLocal())}–${timeFormat.format(session.endTime.toLocal())}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showSleepContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required String editLabel,
  required String deleteLabel,
}) async {
  final screenSize = MediaQuery.of(context).size;
  const menuWidth = 240.0;
  const menuHeight = 90.0;

  // Prevent menu from overflowing viewport edges
  final maxLeft = (screenSize.width - menuWidth - 16).clamp(
    8.0,
    double.infinity,
  );
  final left = globalPosition.dx.clamp(8.0, maxLeft);
  final top = (globalPosition.dy + menuHeight > screenSize.height - 16)
      ? (globalPosition.dy - menuHeight).clamp(8.0, double.infinity)
      : globalPosition.dy.clamp(8.0, double.infinity);

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (ctx, _, secondAnim) {
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: _SleepContextMenuOverlay(
              onEdit: () {
                Navigator.of(ctx).pop();
                if (context.mounted) {
                  onEdit();
                }
              },
              onDelete: () {
                Navigator.of(ctx).pop();
                if (context.mounted) {
                  onDelete();
                }
              },
              editLabel: editLabel,
              deleteLabel: deleteLabel,
            ),
          ),
        ],
      );
    },
  );
}

class _SleepContextMenuOverlay extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;

  const _SleepContextMenuOverlay({
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.8),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.9,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SleepContextMenuItem(
                    icon: LucideIcons.pencil,
                    iconColor: const Color(0xFFC4B5FD),
                    label: editLabel,
                    onTap: onEdit,
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  _SleepContextMenuItem(
                    icon: LucideIcons.trash2,
                    iconColor: const Color(0xFFF87171),
                    textColor: const Color(0xFFF87171),
                    hoverColor: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    hoverBorderColor: const Color(
                      0xFFEF4444,
                    ).withValues(alpha: 0.25),
                    label: deleteLabel,
                    onTap: onDelete,
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

class _SleepContextMenuItem extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? textColor;
  final Color? hoverColor;
  final Color? hoverBorderColor;
  final VoidCallback onTap;

  const _SleepContextMenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.textColor,
    this.hoverColor,
    this.hoverBorderColor,
    required this.onTap,
  });

  @override
  State<_SleepContextMenuItem> createState() => _SleepContextMenuItemState();
}

class _SleepContextMenuItemState extends State<_SleepContextMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveHoverBg =
        widget.hoverColor ?? Colors.white.withValues(alpha: 0.08);
    final effectiveHoverBorder =
        widget.hoverBorderColor ?? Colors.white.withValues(alpha: 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? effectiveHoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _isHovered
                ? Border.all(color: effectiveHoverBorder, width: 0.8)
                : Border.all(color: Colors.transparent, width: 0.8),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 15),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color:
                        widget.textColor ??
                        Colors.white.withValues(alpha: 0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showDeleteSleepConfirmDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String confirmMessage,
  required List<String> sessionIdsToDelete,
}) async {
  final l10n = AppLocalizations.of(context)!;
  bool doNotSync = true;

  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            title: Row(
              children: [
                const Icon(
                  LucideIcons.trash2,
                  color: Color(0xFFF87171),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confirmMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => doNotSync = !doNotSync),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: doNotSync,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => doNotSync = val);
                              }
                            },
                            activeColor: const Color(0xFF8B5CF6),
                            checkColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.doNotSyncInFuture,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  l10n.cancelAction,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref
                      .read(sleepProvider.notifier)
                      .deleteSessions(sessionIdsToDelete, doNotSync: doNotSync);
                },
                child: Text(l10n.deleteAction),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatDateRange({
  required DateTime start,
  required DateTime end,
  required String locale,
  bool includeYear = true,
}) {
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);

  if (startDay.isAtSameMomentAs(endDay)) {
    return DateFormat(
      includeYear ? 'd MMM, yyyy' : 'd MMM',
      locale,
    ).format(start);
  }

  // Cross-day range
  if (start.year == end.year && start.month == end.month) {
    final monthPart = DateFormat(
      includeYear ? 'MMM, yyyy' : 'MMM',
      locale,
    ).format(end);
    return '${start.day} — ${end.day} $monthPart';
  } else if (start.year == end.year) {
    final startPart = DateFormat('d MMM', locale).format(start);
    final endPart = DateFormat(
      includeYear ? 'd MMM, yyyy' : 'd MMM',
      locale,
    ).format(end);
    return '$startPart — $endPart';
  } else {
    final startPart = DateFormat(
      includeYear ? 'd MMM, yyyy' : 'd MMM',
      locale,
    ).format(start);
    final endPart = DateFormat(
      includeYear ? 'd MMM, yyyy' : 'd MMM',
      locale,
    ).format(end);
    return '$startPart — $endPart';
  }
}
