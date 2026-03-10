import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/features/legal/data/legal_consent_repository.dart';
import 'package:reflect_os/features/legal/models/legal_consent.dart';

final legalConsentRepositoryProvider = Provider<LegalConsentRepository>(
  (_) => const LegalConsentRepository(),
);

// ── Check provider ────────────────────────────────────────────────────────────

/// AsyncNotifier of bool — true means legal has been accepted (or user is
/// unauthenticated, so no gate is needed). false means the gate must show.
class LegalConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // Re-run whenever auth state changes.
    final authAsync = ref.watch(authStateProvider);
    final authStatus = authAsync.valueOrNull;

    // While loading or unauthenticated, don't block navigation.
    if (authStatus == null || authStatus is! AuthAuthenticated) return true;

    final userId = authStatus.session.user.id;
    return ref
        .read(legalConsentRepositoryProvider)
        .hasAcceptedCurrentVersions(userId);
  }

  /// Record the user's consent and flip state to accepted.
  Future<void> acceptConsent(bool cookieConsent) async {
    state = const AsyncLoading();
    try {
      final authStatus = ref.read(authStateProvider).valueOrNull;
      if (authStatus is! AuthAuthenticated) return;
      final userId = authStatus.session.user.id;
      final platform = _platformString();
      await ref.read(legalConsentRepositoryProvider).recordConsent(
            userId: userId,
            cookieConsent: cookieConsent,
            platform: platform,
          );
      state = const AsyncData(true);
      ref.invalidate(latestConsentProvider(userId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final legalConsentCheckProvider =
    AsyncNotifierProvider<LegalConsentNotifier, bool>(
  LegalConsentNotifier.new,
);

// ── Latest consent provider ───────────────────────────────────────────────────

/// Fetches the most recent consent record for a given userId.
/// Keyed by userId so it auto-refreshes when invalidated after acceptConsent.
final latestConsentProvider =
    FutureProvider.autoDispose.family<LegalConsent?, String>((ref, userId) {
  return ref
      .read(legalConsentRepositoryProvider)
      .getLatestConsent(userId);
});

// ── Helpers ───────────────────────────────────────────────────────────────────

String _platformString() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    default:
      return 'other';
  }
}
