import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/toolkit/data/models/tool_run.dart';

void main() {
  group('ToolRun.fromJson', () {
    const baseJson = {
      'id': 'run-1',
      'workspace_id': 'ws-1',
      'decision_id': 'dec-1',
      'tool_definition_id': 'tool-1',
      'tool_definition_name': 'NPV Calculator',
      'inputs_jsonb': {'discount_rate': 10.0},
      'outputs_jsonb': {'npv': 250.0},
      'created_at': '2026-01-15T10:00:00.000Z',
    };

    test('parses all fields correctly', () {
      final run = ToolRun.fromJson(baseJson);
      expect(run.id, 'run-1');
      expect(run.workspaceId, 'ws-1');
      expect(run.decisionId, 'dec-1');
      expect(run.toolDefinitionId, 'tool-1');
      expect(run.toolDefinitionName, 'NPV Calculator');
      expect(run.inputsJsonb['discount_rate'], 10.0);
      expect(run.outputsJsonb['npv'], 250.0);
      expect(run.createdAt.year, 2026);
      expect(run.createdAt.month, 1);
      expect(run.createdAt.day, 15);
    });

    test('handles missing inputs_jsonb gracefully', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('inputs_jsonb');
      final run = ToolRun.fromJson(json);
      expect(run.inputsJsonb, isEmpty);
    });

    test('handles missing outputs_jsonb gracefully', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('outputs_jsonb');
      final run = ToolRun.fromJson(json);
      expect(run.outputsJsonb, isEmpty);
    });

    test('handles missing tool_definition_name gracefully', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..remove('tool_definition_name');
      final run = ToolRun.fromJson(json);
      expect(run.toolDefinitionName, '');
    });
  });
}
