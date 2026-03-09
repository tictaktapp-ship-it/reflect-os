import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edge-function-based encryption service.
///
/// All cryptographic operations are delegated to the `encrypt-decrypt`
/// Supabase edge function, which manages AES-256-GCM keys via Vault.
/// Encrypted values are prefixed with `v1:` to distinguish them from legacy
/// plaintext stored before encryption was enabled.
class EncryptionService {
  final SupabaseClient _supabase;
  const EncryptionService(this._supabase);

  /// Encrypts [fields] for the given [workspaceId].
  /// Returns a map of fieldName → encryptedValue.
  Future<Map<String, String?>> encryptFields({
    required String workspaceId,
    required Map<String, String?> fields,
  }) async {
    final response = await _supabase.functions.invoke(
      'encrypt-decrypt',
      body: {
        'action': 'encrypt',
        'workspace_id': workspaceId,
        'fields': fields,
      },
    );
    if (response.status != 200) {
      throw Exception('Encryption failed: ${response.data}');
    }
    final encrypted =
        response.data['encrypted'] as Map<String, dynamic>;
    return encrypted.map((k, v) => MapEntry(k, v as String?));
  }

  /// Decrypts [fields] for the given [workspaceId].
  /// Null or empty values are passed through unchanged.
  Future<Map<String, String?>> decryptFields({
    required String workspaceId,
    required Map<String, String?> fields,
  }) async {
    // Only send non-null, non-empty values to the edge function.
    final nonNull = Map<String, String?>.fromEntries(
      fields.entries.where((e) => e.value != null && e.value!.isNotEmpty),
    );
    if (nonNull.isEmpty) return fields;

    final response = await _supabase.functions.invoke(
      'encrypt-decrypt',
      body: {
        'action': 'decrypt',
        'workspace_id': workspaceId,
        'fields': nonNull,
      },
    );
    if (response.status != 200) {
      throw Exception('Decryption failed: ${response.data}');
    }
    final decrypted =
        response.data['decrypted'] as Map<String, dynamic>;
    // Merge decrypted values back, preserving nulls from the original map.
    return fields.map((k, v) {
      if (decrypted.containsKey(k)) {
        return MapEntry(k, decrypted[k] as String?);
      }
      return MapEntry(k, v);
    });
  }

  /// Checks which fields are actually encrypted (for the verification UI).
  /// Returns a map of fieldName → isEncrypted.
  Future<Map<String, bool>> checkEncryptionStatus({
    required String workspaceId,
    required Map<String, String?> fields,
  }) async {
    final response = await _supabase.functions.invoke(
      'encrypt-decrypt',
      body: {
        'action': 'check',
        'workspace_id': workspaceId,
        'fields': fields,
      },
    );
    if (response.status != 200) return {};
    final status =
        response.data['encryption_status'] as Map<String, dynamic>? ?? {};
    return status.map((k, v) => MapEntry(k, v as bool));
  }

  /// Quick local check (no network) — encrypted values start with `v1:`.
  static bool isEncrypted(String? value) => value?.startsWith('v1:') ?? false;
}

final encryptionServiceProvider = Provider<EncryptionService>(
  (ref) => EncryptionService(Supabase.instance.client),
);
