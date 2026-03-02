import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/settings/data/models/profile_model.dart';
import 'package:reflect_os/features/settings/data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepository();
});

final profileProvider = FutureProvider<ProfileModel?>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;
  return ref.read(profileRepositoryProvider).getProfile(userId);
});
