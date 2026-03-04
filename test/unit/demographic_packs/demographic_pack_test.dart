import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/demographic_packs/data/models/demographic_pack.dart';

void main() {
  group('DemographicPack.fromJson', () {
    const baseJson = {
      'id': 'pack-1',
      'name': 'Retail Investors',
      'description': 'For decisions targeting retail investors.',
      'target_audience': 'Retail investors',
      'pre_populate_fields': {
        'description': 'Decision relevant to retail investors.',
      },
    };

    test('parses all fields correctly', () {
      final pack = DemographicPack.fromJson(baseJson);
      expect(pack.id, 'pack-1');
      expect(pack.name, 'Retail Investors');
      expect(pack.description, 'For decisions targeting retail investors.');
      expect(pack.targetAudience, 'Retail investors');
      expect(pack.prePopulateFields['description'],
          'Decision relevant to retail investors.');
    });

    test('handles missing optional fields with defaults', () {
      final json = {'id': 'pack-2', 'name': 'Basic'};
      final pack = DemographicPack.fromJson(json);
      expect(pack.description, '');
      expect(pack.targetAudience, '');
      expect(pack.prePopulateFields, isEmpty);
    });
  });
}
