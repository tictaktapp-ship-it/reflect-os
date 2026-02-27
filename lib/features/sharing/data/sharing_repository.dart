import 'dart:convert';
import 'dart:math';

import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/sharing/data/models/share_link.dart';

class SharingRepository {
  const SharingRepository();

  Future<List<ShareLink>> getShareLinks(String decisionId) async {
    final rows = await supabase
        .from('share_links')
        .select()
        .eq('decision_id', decisionId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return rows.map((row) => ShareLink.fromJson(row)).toList();
  }

  /// Generates a cryptographically random token, inserts a share link row,
  /// and returns the token so the caller can construct the full share URL.
  Future<String> createShareLink(
    String decisionId, {
    DateTime? expiresAt,
  }) async {
    final token = base64Url.encode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await supabase.from('share_links').insert({
      'decision_id': decisionId,
      'created_by_user_id': supabase.auth.currentUser!.id,
      'token_hash': token,
      if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
    });
    return token;
  }

  Future<void> revokeShareLink(String id) async {
    await supabase.from('share_links').update({
      'revoked_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
