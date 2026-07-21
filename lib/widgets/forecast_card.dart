import 'package:flutter/material.dart';
import '../models/forecast_result.dart';

class ForecastCard extends StatelessWidget {
  final ForecastResult forecast;

  const ForecastCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color statusColor;
    IconData statusIcon;
    if (!forecast.hasEnoughData) {
      statusColor = scheme.onSurfaceVariant;
      statusIcon = Icons.hourglass_empty;
    } else if (forecast.isCritical) {
      statusColor = scheme.error;
      statusIcon = Icons.warning_amber_rounded;
    } else if (forecast.isWarning) {
      statusColor = Colors.orange;
      statusIcon = Icons.info_outline;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 0,
      color: statusColor.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Storage Forecast',
                  style: textTheme.titleSmall?.copyWith(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  forecast.daysLabel,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (forecast.hasEnoughData && forecast.daysUntilFull > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    'until full',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.trending_up,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Growth: ${forecast.growthLabel}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (forecast.hasEnoughData) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.analytics_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'MAE: ${(forecast.mae / (1024 * 1024)).toStringAsFixed(1)} MB  '
                      'RMSE: ${(forecast.rmse / (1024 * 1024)).toStringAsFixed(1)} MB  '
                      'R²: ${forecast.r2.toStringAsFixed(3)}',
                      style: textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
