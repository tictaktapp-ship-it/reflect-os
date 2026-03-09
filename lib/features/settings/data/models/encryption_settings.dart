/// Encryption mode for the workspace.
///
/// [encrypted] — all new decisions are stored end-to-end encrypted (default).
/// [plaintext] — new decisions are stored without encryption.
/// Changing mode does NOT retroactively re-encrypt or decrypt existing rows.
enum EncryptionMode { encrypted, plaintext }

class EncryptionSettings {
  final String workspaceId;
  final EncryptionMode mode;
  final DateTime? changedAt;
  final String? changedByUserId;

  const EncryptionSettings({
    required this.workspaceId,
    required this.mode,
    this.changedAt,
    this.changedByUserId,
  });

  factory EncryptionSettings.fromJson(Map<String, dynamic> json) {
    final modeStr = json['decision_encryption_mode'] as String? ?? 'encrypted';
    return EncryptionSettings(
      workspaceId: json['workspace_id'] as String,
      mode: modeStr == 'plaintext'
          ? EncryptionMode.plaintext
          : EncryptionMode.encrypted,
      changedAt: json['encryption_mode_changed_at'] == null
          ? null
          : DateTime.parse(json['encryption_mode_changed_at'] as String),
      changedByUserId:
          json['encryption_mode_changed_by'] as String?,
    );
  }
}

/// Thrown when a non-owner attempts to change the encryption mode.
class EncryptionPermissionException implements Exception {
  const EncryptionPermissionException(this.message);
  final String message;
}
