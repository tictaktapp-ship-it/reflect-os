import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/demographic_packs/data/models/demographic_pack.dart';

void main() {
  group('DemographicPack.fromJson', () {
    const baseJson = {
      'id': 'pack-1',
      'key': 'retail_investors',
      'display_name': 'Retail Investors',
      'description': 'For decisions targeting retail investors.',
      'is_active': true,
      'preferences_jsonb': {
        'description': 'Decision relevant to retail investors.',
      },
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    };

    test('parses all fields correctly', () {
      final pack = DemographicPack.fromJson(baseJson);
      expect(pack.id, 'pack-1');
      expect(pack.key, 'retail_investors');
      expect(pack.displayName, 'Retail Investors');
      expect(pack.description, 'For decisions targeting retail investors.');
      expect(pack.isActive, true);
      expect(pack.preferencesJsonb['description'],
          'Decision relevant to retail investors.');
      expect(pack.createdAt.year, 2024);
    });

    test('handles missing optional fields with defaults', () {
      final json = {
        'id': 'pack-2',
        'key': 'basic',
        'display_name': 'Basic',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };
      final pack = DemographicPack.fromJson(json);
      expect(pack.description, '');
      expect(pack.isActive, true);
      expect(pack.preferencesJsonb, isEmpty);
    });
  });
}
