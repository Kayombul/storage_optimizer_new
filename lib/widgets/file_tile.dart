import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/file_metadata.dart';
import '../services/storage_service.dart';

class FileTile extends StatelessWidget {
  final FileMetadata file;
  final VoidCallback onDelete;
  final VoidCallback onKeep;

  const FileTile({
    super.key,
    required this.file,
    required this.onDelete,
    required this.onKeep,
  });

  IconData _typeIcon(String type) {
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

  Color _scoreColor(double score) {
    if (score < 0.33) return Colors.red;
    if (score < 0.66) return Colors.orange;
    return Colors.green;
  }

  String _daysAgo(DateTime dt) {
    final days = DateTime.now().difference(dt).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  /// Thumbnail for images, type icon otherwise. Decodes at thumbnail size so
  /// a long list of large photos does not blow up memory.
  Widget _leading(Color scoreColor) {
    if (file.fileType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(file.path),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          cacheWidth: 132,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _iconBox(scoreColor),
        ),
      );
    }
    return _iconBox(scoreColor);
  }

  Widget _iconBox(Color scoreColor) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scoreColor.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_typeIcon(file.fileType), color: scoreColor, size: 22),
      );

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Full-size image preview for pictures; a details sheet for everything
  /// else, so a file is never deleted sight-unseen.
  void _showPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isImage = file.fileType == 'image';

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(file.name,
                          style: textTheme.titleSmall, maxLines: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              if (isImage)
                Flexible(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.file(
                      File(file.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Preview unavailable — the file could not '
                            'be read.',
                            style: textTheme.bodySmall),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(context, 'Size',
                        StorageService.formatBytes(file.sizeBytes)),
                    _row(context, 'Type', file.fileType),
                    _row(context, 'Created', _fmtDate(file.createdAt)),
                    _row(context, 'Modified', _fmtDate(file.lastAccessedAt)),
                    _row(context, 'Value score',
                        file.valueScore.toStringAsFixed(4)),
                    if (file.scoreReason.isNotEmpty)
                      _row(context, 'Flagged because', file.scoreReason),
                    const SizedBox(height: 8),
                    Text(file.path,
                        style: textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => _openExternally(ctx),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hands the file to whichever installed app claims its MIME type, so
  /// audio, archives and documents can be checked before deletion rather
  /// than judged from metadata alone.
  Future<void> _openExternally(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await OpenFilex.open(file.path);
    if (result.type == ResultType.done) return;
    messenger.showSnackBar(
      SnackBar(content: Text(_openFailureMessage(result))),
    );
  }

  String _openFailureMessage(OpenResult r) {
    switch (r.type) {
      case ResultType.noAppToOpen:
        return 'No installed app can open ${file.fileType} files like this.';
      case ResultType.permissionDenied:
        return 'Permission denied opening ${file.name}.';
      case ResultType.fileNotFound:
        return '${file.name} no longer exists.';
      default:
        return 'Could not open ${file.name}: ${r.message}';
    }
  }

  Widget _row(BuildContext context, String label, String value) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label,
                style:
                    t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: t.bodySmall)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scoreColor = _scoreColor(file.valueScore);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: scheme.surfaceContainerLowest,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _leading(scoreColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${StorageService.formatBytes(file.sizeBytes)} · '
                        '${file.fileType} · '
                        'Accessed ${_daysAgo(file.lastAccessedAt)}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Value score bar
            Row(
              children: [
                Text(
                  'Value',
                  style: textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: file.valueScore,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  file.valueScore.toStringAsFixed(2),
                  style: textTheme.labelSmall?.copyWith(
                      color: scoreColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (file.scoreReason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Why: ${file.scoreReason}',
                style: textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showPreview(context),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Preview'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onKeep,
                  icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                  label: const Text('Keep'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
