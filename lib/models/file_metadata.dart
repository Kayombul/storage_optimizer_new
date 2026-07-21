class FileMetadata {
  final int? id;
  final String path;
  final String name;
  final int sizeBytes;
  final String fileType;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final int accessCount;
  final double valueScore;
  final bool isRecommendedForDeletion;
  final String scoreReason;

  const FileMetadata({
    this.id,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.fileType,
    required this.createdAt,
    required this.lastAccessedAt,
    this.accessCount = 1,
    this.valueScore = 0.0,
    this.isRecommendedForDeletion = false,
    this.scoreReason = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'path': path,
        'name': name,
        'sizeBytes': sizeBytes,
        'fileType': fileType,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastAccessedAt': lastAccessedAt.millisecondsSinceEpoch,
        'accessCount': accessCount,
        'valueScore': valueScore,
        'isRecommendedForDeletion': isRecommendedForDeletion ? 1 : 0,
        'scoreReason': scoreReason,
      };

  factory FileMetadata.fromMap(Map<String, dynamic> map) => FileMetadata(
        id: map['id'] as int?,
        path: map['path'] as String,
        name: map['name'] as String,
        sizeBytes: map['sizeBytes'] as int,
        fileType: map['fileType'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        lastAccessedAt:
            DateTime.fromMillisecondsSinceEpoch(map['lastAccessedAt'] as int),
        accessCount: map['accessCount'] as int,
        valueScore: (map['valueScore'] as num).toDouble(),
        isRecommendedForDeletion: (map['isRecommendedForDeletion'] as int) == 1,
        scoreReason: map['scoreReason'] as String? ?? '',
      );

  FileMetadata copyWith({
    int? id,
    double? valueScore,
    bool? isRecommendedForDeletion,
    String? scoreReason,
    int? accessCount,
  }) =>
      FileMetadata(
        id: id ?? this.id,
        path: path,
        name: name,
        sizeBytes: sizeBytes,
        fileType: fileType,
        createdAt: createdAt,
        lastAccessedAt: lastAccessedAt,
        accessCount: accessCount ?? this.accessCount,
        valueScore: valueScore ?? this.valueScore,
        isRecommendedForDeletion:
            isRecommendedForDeletion ?? this.isRecommendedForDeletion,
        scoreReason: scoreReason ?? this.scoreReason,
      );
}
