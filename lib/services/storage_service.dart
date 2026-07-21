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

  static const _scanDirs = [
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/WhatsApp/Media',
  ];

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
    int count = 0;
    for (final dirPath in _scanDirs) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;
      try {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
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
            count++;
            if (count % 100 == 0) onProgress?.call(count);
          } catch (_) {}
        }
      } catch (_) {}
    }
    onProgress?.call(count);
    return files;
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
