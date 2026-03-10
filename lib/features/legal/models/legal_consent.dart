class LegalConsent {
  const LegalConsent({
    required this.id,
    required this.userId,
    required this.tcVersion,
    required this.privacyVersion,
    required this.cookieConsent,
    required this.acceptedAt,
    this.platform,
  });

  final String id;
  final String userId;
  final String tcVersion;
  final String privacyVersion;
  final bool cookieConsent;
  final DateTime acceptedAt;
  final String? platform;

  factory LegalConsent.fromJson(Map<String, dynamic> json) => LegalConsent(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        tcVersion: json['tc_version'] as String,
        privacyVersion: json['privacy_version'] as String,
        cookieConsent: json['cookie_consent'] as bool? ?? false,
        acceptedAt: DateTime.parse(json['accepted_at'] as String),
        platform: json['platform'] as String?,
      );
}
