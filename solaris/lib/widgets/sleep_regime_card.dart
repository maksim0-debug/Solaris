import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:solaris/models/sleep_regime.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/models/night_group.dart';
import 'package:solaris/widgets/glass_card.dart';
import 'package:solaris/l10n/app_localizations.dart';

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

class _SessionDetailRow extends StatelessWidget {
  final NightGroup night;

  const _SessionDetailRow({required this.night});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = night.aggregatedSession;

    // Calculate total duration as sum of all sessions (excluding gaps)
    final totalDuration = night.allSessions.fold<Duration>(
      Duration.zero,
      (prev, s) => prev + s.duration,
    );

    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8),
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
                            start: session.startTime,
                            end: session.endTime,
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
                      '${DateFormat('HH:mm').format(session.startTime)} — ${DateFormat('HH:mm').format(session.endTime)}',
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
    );
  }
}

class _SessionChip extends StatelessWidget {
  final SleepSession session;

  const _SessionChip({required this.session});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Text(
        '${timeFormat.format(session.startTime)}–${timeFormat.format(session.endTime)}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
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
