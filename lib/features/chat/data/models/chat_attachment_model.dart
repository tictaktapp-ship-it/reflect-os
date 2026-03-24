class ChatAttachmentModel {
  const ChatAttachmentModel({
    required this.id,
    required this.messageId,
    required this.workspaceId,
    required this.uploadedBy,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    required this.storagePath,
    required this.isImage,
    this.imageWidth,
    this.imageHeight,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String workspaceId;
  final String uploadedBy;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final String storagePath;
  final bool isImage;
  final int? imageWidth;
  final int? imageHeight;
  final DateTime createdAt;

  factory ChatAttachmentModel.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      workspaceId: json['workspace_id'] as String,
      uploadedBy: json['uploaded_by'] as String,
      fileName: json['file_name'] as String,
      fileSizeBytes: json['file_size_bytes'] as int,
      mimeType: json['mime_type'] as String,
      storagePath: json['storage_path'] as String,
      isImage: json['is_image'] as bool? ?? false,
      imageWidth: json['image_width'] as int?,
      imageHeight: json['image_height'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '< 1 KB';
    if (fileSizeBytes < 1048576) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / 1048576).toStringAsFixed(1)} MB';
  }
}
