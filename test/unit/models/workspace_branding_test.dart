import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/settings/data/models/workspace_branding.dart';

void main() {
  group('WorkspaceBranding.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'workspace_id': 'ws-1',
        'logo_file_url': 'https://example.com/logo.png',
        'company_name': 'Acme Corp',
        'company_tagline': 'Making the future',
        'primary_color_hex': '#1A2B3C',
        'secondary_color_hex': '#FFFFFF',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-02T00:00:00.000Z',
      };
      final b = WorkspaceBranding.fromJson(json);
      expect(b.workspaceId, 'ws-1');
      expect(b.logoFileUrl, 'https://example.com/logo.png');
      expect(b.companyName, 'Acme Corp');
      expect(b.companyTagline, 'Making the future');
      expect(b.primaryColorHex, '#1A2B3C');
      expect(b.secondaryColorHex, '#FFFFFF');
      expect(b.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(b.updatedAt, DateTime.parse('2026-01-02T00:00:00.000Z'));
    });

    test('handles null optional fields gracefully', () {
      final json = {
        'workspace_id': 'ws-2',
        'logo_file_url': null,
        'company_name': null,
        'company_tagline': null,
        'primary_color_hex': null,
        'secondary_color_hex': null,
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };
      final b = WorkspaceBranding.fromJson(json);
      expect(b.logoFileUrl, isNull);
      expect(b.companyName, isNull);
      expect(b.companyTagline, isNull);
      expect(b.primaryColorHex, isNull);
      expect(b.secondaryColorHex, isNull);
    });
  });
}
