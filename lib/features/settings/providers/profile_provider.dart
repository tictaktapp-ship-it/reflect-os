import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/features/settings/data/models/profile_model.dart';
import 'package:reflect_os/features/settings/data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepository();
});

/// Fetches the profile reactively — re-runs whenever auth state changes so
/// it works correctly on cold start (before the session is restored) and
/// after sign-in/sign-out.
final profileProvider = FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final authStatus = ref.watch(authStateProvider).valueOrNull;
  final userId = authStatus is AuthAuthenticated
      ? authStatus.session.user.id
      : null;
  if (userId == null) return null;
  return ref.read(profileRepositoryProvider).getProfile(userId);
});
