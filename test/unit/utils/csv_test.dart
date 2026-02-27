import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CSV parsing logic', () {
    test('splitting a CSV line by comma gives correct columns', () {
      const line = 'Title,State,Stakes,Category';
      final cols = line.split(',');
      expect(cols, ['Title', 'State', 'Stakes', 'Category']);
    });

    test('handles empty lines gracefully', () {
      const csv = 'Title,State\n\nActive Decision,Active\n\n';
      final lines = csv
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);
    });

    test('first row treated as headers', () {
      const csv = 'Title,State,Stakes\nMy Decision,Active,High';
      final lines = csv
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final headers = lines.first.split(',');
      expect(headers, ['Title', 'State', 'Stakes']);
    });

    test('CRLF line endings are normalised', () {
      const csv = 'Title,State\r\nDecision A,Active\r\n';
      final lines = csv
          .replaceAll('\r\n', '\n')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);
      expect(lines.last, 'Decision A,Active');
    });

    test('data rows exclude header row', () {
      const csv = 'Title,State\nAlpha,Active\nBeta,Draft';
      final lines = csv
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final dataRows = lines.skip(1).toList();
      expect(dataRows.length, 2);
      expect(dataRows.first.split(',').first, 'Alpha');
    });
  });
}
