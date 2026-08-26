import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/file_metadata.dart';
import '../services/storage_service.dart';

/// Full-screen, swipeable preview of the files recommended for deletion.
///
/// Every type the scanner recognises gets a real preview: images are decoded
/// from disk, videos show a frame, tracks show their embedded artwork, PDFs
/// show their first page, and text-like documents show their opening lines.
/// Each page carries the metadata that drove the recommendation, plus whatever
/// the platform knows about the file (duration, artist, resolution, pages), so
/// the user can judge it before acting.
class FilePreviewScreen extends StatefulWidget {
  final List<FileMetadata> files;
  final int initialIndex;

  /// Returns true when the file was actually removed from disk.
  final Future<bool> Function(FileMetadata file) onDelete;
  final void Function(FileMetadata file) onKeep;

  const FilePreviewScreen({
    super.key,
    required this.files,
    required this.onDelete,
    required this.onKeep,
    this.initialIndex = 0,
  });

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  late final PageController _controller;
  late List<FileMetadata> _files;
  late int _index;

  @override
  void initState() {
    super.initState();
    _files = List.of(widget.files);
    _index = _files.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, _files.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Drops the current page and keeps the viewer on a sensible neighbour,
  /// closing the screen once nothing is left to review.
  void _removeCurrent() {
    setState(() {
      _files.removeAt(_index);
      if (_index >= _files.length) _index = _files.length - 1;
    });
    if (_files.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    _controller.jumpToPage(_index);
  }

  Future<void> _delete() async {
    final file = _files[_index];
    final deleted = await widget.onDelete(file);
    if (deleted && mounted) _removeCurrent();
  }

  void _keep() {
    widget.onKeep(_files[_index]);
    _removeCurrent();
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final file = _files[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1} / ${_files.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _files.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _PreviewBody(file: _files[i]),
            ),
          ),
          _FileDetails(file: file),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _keep,
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                      label: const Text('Keep'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData previewIconFor(String type) {
  switch (type) {
    case 'image':
      return Icons.image_outlined;
    case 'video':
      return Icons.videocam_outlined;
    case 'audio':
      return Icons.music_note_outlined;
    case 'document':
      return Icons.description_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// The visual half of a preview page: the content of the file when it can be
/// rendered, a typed placeholder when it cannot.
class _PreviewBody extends StatelessWidget {
  final FileMetadata file;

  const _PreviewBody({required this.file});

  @override
  Widget build(BuildContext context) {
    switch (file.fileType) {
      case 'image':
        return _ImagePreview(file: file);
      case 'video':
        return _NativePreview(
          file: file,
          emptyIcon: Icons.videocam_outlined,
          emptyMessage: 'No frame could be read from this video.',
        );
      case 'audio':
        return _NativePreview(
          file: file,
          emptyIcon: Icons.music_note_outlined,
          emptyMessage: 'This track has no embedded artwork.',
        );
      case 'document':
        // A PDF can be rendered a page at a time by the platform; plain text is
        // read directly. Office formats have neither path and fall back to the
        // placeholder inside _TextPreview.
        if (file.path.split('.').last.toLowerCase() == 'pdf') {
          return _NativePreview(
            file: file,
            emptyIcon: Icons.picture_as_pdf_outlined,
            emptyMessage: 'This PDF could not be rendered.',
          );
        }
        return _TextPreview(file: file);
      default:
        return const _Placeholder(
          icon: Icons.insert_drive_file_outlined,
          message: 'No preview available for this file type.',
        );
    }
  }
}

/// Shows a preview the platform renders for us — a video frame, embedded album
/// art, or the first page of a PDF — delivered as PNG bytes over the method
/// channel.
class _NativePreview extends StatefulWidget {
  final FileMetadata file;
  final IconData emptyIcon;
  final String emptyMessage;

  const _NativePreview({
    required this.file,
    required this.emptyIcon,
    required this.emptyMessage,
  });

  @override
  State<_NativePreview> createState() => _NativePreviewState();
}

class _NativePreviewState extends State<_NativePreview> {
  late final Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    // Started once and held, so a rebuild from a swipe or a rotation does not
    // decode the same frame again.
    _thumbnail = StorageService.instance.getThumbnail(widget.file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: FutureBuilder<Uint8List?>(
        future: _thumbnail,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return _Placeholder(
              icon: widget.emptyIcon,
              message: widget.emptyMessage,
              onDark: true,
            );
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _Placeholder(
                  icon: widget.emptyIcon,
                  message: widget.emptyMessage,
                  onDark: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final FileMetadata file;

  const _ImagePreview({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      width: double.infinity,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Image.file(
          File(file.path),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _Placeholder(
            icon: Icons.broken_image_outlined,
            message: 'This image could not be opened.',
            onDark: true,
          ),
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  final FileMetadata file;

  const _TextPreview({required this.file});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<String?>(
      future: StorageService.instance.readTextPreview(file.path),
      builder: (_, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snapshot.data;
        if (text == null || text.trim().isEmpty) {
          return _Placeholder(
            icon: previewIconFor(file.fileType),
            message:
                'This document cannot be shown as text.\n'
                'Check the details below before deleting.',
          );
        }
        return Container(
          width: double.infinity,
          color: scheme.surfaceContainerLowest,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool onDark;

  const _Placeholder({
    required this.icon,
    required this.message,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: color),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The metadata that explains why the file was recommended for deletion.
class _FileDetails extends StatelessWidget {
  final FileMetadata file;

  const _FileDetails({required this.file});

  Color _scoreColor(double score) {
    if (score < 0.33) return Colors.red;
    if (score < 0.66) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scoreColor = _scoreColor(file.valueScore);
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  StorageService.formatBytes(file.sizeBytes),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  file.fileType,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (file.isRecommendedForDeletion)
                  Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Recommended',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Value',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: file.valueScore,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  file.valueScore.toStringAsFixed(2),
                  style: textTheme.labelSmall?.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (file.scoreReason.isNotEmpty)
              _row(context, 'Why', file.scoreReason),
            _MediaInfoRows(file: file),
            _row(
              context,
              'Last accessed',
              dateFormat.format(file.lastAccessedAt),
            ),
            _row(context, 'Created', dateFormat.format(file.createdAt)),
            _row(context, 'Opened', '${file.accessCount} times'),
            _row(context, 'Path', file.path),
          ],
        ),
      ),
    );
  }

  static Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.labelSmall)),
        ],
      ),
    );
  }
}

/// Whatever the platform can tell us about the file itself — a track's artist
/// and length, a clip's resolution, a PDF's page count. Nothing is rendered
/// until the lookup returns, and a file with no readable metadata simply
/// contributes no rows.
class _MediaInfoRows extends StatefulWidget {
  final FileMetadata file;

  const _MediaInfoRows({required this.file});

  @override
  State<_MediaInfoRows> createState() => _MediaInfoRowsState();
}

class _MediaInfoRowsState extends State<_MediaInfoRows> {
  Map<String, String> _info = const {};

  static const _labels = {
    'title': 'Title',
    'artist': 'Artist',
    'album': 'Album',
    'duration': 'Length',
    'resolution': 'Resolution',
    'pages': 'Pages',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(_MediaInfoRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The details panel is reused as the user swipes between files.
    if (oldWidget.file.path != widget.file.path) {
      setState(() => _info = const {});
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final path = widget.file.path;
    final info = await StorageService.instance.getMediaInfo(path);
    // A slow lookup may land after the user has already swiped on.
    if (mounted && widget.file.path == path) {
      setState(() => _info = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_info.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in _labels.entries)
          if (_info[entry.key] != null)
            _FileDetails._row(context, entry.value, _info[entry.key]!),
      ],
    );
  }
}
