import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class StorageGauge extends StatelessWidget {
  final int usedBytes;
  final int totalBytes;
  final double size;

  const StorageGauge({
    super.key,
    required this.usedBytes,
    required this.totalBytes,
    this.size = 160,
  });

  double get _percent =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  Color _gaugeColor(BuildContext context) {
    if (_percent >= 0.90) return Theme.of(context).colorScheme.error;
    if (_percent >= 0.70) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final pct = _percent;
    final color = _gaugeColor(context);
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 14,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'Used',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StorageBreakdownRow extends StatelessWidget {
  final int usedBytes;
  final int freeBytes;
  final int totalBytes;

  const StorageBreakdownRow({
    super.key,
    required this.usedBytes,
    required this.freeBytes,
    required this.totalBytes,
  });

  Widget _chip(BuildContext context, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 'Used', StorageService.formatBytes(usedBytes),
            Colors.orange),
        const SizedBox(width: 8),
        _chip(context, 'Free', StorageService.formatBytes(freeBytes),
            Colors.green),
        const SizedBox(width: 8),
        _chip(context, 'Total', StorageService.formatBytes(totalBytes),
            Theme.of(context).colorScheme.primary),
      ],
    );
  }
}
