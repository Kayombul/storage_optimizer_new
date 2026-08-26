import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/duration_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _alertDays = 14;
  bool _loading = true;
  bool _mediaWatch = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final watching = await StorageService.instance.isMediaWatchEnabled();
    if (mounted) {
      setState(() {
        _alertDays = prefs.getInt('alert_days') ?? 14;
        _mediaWatch = watching;
        _loading = false;
      });
    }
  }

  Future<void> _setMediaWatch(bool enabled) async {
    setState(() => _mediaWatch = enabled);
    await StorageService.instance.setMediaWatchEnabled(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('media_watch', enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? 'You will be alerted when new media is added'
              : 'New media alerts turned off'),
        ),
      );
    }
  }

  Future<void> _checkMediaNow() async {
    await StorageService.instance.checkMediaNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking for new media, an alert will '
              'appear if anything was added'),
        ),
      );
    }
  }

  Future<void> _saveAlertDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alert_days', days);
    setState(() => _alertDays = days);
  }

  Future<void> _clearScanData() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Scan Data?'),
        content:
            const Text('All scanned file records will be removed. '
                'Storage history will be kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await DatabaseService.instance.clearFileMetadata();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scan data cleared')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Storage History?'),
        content: const Text(
            'All storage snapshots will be removed. '
            'Forecasting will restart from scratch.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    final db = await DatabaseService.instance.database;
    await db.delete('storage_snapshots');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History cleared')),
      );
    }
  }

  Future<void> _testNotification() async {
    await NotificationService.instance.showStorageWarning(
      daysUntilFull: _alertDays,
      usedPercent: 78,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Alert threshold
                _sectionHeader(context, 'Notifications'),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Alert threshold',
                                style: textTheme.bodyLarge),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                dayCount(_alertDays),
                                style: textTheme.labelLarge?.copyWith(
                                    color: scheme.onPrimaryContainer),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Alert when storage is estimated to fill within '
                          '${dayCount(_alertDays)}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Slider(
                          value: _alertDays.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: dayCount(_alertDays),
                          onChanged: (v) => _saveAlertDays(v.round()),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 day',
                                style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                            Text('30 days',
                                style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary:
                            const Icon(Icons.perm_media_outlined),
                        title: const Text('New media alerts'),
                        subtitle: const Text(
                            'Watch for new photos, video and music in the '
                            'background and alert when they arrive'),
                        value: _mediaWatch,
                        onChanged: _setMediaWatch,
                      ),
                      if (_mediaWatch) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.search_outlined),
                          title: const Text('Check for new media now'),
                          subtitle: const Text(
                              'Run the watcher without waiting'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _checkMediaNow,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Test notification'),
                  subtitle: const Text('Send a sample alert now'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _testNotification,
                ),
                const SizedBox(height: 20),

                // Data management
                _sectionHeader(context, 'Data Management'),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.folder_delete_outlined),
                        title: const Text('Clear scan data'),
                        subtitle:
                            const Text('Remove all scanned file records'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _clearScanData,
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: Icon(Icons.history_outlined,
                            color: scheme.error),
                        title: Text('Clear storage history',
                            style: TextStyle(color: scheme.error)),
                        subtitle: const Text(
                            'Removes snapshots — resets forecasting'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _clearHistory,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // About
                _sectionHeader(context, 'About'),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI-Based Predictive Storage Optimizer',
                            style: textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0 · CS400 Final Year Project\n'
                          'The Copperbelt University\n'
                          'Lufunda Kayombu (21163392)',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 14, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'All data is processed locally. '
                                'Nothing leaves your device.',
                                style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary),
        ),
      );
}
