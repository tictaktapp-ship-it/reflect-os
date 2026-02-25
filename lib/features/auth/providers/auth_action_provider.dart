import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepository(),
);

/// Tracks the async state of in-flight auth actions (sign in, sign up, etc.).
/// Carries AuthResponse? so callers can inspect the session after sign-up.
/// Null value means idle.
class AuthActionNotifier extends AsyncNotifier<AuthResponse?> {
  @override
  Future<AuthResponse?> build() async => null;

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signUpWithEmail(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthResponse?>(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
  }

  Future<void> resetPassword({required String email}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard<AuthResponse?>(() async {
      await ref.read(authRepositoryProvider).resetPassword(email: email);
      return null;
    });
  }
}

final authActionProvider =
    AsyncNotifierProvider<AuthActionNotifier, AuthResponse?>(
  AuthActionNotifier.new,
);
