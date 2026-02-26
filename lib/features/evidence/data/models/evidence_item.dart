class EvidenceItem {
  const EvidenceItem({
    required this.id,
    required this.decisionId,
    required this.type,
    this.label,
    this.url,
    this.storageBucket,
    this.storagePath,
    this.originalFilename,
    this.mimeType,
    this.fileSizeBytes,
    this.createdByUserId,
    required this.createdAt,
  });

  final String id;
  final String decisionId;
  final String type; // 'link' | 'file'
  final String? label;
  final String? url;
  final String? storageBucket;
  final String? storagePath;
  final String? originalFilename;
  final String? mimeType;
  final int? fileSizeBytes;
  final String? createdByUserId;
  final DateTime createdAt;

  factory EvidenceItem.fromJson(Map<String, dynamic> json) => EvidenceItem(
        id: json['id'] as String,
        decisionId: json['decision_id'] as String,
        type: json['type'] as String,
        label: json['label'] as String?,
        url: json['url'] as String?,
        storageBucket: json['storage_bucket'] as String?,
        storagePath: json['storage_path'] as String?,
        originalFilename: json['original_filename'] as String?,
        mimeType: json['mime_type'] as String?,
        fileSizeBytes: json['file_size_bytes'] == null
            ? null
            : (json['file_size_bytes'] as num).toInt(),
        createdByUserId: json['created_by_user_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
