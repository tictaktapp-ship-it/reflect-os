import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// AES-256-CBC encryption service for decision content.
///
/// Keys are derived deterministically from workspace IDs using SHA-256.
/// Encrypted values are stored as "iv_base64:ciphertext_base64".
///
/// Note: In production, consider a proper KMS for key management.
/// This implementation provides encryption-at-rest within the app tier.
class EncryptionService {
  const EncryptionService._();

  /// Derives a 32-byte AES key from [workspaceId] via SHA-256.
  static enc.Key _keyFrom(String workspaceId) {
    final bytes =
        sha256.convert(utf8.encode('reflect-os-v1-$workspaceId')).bytes;
    return enc.Key(Uint8List.fromList(bytes));
  }

  /// Encrypts [plaintext] using AES-256-CBC with a random 16-byte IV.
  ///
  /// Returns a string formatted as "iv_base64:ciphertext_base64".
  /// Returns [plaintext] unchanged if it is empty.
  static String encrypt(String plaintext, String workspaceId) {
    if (plaintext.isEmpty) return plaintext;
    final key = _keyFrom(workspaceId);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts a value produced by [encrypt].
  ///
  /// If [ciphertext] does not match the expected encrypted format
  /// (e.g. legacy plaintext stored before encryption was enabled),
  /// it is returned as-is so existing data is never corrupted.
  static String decrypt(String ciphertext, String workspaceId) {
    if (ciphertext.isEmpty) return ciphertext;
    // Encrypted values: two colon-separated segments where the IV
    // portion is exactly 24 characters (16 bytes base64-encoded).
    if (!ciphertext.contains(':')) return ciphertext;
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 2 || parts[0].length != 24) return ciphertext;
      final key = _keyFrom(workspaceId);
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      // Decryption failure — treat as legacy plaintext.
      return ciphertext;
    }
  }

  /// Returns true if [value] appears to be encrypted by this service.
  static bool isEncrypted(String value) {
    if (!value.contains(':')) return false;
    final parts = value.split(':');
    return parts.length == 2 && parts[0].length == 24;
  }
}
