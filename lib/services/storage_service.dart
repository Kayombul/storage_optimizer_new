import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/file_metadata.dart';
import '../models/storage_snapshot.dart';

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  static const _channel =
      MethodChannel('com.example.storage_optimizer/storage');

  static const _root = '/storage/emulated/0';

  /// Standard Android media directories. Names must match
  /// `android.os.Environment.DIRECTORY_*` exactly — note `Download`
  /// is singular.
  static const _scanDirs = [
    '$_root/DCIM',
    '$_root/Pictures',
    '$_root/Download',
    '$_root/Movies',
    '$_root/Music',
    '$_root/Documents',
    '$_root/Podcasts',
    '$_root/Audiobooks',
    '$_root/Recordings',
    // WhatsApp pre-Android 11 and Android 11+ scoped-storage locations.
    '$_root/WhatsApp/Media',
    '$_root/Android/media/com.whatsapp/WhatsApp/Media',
    '$_root/Telegram',
  ];

  /// Excluded from the whole-volume fallback sweep: app sandboxes are
  /// unreadable without special access and hold no user-deletable media.
  static const _fallbackSkip = [
    '$_root/Android/data',
    '$_root/Android/obb',
  ];

  /// Guards against pathological or symlink-looping directory trees.
  static const _maxDepth = 12;

  Future<StorageSnapshot> getStorageInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getStorageInfo');
      if (result != null) {
        return StorageSnapshot(
          timestamp: DateTime.now(),
          totalBytes: (result['totalBytes'] as num).toInt(),
          usedBytes: (result['usedBytes'] as num).toInt(),
          freeBytes: (result['freeBytes'] as num).toInt(),
        );
      }
    } catch (_) {}
    // Fallback for emulator / permission denied
    return StorageSnapshot(
      timestamp: DateTime.now(),
      totalBytes: 64 * 1024 * 1024 * 1024,
      usedBytes: 45 * 1024 * 1024 * 1024,
      freeBytes: 19 * 1024 * 1024 * 1024,
    );
  }

  Future<int> _getSdkInt() async {
    try {
      return await _channel.invokeMethod<int>('getSdkInt') ?? 30;
    } catch (_) {
      return 30;
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _getSdkInt();
    if (sdk >= 33) {
      final r1 = await Permission.photos.request();
      final r2 = await Permission.videos.request();
      final r3 = await Permission.audio.request();
      return r1.isGranted || r2.isGranted || r3.isGranted;
    } else if (sdk >= 30) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;
      // Fall back to regular storage
      return (await Permission.storage.request()).isGranted;
    } else {
      return (await Permission.storage.request()).isGranted;
    }
  }

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await _getSdkInt();
    if (sdk >= 33) {
      return await Permission.photos.isGranted ||
          await Permission.videos.isGranted ||
          await Permission.audio.isGranted;
    } else if (sdk >= 30) {
      return await Permission.manageExternalStorage.isGranted ||
          await Permission.storage.isGranted;
    } else {
      return await Permission.storage.isGranted;
    }
  }

  Future<List<FileMetadata>> scanFiles({
    void Function(int scanned)? onProgress,
  }) async {
    final files = <FileMetadata>[];
    final seen = <String>{};

    for (final dirPath in _scanDirs) {
      await _collect(Directory(dirPath), files, seen, onProgress);
    }

    // Fallback: if none of the standard directories yielded anything (unusual
    // vendor layout, media kept at the volume root), sweep the whole volume so
    // a scan never comes back empty on a device that does have files.
    if (files.isEmpty) {
      await _collect(Directory(_root), files, seen, onProgress,
          skip: _fallbackSkip);
    }

    onProgress?.call(files.length);
    return files;
  }

  /// Walks [dir] one level at a time, recursing manually.
  ///
  /// `Directory.list(recursive: true)` aborts its whole stream on the first
  /// unreadable entry, which would silently truncate a scan at the first
  /// locked folder. Recursing per directory confines any such failure to that
  /// subtree.
  Future<void> _collect(
    Directory dir,
    List<FileMetadata> files,
    Set<String> seen,
    void Function(int scanned)? onProgress, {
    List<String> skip = const [],
    int depth = 0,
  }) async {
    if (depth > _maxDepth) return;
    if (skip.any((s) => dir.path == s || dir.path.startsWith('$s/'))) return;
    if (!await dir.exists()) return;

    final subDirs = <Directory>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          subDirs.add(entity);
          continue;
        }
        if (entity is! File) continue;
        if (!seen.add(entity.path)) continue;
        try {
          final stat = await entity.stat();
          if (stat.size == 0) continue;
          files.add(FileMetadata(
            path: entity.path,
            name: entity.uri.pathSegments.last,
            sizeBytes: stat.size,
            fileType: _detectType(entity.path),
            createdAt: stat.changed,
            lastAccessedAt: stat.modified,
            accessCount: 1,
          ));
          if (files.length % 100 == 0) onProgress?.call(files.length);
        } catch (_) {}
      }
    } catch (_) {
      // Unreadable directory — keep whatever this level yielded and move on.
    }

    for (final sub in subDirs) {
      await _collect(sub, files, seen, onProgress,
          skip: skip, depth: depth + 1);
    }
  }

  String _detectType(String path) {
    final ext = path.split('.').last.toLowerCase();
    const imageExts = {
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'tiff', 'raw'
    };
    const videoExts = {
      'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', '3gp', 'webm', 'ts'
    };
    const audioExts = {
      'mp3', 'aac', 'wav', 'flac', 'ogg', 'm4a', 'wma', 'opus'
    };
    const docExts = {
      'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'
    };
    if (imageExts.contains(ext)) return 'image';
    if (videoExts.contains(ext)) return 'video';
    if (audioExts.contains(ext)) return 'audio';
    if (docExts.contains(ext)) return 'document';
    return 'other';
  }

  Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
