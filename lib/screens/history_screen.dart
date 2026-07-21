import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/storage_snapshot.dart';
import '../models/forecast_result.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<StorageSnapshot> _snapshots = [];
  ForecastResult _forecast = ForecastResult.noData();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final snaps = await DatabaseService.instance.getSnapshots(limit: 60);
    ForecastResult forecast = ForecastResult.noData();
    if (snaps.length >= 3) {
      forecast = await PredictionService.instance
          .forecast(snaps, snaps.last.totalBytes);
    }
    if (mounted) {
      setState(() {
        _snapshots = snaps;
        _forecast = forecast;
        _loading = false;
      });
    }
  }

  List<FlSpot> _buildSpots() {
    if (_snapshots.isEmpty) return [];
    final base = _snapshots.first.timestamp;
    return _snapshots.map((s) {
      final x = s.timestamp.difference(base).inHours / 24.0;
      final y = s.usedGB;
      return FlSpot(x, y);
    }).toList();
  }

  List<FlSpot> _buildForecastSpots(List<FlSpot> actual) {
    if (actual.length < 3 || _snapshots.isEmpty) return [];
    final forecast = _forecast;
    if (!forecast.hasEnoughData || forecast.daysUntilFull < 0) return [];

    final last = actual.last;
    final growthGB = forecast.dailyGrowthBytes / (1024 * 1024 * 1024);
    final totalGB = _snapshots.last.totalGB;

    // Project 30 more days or until full
    final projectDays = forecast.daysUntilFull.clamp(0, 30);
    return List.generate(projectDays + 1, (i) {
      return FlSpot(
        last.x + i,
        (last.y + i * growthGB).clamp(0, totalGB.toDouble()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_snapshots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'No history yet.\nOpen the dashboard to record storage snapshots.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final spots = _buildSpots();
    final forecastSpots = _buildForecastSpots(spots);
    final totalGB = _snapshots.last.totalGB;
    final latestUsed = _snapshots.last.usedGB;
    final base = _snapshots.first.timestamp;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Stats row
            Row(
              children: [
                _statCard(context, 'Current',
                    '${latestUsed.toStringAsFixed(1)} GB', scheme.primary),
                const SizedBox(width: 12),
                _statCard(context, 'Total',
                    '${totalGB.toStringAsFixed(0)} GB', scheme.secondary),
                const SizedBox(width: 12),
                _statCard(
                    context,
                    'Data points',
                    '${_snapshots.length}',
                    scheme.tertiary),
              ],
            ),
            const SizedBox(height: 20),

            // Chart
            Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text('Storage Usage (GB)',
                          style: textTheme.titleSmall),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: totalGB.toDouble() * 1.05,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: scheme.outlineVariant.withAlpha(80),
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (v, _) => Text(
                                  '${v.toInt()}G',
                                  style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: _snapshots.length > 14 ? 7 : 3,
                                getTitlesWidget: (v, _) {
                                  final date = base.add(
                                      Duration(hours: (v * 24).round()));
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      DateFormat('d/M').format(date),
                                      style: textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            // Actual data
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: scheme.primary,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: spots.length <= 20,
                                getDotPainter: (_, __, ___, ____) => // ignore: unnecessary_underscores
                                    FlDotCirclePainter(
                                  radius: 3,
                                  color: scheme.primary,
                                  strokeWidth: 0,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: scheme.primary.withAlpha(40),
                              ),
                            ),
                            // Forecast (dashed)
                            if (forecastSpots.isNotEmpty)
                              LineChartBarData(
                                spots: forecastSpots,
                                isCurved: true,
                                color: scheme.error.withAlpha(180),
                                barWidth: 1.5,
                                dashArray: [6, 4],
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: scheme.error.withAlpha(20),
                                ),
                              ),
                          ],
                          // Total capacity reference line
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: totalGB.toDouble(),
                                color: scheme.error.withAlpha(120),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  style: textTheme.labelSmall?.copyWith(
                                      color: scheme.error),
                                  labelResolver: (_) => 'Full',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendItem(context, scheme.primary, 'Actual'),
                        const SizedBox(width: 20),
                        if (forecastSpots.isNotEmpty)
                          _legendItem(context, scheme.error, 'Forecast',
                              dashed: true),
                        const SizedBox(width: 20),
                        _legendItem(context, scheme.error.withAlpha(120),
                            'Capacity',
                            dashed: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label,
      {bool dashed = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 2,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            border: dashed
                ? Border(bottom: BorderSide(color: color, width: 1.5))
                : null,
          ),
          child: dashed
              ? null
              : Container(color: color),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
