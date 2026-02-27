import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';

RiskAssessment _make(Map<String, dynamic> outputJsonb) {
  return RiskAssessment(
    id: 'ra-1',
    decisionId: 'dec-1',
    provider: 'openai',
    model: 'gpt-4o',
    status: 'complete',
    outputJsonb: outputJsonb,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('RiskAssessment getters', () {
    test('overallRiskLevel returns correct string', () {
      final ra = _make({'overall_risk_level': 'High'});
      expect(ra.overallRiskLevel, 'High');
    });

    test('overallRiskLevel returns null when key missing', () {
      final ra = _make({});
      expect(ra.overallRiskLevel, isNull);
    });

    test('risks returns empty list when key missing', () {
      final ra = _make({});
      expect(ra.risks, isEmpty);
    });

    test('risks returns correct list when present', () {
      final ra = _make({
        'risks': [
          {'label': 'Regulatory', 'severity': 'High'},
          {'label': 'FX', 'severity': 'Medium'},
        ],
      });
      expect(ra.risks.length, 2);
      expect(ra.risks.first['label'], 'Regulatory');
    });

    test('summary returns null when key missing', () {
      final ra = _make({});
      expect(ra.summary, isNull);
    });

    test('summary returns correct string when present', () {
      final ra = _make({'summary': 'Moderate overall risk.'});
      expect(ra.summary, 'Moderate overall risk.');
    });

    test('handles malformed risks and confidence without throwing', () {
      // risks and confidence have defensive type checks; wrong types return
      // defaults rather than throwing.
      final ra = _make({
        'risks': 'not a list', // wrong type — falls back to []
        'confidence': 'not a number', // wrong type — falls back to null
      });
      expect(() => ra.risks, returnsNormally);
      expect(() => ra.confidence, returnsNormally);
      expect(ra.risks, isEmpty);
      expect(ra.confidence, isNull);
    });
  });
}
