import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/settings/data/models/encryption_settings.dart';

void main() {
  group('EncryptionSettings.fromJson', () {
    test('parses encrypted mode correctly', () {
      final json = {
        'workspace_id': 'ws-1',
        'encryption_mode': 'encrypted',
        'encryption_mode_changed_at': null,
        'encryption_mode_changed_by': null,
      };
      final settings = EncryptionSettings.fromJson(json);
      expect(settings.workspaceId, 'ws-1');
      expect(settings.mode, EncryptionMode.encrypted);
      expect(settings.changedAt, isNull);
      expect(settings.changedByUserId, isNull);
    });

    test('parses plaintext mode correctly', () {
      final json = {
        'workspace_id': 'ws-2',
        'encryption_mode': 'plaintext',
        'encryption_mode_changed_at': '2026-02-01T10:00:00.000Z',
        'encryption_mode_changed_by': 'user-1',
      };
      final settings = EncryptionSettings.fromJson(json);
      expect(settings.mode, EncryptionMode.plaintext);
      expect(settings.changedAt!.year, 2026);
      expect(settings.changedByUserId, 'user-1');
    });

    test('defaults to encrypted for unknown mode string', () {
      final json = {
        'workspace_id': 'ws-3',
        'encryption_mode': 'unknown_value',
        'encryption_mode_changed_at': null,
        'encryption_mode_changed_by': null,
      };
      final settings = EncryptionSettings.fromJson(json);
      expect(settings.mode, EncryptionMode.encrypted);
    });

    test('defaults to encrypted when mode is null', () {
      final json = {
        'workspace_id': 'ws-4',
        // no 'encryption_mode' key
      };
      final settings = EncryptionSettings.fromJson(json);
      expect(settings.mode, EncryptionMode.encrypted);
    });
  });

  group('EncryptionPermissionException', () {
    test('holds the message', () {
      const e = EncryptionPermissionException('test message');
      expect(e.message, 'test message');
    });
  });
}
