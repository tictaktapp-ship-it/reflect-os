import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPrefsKey = 'has_logged_first_decision';

/// Set to true in-session when the user completes onboarding.
/// Prevents re-showing the welcome screen without waiting for SharedPreferences.
final firstRunCompletedProvider = StateProvider<bool>((ref) => false);

/// True if the user has NOT yet logged their first decision.
final _firstRunPrefsProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kPrefsKey) ?? false);
});

/// Returns true when the welcome screen should be shown.
final firstRunProvider = Provider<bool>((ref) {
  if (ref.watch(firstRunCompletedProvider)) return false;
  return ref.watch(_firstRunPrefsProvider).valueOrNull ?? false;
});

/// Call this after the user logs their first decision.
Future<void> markFirstRunComplete(WidgetRef ref) async {
  ref.read(firstRunCompletedProvider.notifier).state = true;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kPrefsKey, true);
}
