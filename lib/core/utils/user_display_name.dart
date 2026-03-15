/// Priority: fullName > displayName > email > first 8 chars of userId + '...'
String displayNameForUser({
  String? fullName,
  String? displayName,
  String? email,
  required String userId,
}) {
  if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
  if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
  if (email != null && email.trim().isNotEmpty) return email.trim();
  return '${userId.substring(0, userId.length >= 8 ? 8 : userId.length)}...';
}

/// First letter of the resolved display name (uppercase), for avatars.
String avatarInitialForUser({
  String? fullName,
  String? displayName,
  String? email,
  required String userId,
}) {
  final name = displayNameForUser(
      fullName: fullName,
      displayName: displayName,
      email: email,
      userId: userId);
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}
