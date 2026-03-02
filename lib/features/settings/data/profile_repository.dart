import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/settings/data/models/profile_model.dart';

class ProfileRepository {
  const ProfileRepository();

  Future<ProfileModel?> getProfile(String userId) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ProfileModel.fromJson(row);
  }

  Future<void> updateDisplayName(String userId, String displayName) async {
    await supabase.from('profiles').upsert(
      {'user_id': userId, 'display_name': displayName},
      onConflict: 'user_id',
    );
  }

  /// Uploads [file] to the avatars bucket and returns the public URL.
  Future<String> uploadAvatar(String userId, XFile file) async {
    final ext = file.name.split('.').last.toLowerCase();
    const validExts = {'jpg', 'jpeg', 'png', 'webp'};
    final safeExt = validExts.contains(ext) ? ext : 'jpg';
    final path = '$userId/avatar.$safeExt';
    final bytes = await file.readAsBytes();
    await supabase.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: 'image/$safeExt', upsert: true),
    );
    return supabase.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> updateAvatarUrl(String userId, String? avatarUrl) async {
    await supabase.from('profiles').upsert(
      {'user_id': userId, 'avatar_url': avatarUrl},
      onConflict: 'user_id',
    );
  }

  Future<void> removeAvatar(String userId) async {
    await supabase.from('profiles').upsert(
      {'user_id': userId, 'avatar_url': null},
      onConflict: 'user_id',
    );
  }
}
