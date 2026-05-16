import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/weight_service.dart';

/// Real-time fl_chart line widget for the user's recent weight history.
///
/// Reads the latest 12 entries from `WeightService.weightHistoryStream`.
/// If the user has 0 or 1 entry the chart is replaced with a guidance
/// message — a single point would compress the y-axis and look broken.
///
/// `targetWeightKg` (optional) draws a horizontal dashed reference line
/// so the user can see how close they are to their stated goal.
class WeightTrendChart extends StatelessWidget {
  final String uid;
  final double? targetWeightKg;

  const WeightTrendChart({
    super.key,
    required this.uid,
    this.targetWeightKg,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WeightEntry>>(
      stream: WeightService().weightHistoryStream(uid),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <WeightEntry>[];
        if (entries.length < 2) {
          return _EmptyState(hasOne: entries.length == 1);
        }
        return SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: LineChart(_buildChartData(entries)),
          ),
        );
      },
    );
  }

  LineChartData _buildChartData(List<WeightEntry> entries) {
    final spots = <FlSpot>[
      for (int i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].weightKg),
    ];
    final ys = entries.map((e) => e.weightKg).toList();
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.2).clamp(0.5, 3.0);

    return LineChartData(
      minY: minY - pad,
      maxY: maxY + pad,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touched) => touched.map((spot) {
            final entry = entries[spot.x.toInt()];
            return LineTooltipItem(
              '${entry.weightKg.toStringAsFixed(1)} kg\n'
              '${DateFormat('d MMM').format(DateTime.parse(entry.date))}',
              const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.border,
          strokeWidth: 0.6,
          dashArray: const [3, 3],
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, _) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: (entries.length / 4).clamp(1, 12).toDouble(),
            getTitlesWidget: (value, _) {
              final idx = value.toInt();
              if (idx < 0 || idx >= entries.length) {
                return const SizedBox.shrink();
              }
              final date = DateTime.parse(entries[idx].date);
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('d/M').format(date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      extraLinesData: targetWeightKg == null
          ? const ExtraLinesData()
          : ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: targetWeightKg!,
                  color: AppColors.primary.withValues(alpha: 0.5),
                  strokeWidth: 1.4,
                  dashArray: const [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    labelResolver: (_) =>
                        'Goal ${targetWeightKg!.toStringAsFixed(1)} kg',
                  ),
                ),
              ],
            ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: AppColors.primary,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 3.5,
              color: AppColors.primary,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasOne;
  const _EmptyState({required this.hasOne});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          hasOne
              ? 'Log one more weigh-in to see your trend chart.'
              : 'Log your weight weekly to track your progress.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
