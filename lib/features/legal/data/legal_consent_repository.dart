import 'package:reflect_os/core/constants/legal_versions.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/legal/models/legal_consent.dart';

class LegalConsentRepository {
  const LegalConsentRepository();

  /// Returns true if the user has accepted the current T&C and Privacy versions.
  Future<bool> hasAcceptedCurrentVersions(String userId) async {
    final rows = await supabase
        .from('legal_consents')
        .select('id')
        .eq('user_id', userId)
        .eq('tc_version', LegalVersions.tcVersion)
        .eq('privacy_version', LegalVersions.privacyVersion)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// Inserts a new immutable consent record. Never updates or deletes.
  Future<void> recordConsent({
    required String userId,
    required bool cookieConsent,
    required String platform,
  }) async {
    try {
      await supabase.from('legal_consents').insert({
        'user_id': userId,
        'tc_version': LegalVersions.tcVersion,
        'privacy_version': LegalVersions.privacyVersion,
        'cookie_consent': cookieConsent,
        'platform': platform,
        // ip_address and user_agent are not passed from Flutter
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the most recent consent row for the user, or null if none.
  Future<LegalConsent?> getLatestConsent(String userId) async {
    final row = await supabase
        .from('legal_consents')
        .select()
        .eq('user_id', userId)
        .order('accepted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return LegalConsent.fromJson(row);
  }
}
