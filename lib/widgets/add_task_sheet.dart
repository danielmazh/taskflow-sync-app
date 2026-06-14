import 'package:flutter/material.dart';

import '../models/task.dart';
import 'voice_capture_sheet.dart';

class AddTaskSheetResult {
  final String title;
  final String? note;
  final DateTime? dueAt;
  /// User asked to export this new task to Google Calendar. Only ever true
  /// from the add (not edit) flow and only when calendar export was offered
  /// (connected + authorized + a due time was selected). Home handles the
  /// actual export call once the task exists.
  final bool addToCalendar;
  const AddTaskSheetResult({
    required this.title,
    this.note,
    this.dueAt,
    this.addToCalendar = false,
  });
}

Future<AddTaskSheetResult?> showAddTaskSheet(
  BuildContext context, {
  Task? initial,
  bool calendarAvailable = false,
}) {
  return showModalBottomSheet<AddTaskSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: _AddTaskSheet(
          initial: initial,
          calendarAvailable: calendarAvailable,
        ),
      ),
    ),
  );
}

class _AddTaskSheet extends StatefulWidget {
  final Task? initial;
  final bool calendarAvailable;
  const _AddTaskSheet({this.initial, this.calendarAvailable = false});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final FocusNode _titleFocus;
  DateTime? _dueAt;
  bool _addToCalendar = false;
  bool get _isEdit => widget.initial != null;
  bool get _showCalendarCheckbox =>
      !_isEdit && widget.calendarAvailable && _dueAt != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initial?.title ?? '');
    _noteCtrl = TextEditingController(text: widget.initial?.note ?? '');
    _titleFocus = FocusNode();
    _dueAt = widget.initial?.dueAt;
    // Auto-focus on the title on new-task only — editing already has content.
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _dictateInto(
    TextEditingController controller,
    FocusNode? focus,
  ) async {
    final recognized = await showVoiceCaptureSheet(context);
    if (!mounted) return;
    final text = recognized?.trim();
    if (text == null || text.isEmpty) return;
    final current = controller.text;
    final next = current.isEmpty ? text : '$current $text';
    controller.text = next;
    controller.selection = TextSelection.collapsed(offset: next.length);
    focus?.requestFocus();
  }

  Future<void> _pickDueAt() async {
    final now = DateTime.now();
    final initialDate = _dueAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatDueAt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final note = _noteCtrl.text.trim();
    Navigator.of(context).pop(
      AddTaskSheetResult(
        title: title,
        note: note.isEmpty ? null : note,
        dueAt: _dueAt,
        addToCalendar: _showCalendarCheckbox && _addToCalendar,
      ),
    );
  }

  void _applyQuick(DateTime when) {
    setState(() => _dueAt = when);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit task' : 'New task',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Title',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_none_outlined),
                tooltip: 'Dictate title',
                onPressed: () => _dictateInto(_titleCtrl, _titleFocus),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.mic_none_outlined),
                tooltip: 'Dictate note',
                onPressed: () => _dictateInto(_noteCtrl, null),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DateRow(
            now: DateTime.now(),
            selected: _dueAt,
            onPick: _applyQuick,
            onCustom: _pickDueAt,
          ),
          if (_dueAt != null) ...[
            const SizedBox(height: 10),
            Semantics(
              label: 'Selected due date',
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 18, color: scheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatDueAt(_dueAt!),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear due date',
                      iconSize: 20,
                      onPressed: () => setState(() => _dueAt = null),
                      icon: Icon(
                        Icons.close,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_showCalendarCheckbox) ...[
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _addToCalendar,
              onChanged: (v) => setState(() => _addToCalendar = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Add to Google Calendar'),
              secondary: const Icon(Icons.event_available_outlined),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                child: Text(_isEdit ? 'Save' : 'Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-date chips
// ─────────────────────────────────────────────────────────────────────────────

/// Date row: a fixed "Pick date & time" button on the left (primary, always
/// visible — the mandatory way to set any date), and a horizontally-scrollable
/// set of convenience shortcuts on the right (Today / This evening / …).
class _DateRow extends StatelessWidget {
  final DateTime now;
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onCustom;
  const _DateRow({
    required this.now,
    required this.selected,
    required this.onPick,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = quickDateOptions(now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: 'Pick date & time',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: onCustom,
          color: scheme.onSecondaryContainer,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  ChoiceChip(
                    label: Text(options[i].label),
                    avatar: Icon(options[i].icon, size: 18),
                    selected:
                        selected != null && selected == options[i].when,
                    onSelected: (_) => onPick(options[i].when),
                    tooltip: options[i].tooltip,
                  ),
                  if (i != options.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One quick-date suggestion presented as a chip.
class QuickDateOption {
  final String label;
  final IconData icon;
  final DateTime when;
  final String tooltip;
  const QuickDateOption({
    required this.label,
    required this.icon,
    required this.when,
    required this.tooltip,
  });
}

/// Compute the chip set for [now]. Pure — also used by tests.
///
/// Rules:
///   - "Today": today at 17:00. If now ≥ 17:00, instead "in 1h" rounded up
///             to the next half-hour, clamped to today's 23:30.
///   - "This evening": today at 18:00. If now ≥ 18:00, rolls to tomorrow 18:00.
///   - "Tomorrow": tomorrow at 09:00.
///   - "Next week": now + 7 days at 09:00.
List<QuickDateOption> quickDateOptions(DateTime now) {
  // "Today" — late-in-day fallback to "+1h" rounded to next :30.
  DateTime todayWhen;
  if (now.hour < 17) {
    todayWhen = DateTime(now.year, now.month, now.day, 17, 0);
  } else {
    final inOneHour = now.add(const Duration(hours: 1));
    final m = inOneHour.minute <= 30 ? 30 : 60;
    var rounded = DateTime(
      inOneHour.year,
      inOneHour.month,
      inOneHour.day,
      inOneHour.hour,
      0,
    ).add(Duration(minutes: m));
    // Clamp to today 23:30.
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 30);
    if (rounded.isAfter(endOfToday)) rounded = endOfToday;
    todayWhen = rounded;
  }

  // "This evening" — today 18:00, or tomorrow 18:00 if past.
  DateTime evening = DateTime(now.year, now.month, now.day, 18, 0);
  if (!evening.isAfter(now)) {
    evening = evening.add(const Duration(days: 1));
  }

  final tomorrow = DateTime(now.year, now.month, now.day, 9, 0)
      .add(const Duration(days: 1));
  final nextWeek = DateTime(now.year, now.month, now.day, 9, 0)
      .add(const Duration(days: 7));

  return [
    QuickDateOption(
      label: 'Today',
      icon: Icons.today_outlined,
      when: todayWhen,
      tooltip: 'Due today',
    ),
    QuickDateOption(
      label: 'This evening',
      icon: Icons.wb_twilight_outlined,
      when: evening,
      tooltip: 'Due around 18:00',
    ),
    QuickDateOption(
      label: 'Tomorrow',
      icon: Icons.wb_sunny_outlined,
      when: tomorrow,
      tooltip: 'Due tomorrow at 09:00',
    ),
    QuickDateOption(
      label: 'Next week',
      icon: Icons.next_week_outlined,
      when: nextWeek,
      tooltip: 'Due one week from now',
    ),
  ];
}
