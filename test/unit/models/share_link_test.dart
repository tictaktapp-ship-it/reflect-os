import 'package:flutter_test/flutter_test.dart';
import 'package:reflect_os/features/sharing/data/models/share_link.dart';

ShareLink _makeLink({DateTime? expiresAt, DateTime? revokedAt}) {
  return ShareLink(
    id: 'link-1',
    decisionId: 'dec-1',
    createdByUserId: 'user-1',
    tokenHash: 'abc123',
    expiresAt: expiresAt,
    revokedAt: revokedAt,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('ShareLink.isActive', () {
    test('returns true when revokedAt is null and expiresAt is null', () {
      expect(_makeLink().isActive, isTrue);
    });

    test('returns true when revokedAt is null and expiresAt is in the future',
        () {
      final link = _makeLink(
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(link.isActive, isTrue);
    });

    test('returns false when revokedAt is not null', () {
      final link = _makeLink(revokedAt: DateTime(2026, 1, 2));
      expect(link.isActive, isFalse);
    });

    test('returns false when expiresAt is in the past', () {
      final link = _makeLink(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(link.isActive, isFalse);
    });
  });
}
