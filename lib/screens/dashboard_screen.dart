import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/storage_snapshot.dart';
import '../models/forecast_result.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/prediction_service.dart';
import '../services/value_scoring_service.dart';
import '../services/optimization_service.dart';
import '../services/notification_service.dart';
import '../widgets/storage_gauge.dart';
import '../widgets/forecast_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StorageSnapshot? _latest;
  ForecastResult _forecast = ForecastResult.noData();
  bool _loading = false;
  bool _scanning = false;
  int _scanProgress = 0;
  int _fileCount = 0;
  int _recommendedCount = 0;
  DateTime? _lastScan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _refreshStorage();
      await _refreshStats();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshStorage() async {
    final snapshot = await StorageService.instance.getStorageInfo();
    await DatabaseService.instance.insertSnapshot(snapshot);
    await DatabaseService.instance.pruneOldSnapshots();

    final snapshots = await DatabaseService.instance.getSnapshots();
    final forecast = await PredictionService.instance
        .forecast(snapshots, snapshot.totalBytes);

    if (mounted) {
      setState(() {
        _latest = snapshot;
        _forecast = forecast;
      });
    }

    // Show notification if forecast is critical
    final prefs = await SharedPreferences.getInstance();
    final threshold = prefs.getInt('alert_days') ?? 14;
    if (forecast.hasEnoughData &&
        forecast.daysUntilFull >= 0 &&
        forecast.daysUntilFull <= threshold) {
      await NotificationService.instance.showStorageWarning(
        daysUntilFull: forecast.daysUntilFull,
        usedPercent: snapshot.usedPercent,
      );
    }
  }

  Future<void> _refreshStats() async {
    final count = await DatabaseService.instance.getFileCount();
    final rec = await DatabaseService.instance.getRecommendedCount();
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('last_scan');
    if (mounted) {
      setState(() {
        _fileCount = count;
        _recommendedCount = rec;
        _lastScan =
            lastMs != null ? DateTime.fromMillisecondsSinceEpoch(lastMs) : null;
      });
    }
  }

  Future<void> _startScan() async {
    final granted = await StorageService.instance.hasPermission();
    if (!granted) {
      final ok = await StorageService.instance.requestPermissions();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Storage permission is required to scan files.')),
          );
        }
        return;
      }
    }

    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });

    try {
      final rawFiles = await StorageService.instance.scanFiles(
        onProgress: (n) {
          if (mounted) setState(() => _scanProgress = n);
        },
      );

      final scored = await ValueScoringService.instance.scoreAll(rawFiles);

      // Build deletion plan
      if (_latest != null) {
        OptimizationService.instance.generatePlan(
          files: scored,
          forecast: _forecast,
          freeBytes: _latest!.freeBytes,
          totalBytes: _latest!.totalBytes,
        );
      }

      await DatabaseService.instance.clearFileMetadata();
      await DatabaseService.instance.upsertAllFiles(scored);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          'last_scan', DateTime.now().millisecondsSinceEpoch);

      final recommended = scored.where((f) => f.isRecommendedForDeletion).length;
      await NotificationService.instance.showScanComplete(
        filesFound: scored.length,
        recommended: recommended,
      );

      await _refreshStats();
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _formatLastScan(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Optimizer'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Storage gauge
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: Column(
                        children: [
                          Text('Device Storage',
                              style: textTheme.titleMedium),
                          const SizedBox(height: 20),
                          StorageGauge(
                            usedBytes: _latest?.usedBytes ?? 0,
                            totalBytes: _latest?.totalBytes ?? 1,
                          ),
                          const SizedBox(height: 20),
                          StorageBreakdownRow(
                            usedBytes: _latest?.usedBytes ?? 0,
                            freeBytes: _latest?.freeBytes ?? 0,
                            totalBytes: _latest?.totalBytes ?? 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Forecast card
                  ForecastCard(forecast: _forecast),
                  const SizedBox(height: 16),

                  // Scan stats card
                  Card(
                    elevation: 0,
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Last Scan',
                                  style: textTheme.titleSmall),
                              Text(
                                _formatLastScan(_lastScan),
                                style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              _statBadge(
                                context,
                                '$_fileCount',
                                'Files scanned',
                                Icons.folder_outlined,
                                scheme.primary,
                              ),
                              const SizedBox(width: 12),
                              _statBadge(
                                context,
                                '$_recommendedCount',
                                'For deletion',
                                Icons.delete_outline,
                                scheme.error,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scan button
                  if (_scanning) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Scanning… $_scanProgress files found',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton.icon(
                    onPressed: _scanning ? null : _startScan,
                    icon: const Icon(Icons.search),
                    label: Text(
                        _scanning ? 'Scanning…' : 'Scan Files'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_fileCount > 0)
                    OutlinedButton.icon(
                      onPressed: () =>
                          DefaultTabController.of(context).animateTo(1),
                      icon: const Icon(Icons.list_alt),
                      label: Text(
                          'View $_recommendedCount Recommendations'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _statBadge(BuildContext context, String value, String label,
      IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
