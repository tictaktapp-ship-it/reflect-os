import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';

void main() {
  group('Decision.fromJson', () {
    const baseJson = {
      'id': 'dec-1',
      'title': 'Should we expand to Europe?',
      'state': 'Active',
      'stakes': 'High',
      'initial_confidence': 70,
      'category_name': 'Strategic',
      'description_encrypted': 'enc-text',
      'health_state': 'On Track',
      'decision_deadline': '2026-06-01T00:00:00.000Z',
      'created_at': '2026-01-01T10:00:00.000Z',
      'updated_at': '2026-01-02T10:00:00.000Z',
      'requires_approval': true,
      'source_decision_id': 'dec-0',
      'shared_to_team_at': null,
      'shared_from_personal_at': null,
    };

    test('parses all fields correctly', () {
      final d = Decision.fromJson(baseJson);
      expect(d.id, 'dec-1');
      expect(d.title, 'Should we expand to Europe?');
      expect(d.state, 'Active');
      expect(d.stakes, 'High');
      expect(d.initialConfidence, 70);
      expect(d.categoryName, 'Strategic');
      expect(d.descriptionEncrypted, 'enc-text');
      expect(d.healthState, 'On Track');
      expect(d.decisionDeadline, DateTime.parse('2026-06-01T00:00:00.000Z'));
      expect(d.createdAt, DateTime.parse('2026-01-01T10:00:00.000Z'));
      expect(d.updatedAt, DateTime.parse('2026-01-02T10:00:00.000Z'));
      expect(d.requiresApproval, isTrue);
      expect(d.sourceDecisionId, 'dec-0');
    });

    test('isActive returns true when state is Active', () {
      final d = Decision.fromJson(baseJson);
      expect(d.isActive, isTrue);
      expect(d.isDraft, isFalse);
    });

    test('isDraft returns true when state is Draft', () {
      final d = Decision.fromJson({...baseJson, 'state': 'Draft'});
      expect(d.isDraft, isTrue);
      expect(d.isActive, isFalse);
    });

    test('requiresApproval defaults to false when missing from json', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('requires_approval');
      final d = Decision.fromJson(json);
      expect(d.requiresApproval, isFalse);
    });

    test('handles null optional fields without throwing', () {
      final json = {
        'id': 'dec-2',
        'title': 'Minimal',
        'state': 'Draft',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };
      final d = Decision.fromJson(json);
      expect(d.stakes, isNull);
      expect(d.initialConfidence, isNull);
      expect(d.categoryName, isNull);
      expect(d.descriptionEncrypted, isNull);
      expect(d.healthState, isNull);
      expect(d.decisionDeadline, isNull);
      expect(d.sourceDecisionId, isNull);
    });
  });
}
