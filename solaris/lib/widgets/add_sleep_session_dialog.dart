import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/models/sleep_session.dart';
import 'package:solaris/providers/sleep_provider.dart';

import 'package:solaris/providers.dart';

class AddSleepSessionDialog extends ConsumerStatefulWidget {
  const AddSleepSessionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const AddSleepSessionDialog(),
    );
  }

  @override
  ConsumerState<AddSleepSessionDialog> createState() =>
      _AddSleepSessionDialogState();
}

class _AddSleepSessionDialogState
    extends ConsumerState<AddSleepSessionDialog> {
  late DateTime _startTime;
  late DateTime _endTime;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = ref.read(currentTimeProvider).value ?? DateTime.now();
    // Default start time: Yesterday at 23:00
    final yesterday = now.subtract(const Duration(days: 1));
    _startTime = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      23,
      0,
    );
    // Default end time: Today at 07:00
    _endTime = DateTime(now.year, now.month, now.day, 7, 0);

    if (_endTime.isBefore(_startTime) ||
        _endTime.isAtSameMomentAs(_startTime)) {
      _endTime = _startTime.add(const Duration(hours: 8));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _applyDurationPreset(int hours) {
    setState(() {
      _endTime = _startTime.add(Duration(hours: hours));
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startTime : _endTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              surface: Color(0xFF1E1B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final initialTime = TimeOfDay.fromDateTime(initialDate);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              surface: Color(0xFF1E1B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      final newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      if (isStart) {
        _startTime = newDateTime;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 8));
        }
      } else {
        _endTime = newDateTime;
      }
    });
  }

  void _saveSession(AppLocalizations l10n) {
    if (_endTime.isBefore(_startTime) || _endTime.isAtSameMomentAs(_startTime)) {
      return;
    }

    final rawTitle = _titleController.text.trim();
    final rawDesc = _descController.text.trim();

    final title = rawTitle.isNotEmpty ? rawTitle : l10n.manualSleepTitleDefault;
    final description =
        rawDesc.isNotEmpty ? rawDesc : l10n.manualSleepDescDefault;

    final session = SleepSession(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      startTime: _startTime.toUtc(),
      endTime: _endTime.toUtc(),
      title: title,
      description: description,
      segments: const [],
      source: 'manual',
    );

    ref.read(sleepProvider.notifier).addManualSession(session);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final duration = _endTime.difference(_startTime);
    final isValidRange = _endTime.isAfter(_startTime);

    final String durationString;
    if (isValidRange) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      durationString = '${hours}${l10n.hoursAbbreviation} ${minutes}${l10n.minutesAbbreviation}';
    } else {
      durationString = l10n.invalidTimeRangeError;
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1B2E),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.moon,
              color: Color(0xFFC4B5FD),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.addSleepSession,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start & End Time Pickers
            Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: l10n.startTime,
                    dateTime: _startTime,
                    locale: l10n.localeName,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeTile(
                    label: l10n.endTime,
                    dateTime: _endTime,
                    locale: l10n.localeName,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Duration Header & Presets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${l10n.duration}: ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      durationString,
                      style: TextStyle(
                        color: isValidRange
                            ? const Color(0xFFC4B5FD)
                            : const Color(0xFFF87171),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [7, 8, 9].map((h) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: InkWell(
                        onTap: () => _applyDurationPreset(h),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '+${h}${l10n.hoursAbbreviation}',
                            style: const TextStyle(
                              color: Color(0xFFC4B5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title Field
            Text(
              l10n.sessionTitleLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.sleepSessionTitleHint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Field
            Text(
              l10n.sessionDescLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.sleepSessionDescHint,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancelAction,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: isValidRange ? () => _saveSession(l10n) : null,
          child: Text(l10n.saveAction),
        ),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final DateTime dateTime;
  final String locale;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.dateTime,
    required this.locale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, HH:mm', locale);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateFormat.format(dateTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.calendar,
                  color: Colors.white.withOpacity(0.5),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
