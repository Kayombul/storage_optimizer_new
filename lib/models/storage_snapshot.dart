class StorageSnapshot {
  final int? id;
  final DateTime timestamp;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;

  const StorageSnapshot({
    this.id,
    required this.timestamp,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });

  double get usedPercent =>
      totalBytes > 0 ? (usedBytes / totalBytes) * 100 : 0.0;

  double get usedGB => usedBytes / (1024 * 1024 * 1024);
  double get freeGB => freeBytes / (1024 * 1024 * 1024);
  double get totalGB => totalBytes / (1024 * 1024 * 1024);

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'totalBytes': totalBytes,
        'usedBytes': usedBytes,
        'freeBytes': freeBytes,
      };

  factory StorageSnapshot.fromMap(Map<String, dynamic> map) => StorageSnapshot(
        id: map['id'] as int?,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        totalBytes: map['totalBytes'] as int,
        usedBytes: map['usedBytes'] as int,
        freeBytes: map['freeBytes'] as int,
      );
}
