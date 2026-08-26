import 'dart:io';

import 'package:flutter/material.dart';
import '../models/file_metadata.dart';
import '../services/storage_service.dart';

class FileTile extends StatelessWidget {
  final FileMetadata file;
  final VoidCallback onDelete;
  final VoidCallback onKeep;

  /// Opens the full-screen preview of this file. Null hides the affordance.
  final VoidCallback? onPreview;

  const FileTile({
    super.key,
    required this.file,
    required this.onDelete,
    required this.onKeep,
    this.onPreview,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final scoreColor = _scoreColor(file.valueScore);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
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
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${StorageService.formatBytes(file.sizeBytes)} · '
                          '${file.fileType} · '
                          'Accessed ${_daysAgo(file.lastAccessedAt)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
              if (file.scoreReason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Why: ${file.scoreReason}',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onPreview != null) ...[
                    TextButton.icon(
                      onPressed: onPreview,
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Preview'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: onKeep,
                    icon: const Icon(Icons.thumb_up_alt_outlined, size: 16),
                    label: const Text('Keep'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Image files get a real thumbnail so the recommendation can be judged at
  /// a glance; every other type keeps the value-coloured type icon, as does
  /// an image that can no longer be read from disk.
  Widget _leading(Color scoreColor) {
    const size = 38.0;

    if (file.fileType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(file.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 96,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _iconBox(scoreColor, size),
        ),
      );
    }
    return _iconBox(scoreColor, size);
  }

  Widget _iconBox(Color scoreColor, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scoreColor.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_typeIcon(file.fileType), color: scoreColor, size: 22),
    );
  }
}
