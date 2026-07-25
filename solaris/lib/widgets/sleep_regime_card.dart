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
                        start: widget.regime.startDate,
                        end: widget.regime.nights.isEmpty
                            ? widget.regime.endDate
                            : widget.regime.nights.first.aggregatedSession.endTime,
                        locale: l10n.localeName,
                        includeYear: false,
                      ),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
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
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
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
                    color: Colors.white.withOpacity(0.3),
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
          ...widget.regime.nights.map(
            (night) => _SessionDetailRow(night: night),
          ),
        ],
      ],
    );
  }
}

class _SessionDetailRow extends ConsumerWidget {
  final NightGroup night;

  const _SessionDetailRow({required this.night});

  void _onDeleteRow(BuildContext context, WidgetRef ref) {
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

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
      child: GestureDetector(
        onLongPress: () => _onDeleteRow(context, ref),
        behavior: HitTestBehavior.opaque,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          if (night.isOutdated) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('HH:mm').format(session.startTime.toLocal())} — ${DateFormat('HH:mm').format(session.endTime.toLocal())}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
    );
  }
}

class _SessionChip extends ConsumerWidget {
  final SleepSession session;

  const _SessionChip({required this.session});

  void _onDeleteChip(BuildContext context, WidgetRef ref) {
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
    final timeFormat = DateFormat('HH:mm');
    return GestureDetector(
      onTap: () => _onDeleteChip(context, ref),
      onLongPress: () => _onDeleteChip(context, ref),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: Text(
            '${timeFormat.format(session.startTime.toLocal())}–${timeFormat.format(session.endTime.toLocal())}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
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
            backgroundColor: const Color(0xFF1E1B2E),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.white.withOpacity(0.15),
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
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => doNotSync = !doNotSync),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                              color: Colors.white.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.doNotSyncInFuture,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
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
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                  ),
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
                  ref.read(sleepProvider.notifier).deleteSessions(
                        sessionIdsToDelete,
                        doNotSync: doNotSync,
                      );
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
    return DateFormat(includeYear ? 'd MMM, yyyy' : 'd MMM', locale).format(start);
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
