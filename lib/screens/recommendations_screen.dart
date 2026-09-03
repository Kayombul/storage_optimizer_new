import 'package:flutter/material.dart';
import '../models/file_metadata.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../widgets/file_tile.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<FileMetadata> _files = [];
  String _filter = 'all';
  bool _loading = true;
  bool _showAllFiles = false;

  static const _types = ['all', 'image', 'video', 'audio', 'document'];

  /// Index of this screen within the shell's tab bar.
  static const _tabIndex = 1;
  TabController? _tabs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell keeps this screen alive between tab switches, so initState
    // runs only once. Without this listener the list still shows whatever was
    // loaded the first time the tab was opened — after a scan it would look
    // as though navigating here did nothing.
    final controller = DefaultTabController.maybeOf(context);
    if (controller != _tabs) {
      _tabs?.removeListener(_onTabChanged);
      _tabs = controller;
      _tabs?.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    final c = _tabs;
    if (c == null || c.indexIsChanging) return;
    if (c.index == _tabIndex) _load();
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await DatabaseService.instance.getAllFiles();
    if (mounted) {
      setState(() {
        _files = all;
        _loading = false;
      });
    }
  }

  List<FileMetadata> get _filtered {
    var list = _showAllFiles
        ? _files
        : _files.where((f) => f.isRecommendedForDeletion).toList();
    if (_filter != 'all') {
      list = list.where((f) => f.fileType == _filter).toList();
    }
    return list;
  }

  int get _totalSizeFiltered {
    return _filtered.fold(0, (sum, f) => sum + f.sizeBytes);
  }

  Future<void> _deleteFile(FileMetadata file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(
            'Delete "${file.name}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    final deleted = await StorageService.instance.deleteFile(file.path);
    if (deleted) {
      if (file.id != null) {
        await DatabaseService.instance.deleteFileById(file.id!);
      }
      if (mounted) {
        setState(() => _files.removeWhere((f) => f.path == file.path));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${file.name}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete ${file.name}')),
        );
      }
    }
  }

  void _keepFile(FileMetadata file) {
    setState(() => _files.removeWhere((f) => f.path == file.path));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${file.name} will be kept'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => setState(() => _files.add(file)),
        ),
      ),
    );
  }

  Future<void> _deleteAll() async {
    final files = _filtered;
    if (files.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Shown?'),
        content: Text(
            'Delete ${files.length} files?\n'
            'This frees ${StorageService.formatBytes(_totalSizeFiltered)}.\n\n'
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete All')),
        ],
      ),
    );
    if (confirm != true) return;

    int deleted = 0;
    for (final f in files) {
      final ok = await StorageService.instance.deleteFile(f.path);
      if (ok) {
        if (f.id != null) await DatabaseService.instance.deleteFileById(f.id!);
        deleted++;
      }
    }
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deleted files')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shown = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          if (shown.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete all shown',
              onPressed: _deleteAll,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Toggle recommended / all
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                                value: false,
                                label: Text('For Deletion'),
                                icon: Icon(Icons.delete_outline)),
                            ButtonSegment(
                                value: true,
                                label: Text('All Files'),
                                icon: Icon(Icons.folder_outlined)),
                          ],
                          selected: {_showAllFiles},
                          onSelectionChanged: (s) =>
                              setState(() => _showAllFiles = s.first),
                        ),
                      ),
                    ],
                  ),
                ),

                // Type filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _types.map((t) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(t == 'all'
                              ? 'All'
                              : t[0].toUpperCase() + t.substring(1)),
                          selected: _filter == t,
                          onSelected: (_) => setState(() => _filter = t),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Summary bar
                if (shown.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '${shown.length} files · '
                          '${StorageService.formatBytes(_totalSizeFiltered)} could be freed',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                // List
                Expanded(
                  child: shown.isEmpty
                      ? _empty(context)
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          itemCount: shown.length,
                          itemBuilder: (_, i) => FileTile(
                            file: shown[i],
                            onDelete: () => _deleteFile(shown[i]),
                            onKeep: () => _keepFile(shown[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            _files.isEmpty
                ? 'No files scanned yet.\nTap "Scan Files" on the dashboard.'
                : 'No files match the current filter.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
