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
import 'package:solaris/models/settings_state.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/providers/sleep_provider.dart';
import 'package:solaris/widgets/add_sleep_session_dialog.dart';

class SleepRegimeCard extends ConsumerStatefulWidget {
  final SleepRegime regime;
  final bool initiallyExpanded;
  final int? initialVisibleCount;

  const SleepRegimeCard({
    super.key,
    required this.regime,
    this.initiallyExpanded = false,
    this.initialVisibleCount,
  });

  @override
  ConsumerState<SleepRegimeCard> createState() => _SleepRegimeCardState();
}

class _SleepRegimeCardState extends ConsumerState<SleepRegimeCard> {
  late bool _isExpanded;
  int? _visibleSessionsLimit;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final selectedMonitors = ref.watch(selectedMonitorsProvider);
    final monitorId = selectedMonitors.firstOrNull ?? 'all';
    final settings = settingsAsync.maybeWhen(
      data: (map) => map[monitorId] ?? map['all'] ?? SettingsState(),
      orElse: () => SettingsState(),
    );

    final totalNights = widget.regime.nights.length;
    final defaultLimit =
        widget.initialVisibleCount ??
        settings.sleepVisibleSessionsCount.clamp(1, 50);
    final activeLimit =
        _visibleSessionsLimit != null && _visibleSessionsLimit! > defaultLimit
        ? _visibleSessionsLimit!
        : defaultLimit;
    final displayedCount = activeLimit > totalNights
        ? totalNights
        : (activeLimit < 0 ? 0 : activeLimit);
    final visibleNights = widget.regime.nights.take(displayedCount).toList();
    final hasMore = displayedCount < totalNights;
    final canCollapse =
        _visibleSessionsLimit != null && displayedCount > defaultLimit;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header section (Interactive to expand / collapse)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Date Range & Day Count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.regime.isPermanent)
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.repeat,
                                        size: 12,
                                        color: Color(0xFFC4B5FD),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        l10n.permanentScheduleBadge,
                                        style: const TextStyle(
                                          color: Color(0xFFC4B5FD),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    l10n.dailyScheduleTitle,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
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
                            color: const Color(
                              0xFF8B5CF6,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!widget.regime.isPermanent) ...[
                                Text(
                                  l10n.daysCount(widget.regime.dayCount),
                                  style: const TextStyle(
                                    color: Color(0xFFC4B5FD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
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

                    // Bottom Row: Scatter or Permanent schedule bounds
                    Text(
                      widget.regime.isPermanent
                          ? '${widget.regime.averageBedtimeFormatted} — ${widget.regime.averageWakeTimeFormatted}'
                          : '${l10n.scatter}: ${widget.regime.windowStart} — ${widget.regime.windowEnd}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded Content: Sessions inside the same GlassCard
          if (_isExpanded) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                children: [
                  for (final (i, night) in visibleNights.indexed) ...[
                    _SessionDetailRow(
                      key: ValueKey(night.aggregatedSession.id),
                      night: night,
                      isAnomaly: widget.regime.anomalyDates.any(
                        (d) =>
                            d.year == night.date.year &&
                            d.month == night.date.month &&
                            d.day == night.date.day,
                      ),
                    ),
                    if (i < visibleNights.length - 1) const SizedBox(height: 8),
                  ],
                  if (hasMore || canCollapse) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasMore) ...[
                          _PaginationButton(
                            key: const ValueKey('pagination_show_more'),
                            icon: LucideIcons.chevronDown,
                            label: l10n.showMoreSessions(
                              (totalNights - displayedCount) < defaultLimit
                                  ? (totalNights - displayedCount)
                                  : defaultLimit,
                            ),
                            isSecondary: true,
                            onTap: () {
                              setState(() {
                                final next = displayedCount + defaultLimit;
                                _visibleSessionsLimit = next > totalNights
                                    ? totalNights
                                    : next;
                              });
                            },
                          ),
                          if (totalNights - displayedCount > defaultLimit) ...[
                            const SizedBox(width: 8),
                            _PaginationIconButton(
                              key: const ValueKey('pagination_show_all'),
                              icon: LucideIcons.ellipsis,
                              tooltip: l10n.showAllSessions(totalNights),
                              onTap: () {
                                setState(() {
                                  _visibleSessionsLimit = totalNights;
                                });
                              },
                            ),
                          ],
                        ],
                        if (canCollapse) ...[
                          if (hasMore) const SizedBox(width: 8),
                          _PaginationButton(
                            key: const ValueKey('pagination_collapse'),
                            icon: LucideIcons.chevronUp,
                            label: l10n.collapseSessions,
                            isSecondary: true,
                            onTap: () {
                              setState(() {
                                _visibleSessionsLimit = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionDetailRow extends ConsumerStatefulWidget {
  final NightGroup night;
  final bool isAnomaly;

  const _SessionDetailRow({
    super.key,
    required this.night,
    this.isAnomaly = false,
  });

  @override
  ConsumerState<_SessionDetailRow> createState() => _SessionDetailRowState();
}

class _SessionDetailRowState extends ConsumerState<_SessionDetailRow> {
  bool _isHovered = false;

  void _onEditRow(BuildContext context) {
    if (!context.mounted) return;
    if (widget.night.allSessions.length > 1) {
      AddSleepSessionDialog.show(
        context,
        initialSession: widget.night.aggregatedSession,
        sessionIdsToReplaceOnSave: widget.night.allSessions
            .map((s) => s.id)
            .toList(),
      );
    } else {
      final sessionToEdit =
          widget.night.allSessions.firstOrNull ??
          widget.night.aggregatedSession;
      AddSleepSessionDialog.show(context, initialSession: sessionToEdit);
    }
  }

  void _onDeleteRow(BuildContext context) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final session = widget.night.aggregatedSession;
    final dateRangeStr = _formatDateRange(
      start: session.startTime.toLocal(),
      end: session.endTime.toLocal(),
      locale: l10n.localeName,
    );

    final sessionIds = widget.night.allSessions.map((s) => s.id).toList();

    _showDeleteSleepConfirmDialog(
      context: context,
      ref: ref,
      title: l10n.deleteSleepSessionTitle,
      confirmMessage: l10n.deleteSleepSessionConfirm(dateRangeStr),
      sessionIdsToDelete: sessionIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.night.aggregatedSession;

    // Calculate total duration as sum of all sessions (excluding gaps)
    final totalDuration = widget.night.allSessions.fold<Duration>(
      Duration.zero,
      (prev, s) => prev + s.duration,
    );

    final editLabel = widget.night.allSessions.length > 1
        ? l10n.mergeAndEditNight
        : l10n.editSleepSession;
    final isPermanent =
        session.isPermanent ||
        widget.night.allSessions.any((s) => s.isPermanent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: () => _onEditRow(context),
        onLongPress: () => _onDeleteRow(context),
        onSecondaryTapUp: (details) => _showSleepContextMenu(
          context,
          globalPosition: details.globalPosition,
          onEdit: () => _onEditRow(context),
          onDelete: () => _onDeleteRow(context),
          onTogglePermanent: () {
            if (isPermanent) {
              // Disabling: find whichever session in this night has isPermanent == true
              final target = widget.night.allSessions.firstWhere(
                (s) => s.isPermanent,
                orElse: () => session,
              );
              ref
                  .read(sleepProvider.notifier)
                  .setSessionPermanent(target.id, false);
            } else {
              // Enabling: if fragmented into multiple sessions, consolidate into the aggregated bounds
              if (widget.night.allSessions.length > 1) {
                final consolidated = widget.night.aggregatedSession.copyWith(
                  isPermanent: true,
                  source: 'manual',
                );
                ref
                    .read(sleepProvider.notifier)
                    .consolidateNightSessions(
                      oldSessionIds: widget.night.allSessions
                          .map((s) => s.id)
                          .toList(),
                      newSession: consolidated,
                    );
              } else {
                final targetId = widget.night.allSessions.isNotEmpty
                    ? widget.night.allSessions.first.id
                    : session.id;
                ref
                    .read(sleepProvider.notifier)
                    .setSessionPermanent(targetId, true);
              }
            }
          },
          editLabel: editLabel,
          deleteLabel: l10n.deleteSleepSessionTitle,
          permanentLabel: isPermanent
              ? l10n.removePermanentScheduleAction
              : l10n.makePermanentScheduleAction,
          isPermanent: isPermanent,
        ),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.025),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
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
                            if (isPermanent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.repeat,
                                      size: 10.5,
                                      color: Color(0xFFC4B5FD),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.permanentScheduleBadge,
                                      style: const TextStyle(
                                        color: Color(0xFFC4B5FD),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (widget.isAnomaly)
                              Tooltip(
                                message: l10n.regimeAnomalyTooltip,
                                waitDuration: const Duration(milliseconds: 200),
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
              if (widget.night.allSessions.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.night.allSessions
                      .map((s) => _SessionChip(session: s))
                      .toList(),
                ),
              ],
            ],
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
        onTogglePermanent: () {
          ref
              .read(sleepProvider.notifier)
              .setSessionPermanent(session.id, !session.isPermanent);
        },
        editLabel: l10n.editSleepSegment,
        deleteLabel: l10n.deleteAction,
        permanentLabel: session.isPermanent
            ? l10n.removePermanentScheduleAction
            : l10n.makePermanentScheduleAction,
        isPermanent: session.isPermanent,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: session.isPermanent
                ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: session.isPermanent
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (session.isPermanent) ...[
                const Icon(
                  LucideIcons.repeat,
                  size: 10,
                  color: Color(0xFFC4B5FD),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '${timeFormat.format(session.startTime.toLocal())}–${timeFormat.format(session.endTime.toLocal())}',
                style: TextStyle(
                  color: session.isPermanent
                      ? const Color(0xFFC4B5FD)
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
  VoidCallback? onTogglePermanent,
  required String editLabel,
  required String deleteLabel,
  String? permanentLabel,
  bool isPermanent = false,
}) async {
  final screenSize = MediaQuery.of(context).size;
  const menuWidth = 240.0;
  final menuHeight = onTogglePermanent != null ? 135.0 : 90.0;

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
              onTogglePermanent: onTogglePermanent != null
                  ? () {
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        onTogglePermanent();
                      }
                    }
                  : null,
              editLabel: editLabel,
              deleteLabel: deleteLabel,
              permanentLabel: permanentLabel,
              isPermanent: isPermanent,
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
  final VoidCallback? onTogglePermanent;
  final String editLabel;
  final String deleteLabel;
  final String? permanentLabel;
  final bool isPermanent;

  const _SleepContextMenuOverlay({
    required this.onEdit,
    required this.onDelete,
    this.onTogglePermanent,
    required this.editLabel,
    required this.deleteLabel,
    this.permanentLabel,
    this.isPermanent = false,
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
                  if (onTogglePermanent != null && permanentLabel != null) ...[
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    _SleepContextMenuItem(
                      icon: isPermanent ? LucideIcons.repeat : LucideIcons.pin,
                      iconColor: isPermanent
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFFA78BFA),
                      label: permanentLabel!,
                      onTap: onTogglePermanent!,
                    ),
                  ],
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
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            contentPadding: EdgeInsets.zero,
            clipBehavior: Clip.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: GlassCard(
                borderRadius: 20,
                opacity: 0.06,
                blur: 20,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.trash2,
                            color: Color(0xFFF87171),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            color: Colors.white60,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      confirmMessage,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => doNotSync = !doNotSync),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: doNotSync
                                ? const Color(
                                    0xFFFDBA74,
                                  ).withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: doNotSync
                                  ? const Color(
                                      0xFFFDBA74,
                                    ).withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                  activeColor: const Color(0xFFFDBA74),
                                  checkColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.doNotSyncInFuture,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white.withValues(alpha: 0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.75,
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            l10n.cancelAction,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(LucideIcons.trash2, size: 15),
                          label: Text(
                            l10n.deleteAction,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            ref
                                .read(sleepProvider.notifier)
                                .deleteSessions(
                                  sessionIdsToDelete,
                                  doNotSync: doNotSync,
                                );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

class _PaginationButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  const _PaginationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  State<_PaginationButton> createState() => _PaginationButtonState();
}

class _PaginationButtonState extends State<_PaginationButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeBg = widget.isSecondary
        ? (_isHovered
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.03))
        : (_isHovered
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.22)
              : const Color(0xFF8B5CF6).withValues(alpha: 0.12));

    final themeBorder = widget.isSecondary
        ? (_isHovered
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08))
        : (_isHovered
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.45)
              : const Color(0xFF8B5CF6).withValues(alpha: 0.25));

    final textColor = widget.isSecondary
        ? (_isHovered ? Colors.white : Colors.white70)
        : const Color(0xFFC4B5FD);

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: themeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );

    return button;
  }
}

class _PaginationIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _PaginationIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<_PaginationIconButton> createState() => _PaginationIconButtonState();
}

class _PaginationIconButtonState extends State<_PaginationIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeBg = _isHovered
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.03);
    final themeBorder = _isHovered
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.08);
    final iconColor = _isHovered ? Colors.white : Colors.white70;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: themeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeBorder, width: 1),
      ),
      child: Icon(widget.icon, size: 14, color: iconColor),
    );

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
