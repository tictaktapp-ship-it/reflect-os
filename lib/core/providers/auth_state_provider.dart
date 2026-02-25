import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class AuthStatus {
  const AuthStatus();
}

final class AuthAuthenticated extends AuthStatus {
  const AuthAuthenticated(this.session);
  final Session session;
}

final class AuthUnauthenticated extends AuthStatus {
  const AuthUnauthenticated();
}

final class AuthLoading extends AuthStatus {
  const AuthLoading();
}

final authStateProvider = StreamProvider<AuthStatus>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((data) {
    final session = data.session;
    if (session != null) {
      return AuthAuthenticated(session);
    }
    return const AuthUnauthenticated();
  });
});
