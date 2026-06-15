import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/task_store.dart';
import '../theme/app_theme.dart';
import '../util/motivational_messages.dart';
import '../util/stats_data.dart';

class StatisticsScreen extends StatelessWidget {
  final TaskStore store;
  const StatisticsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final stats = StatsData.from(store.tasks, now);
          final bucket = bucketForOnTime(
            hasData: stats.hasOnTimeData,
            pct: stats.onTimePct,
          );
          final motivational = motivationalSession.lineFor(bucket);
          final byLabel = labelStatsFrom(store.tasks, now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _MotivationalBanner(message: motivational),
              const SizedBox(height: AppSpacing.lg),
              _MetricCardsRow(stats: stats),
              const SizedBox(height: AppSpacing.xl),
              _OutcomesRing(stats: stats),
              const SizedBox(height: AppSpacing.xl),
              _WeeklyBars(stats: stats),
              if (byLabel.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                _ByLabelCard(rows: byLabel),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Semantic outcome colors — green / amber / red that read in light & dark.
// Tier-A choice: Material green/amber/red 800 in light, 300 in dark, paired
// with the M3 error role for "missed" so deletes/errors share a vocabulary.
// ─────────────────────────────────────────────────────────────────────────────
class _OutcomePalette {
  final Color onTime;
  final Color late;
  final Color missed;
  final Color onTimeBg;
  final Color lateBg;
  final Color missedBg;
  const _OutcomePalette({
    required this.onTime,
    required this.late,
    required this.missed,
    required this.onTimeBg,
    required this.lateBg,
    required this.missedBg,
  });

  factory _OutcomePalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return _OutcomePalette(
      onTime: dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      late: dark ? const Color(0xFFFFB74D) : const Color(0xFFB26A00),
      missed: scheme.error,
      onTimeBg:
          dark ? const Color(0x3381C784) : const Color(0xFFE8F5E9),
      lateBg:
          dark ? const Color(0x33FFB74D) : const Color(0xFFFFF3E0),
      missedBg: scheme.errorContainer,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner
// ─────────────────────────────────────────────────────────────────────────────
class _MotivationalBanner extends StatelessWidget {
  final String message;
  const _MotivationalBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: scheme.onPrimaryContainer,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Three metric cards
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCardsRow extends StatelessWidget {
  final StatsData stats;
  const _MetricCardsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final pctLabel = stats.hasOnTimeData ? '${stats.onTimePct}%' : '—';
    return Row(
      children: [
        Expanded(
          child: _MetricCard(label: 'Active', value: '${stats.active}'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricCard(label: 'Completed', value: '${stats.completed}'),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MetricCard(label: 'On-time', value: pctLabel),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deadline-outcomes donut
// ─────────────────────────────────────────────────────────────────────────────
class _OutcomesRing extends StatelessWidget {
  final StatsData stats;
  const _OutcomesRing({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = _OutcomePalette.of(context);
    final total = stats.onTime + stats.late + stats.missed;
    final centerLabel = stats.hasOnTimeData ? '${stats.onTimePct}%' : '—';
    final centerSub = stats.hasOnTimeData ? 'on time' : 'no data';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deadline outcomes',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: stats.hasOnTimeData
                    ? 'On time ${stats.onTimePct}%. ${stats.onTime} on time, ${stats.late} late, ${stats.missed} missed.'
                    : 'No deadline tasks yet.',
                excludeSemantics: true,
                child: SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(132),
                      painter: _DonutPainter(
                        onTime: stats.onTime,
                        late: stats.late,
                        missed: stats.missed,
                        onTimeColor: palette.onTime,
                        lateColor: palette.late,
                        missedColor: palette.missed,
                        trackColor: scheme.outlineVariant,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          centerLabel,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          centerSub,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(
                      color: palette.onTime,
                      label: 'On time',
                      count: stats.onTime,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _LegendRow(
                      color: palette.late,
                      label: 'Late',
                      count: stats.late,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _LegendRow(
                      color: palette.missed,
                      label: 'Missed',
                      count: stats.missed,
                    ),
                    if (total == 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No deadline tasks yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          '$count',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int onTime;
  final int late;
  final int missed;
  final Color onTimeColor;
  final Color lateColor;
  final Color missedColor;
  final Color trackColor;

  _DonutPainter({
    required this.onTime,
    required this.late,
    required this.missed,
    required this.onTimeColor,
    required this.lateColor,
    required this.missedColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    final total = onTime + late + missed;
    if (total == 0) return;

    final segments = <(int, Color)>[
      (onTime, onTimeColor),
      (late, lateColor),
      (missed, missedColor),
    ];

    var startAngle = -math.pi / 2; // 12 o'clock
    const gap = 0.04; // small visual gap between segments
    final nonZero = segments.where((s) => s.$1 > 0).length;

    for (final (count, color) in segments) {
      if (count == 0) continue;
      final sweep = (count / total) * (2 * math.pi);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = nonZero == 1 ? StrokeCap.butt : StrokeCap.round
        ..color = color;
      final inset = nonZero > 1 ? gap : 0.0;
      canvas.drawArc(rect, startAngle + inset, sweep - inset * 2, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.onTime != onTime ||
      old.late != late ||
      old.missed != missed ||
      old.onTimeColor != onTimeColor ||
      old.lateColor != lateColor ||
      old.missedColor != missedColor ||
      old.trackColor != trackColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Weekly bars — Sunday → Saturday, today highlighted
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyBars extends StatelessWidget {
  final StatsData stats;
  const _WeeklyBars({required this.stats});

  static const _labels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxVal = stats.weeklyBars.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );
    final total =
        stats.weeklyBars.fold<int>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('This week', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                '$total completed',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.muted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            label: _weeklySemanticsLabel(stats),
            excludeSemantics: true,
            child: SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final value = stats.weeklyBars[i];
                final isToday = i == stats.todayIndex;
                final ratio = maxVal == 0 ? 0.0 : value / maxVal;
                final barHeight = 8 + ratio * 96; // min stub + scaled
                final barColor = isToday
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.22);
                final labelColor = isToday ? scheme.primary : scheme.muted;
                final labelWeight =
                    isToday ? FontWeight.w700 : FontWeight.w500;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        value == 0 ? '' : '$value',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isToday ? scheme.primary : scheme.muted,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _labels[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: labelColor,
                          fontWeight: labelWeight,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          )),
        ],
      ),
    );
  }
}

String _weeklySemanticsLabel(StatsData stats) {
  const names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday'];
  final parts = <String>[];
  for (var i = 0; i < 7; i++) {
    final v = stats.weeklyBars[i];
    if (v > 0) parts.add('${names[i]} $v');
  }
  if (parts.isEmpty) return 'No completions this week.';
  return 'This week: ${parts.join(', ')}.';
}

// ─────────────────────────────────────────────────────────────────────────────
// By label — per-label breakdown card (Phase 7d)
// ─────────────────────────────────────────────────────────────────────────────
class _ByLabelCard extends StatelessWidget {
  final List<LabelStat> rows;
  const _ByLabelCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By label', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _LabelStatRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _LabelStatRow extends StatelessWidget {
  final LabelStat row;
  const _LabelStatRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pct = row.hasOnTimeData ? '${row.onTimePct}% on-time' : '— on-time';
    final summary = '${row.active} active · ${row.completed} done · $pct';
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: row.isUnlabeled ? scheme.muted : scheme.onSurface,
      fontWeight: FontWeight.w600,
      fontStyle: row.isUnlabeled ? FontStyle.italic : FontStyle.normal,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          row.isUnlabeled ? Icons.label_off_outlined : Icons.label_outline,
          size: 16,
          color: scheme.muted,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: Text(
            row.label,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: Text(
            summary,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
          ),
        ),
      ],
    );
  }
}

