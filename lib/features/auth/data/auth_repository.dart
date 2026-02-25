import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

class AuthRepository {
  const AuthRepository();

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) =>
      supabase.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      supabase.auth.signUp(email: email, password: password);

  Future<void> signOut() => supabase.auth.signOut();

  Future<void> resetPassword({required String email}) =>
      supabase.auth.resetPasswordForEmail(email);
}
