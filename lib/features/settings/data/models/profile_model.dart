class ProfileModel {
  const ProfileModel({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.timezone,
    this.locale,
    this.themePreference,
  });

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final String? timezone;
  final String? locale;
  final String? themePreference;

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        timezone: json['timezone'] as String?,
        locale: json['locale'] as String?,
        themePreference: json['theme_preference'] as String?,
      );
}
