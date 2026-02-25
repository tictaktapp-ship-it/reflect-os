import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'routes.dart';

// TODO: replace with real provider once implemented.
// import 'package:reflect_os/core/providers/subscription_status_provider.dart';

/// Placeholder subscription state — replace with subscriptionStatusProvider.
final _subscriptionStatusProvider = Provider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authStateProvider);
  final isAuthenticated = authStatus.valueOrNull is AuthAuthenticated;
  final isSubscribed = ref.watch(_subscriptionStatusProvider);

  return GoRouter(
    initialLocation: Routes.home,
    redirect: (BuildContext context, GoRouterState state) {
      final isPublicRoute = state.matchedLocation.startsWith('/share/') ||
          state.matchedLocation.startsWith('/auth/');

      if (!isAuthenticated && !isPublicRoute) {
        return Routes.login;
      }

      if (isAuthenticated && !isSubscribed) {
        final isBillingRoute =
            state.matchedLocation.startsWith('/billing/');
        if (!isBillingRoute && !isPublicRoute) {
          return '/billing/subscribe';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (context, state) => const _Placeholder('Login')),
      GoRoute(path: Routes.register, builder: (context, state) => const _Placeholder('Register')),
      GoRoute(path: Routes.forgotPassword, builder: (context, state) => const _Placeholder('Forgot Password')),
      GoRoute(path: Routes.home, builder: (context, state) => const _Placeholder('Home')),
      GoRoute(path: Routes.decisionsList, builder: (context, state) => const _Placeholder('Decisions')),
      GoRoute(path: Routes.decisionsDetail, builder: (context, state) => const _Placeholder('Decision Detail')),
      GoRoute(path: Routes.decisionsCreate, builder: (context, state) => const _Placeholder('Create Decision')),
      GoRoute(path: Routes.outcomesCreate, builder: (context, state) => const _Placeholder('Create Outcome')),
      GoRoute(path: Routes.search, builder: (context, state) => const _Placeholder('Search')),
      GoRoute(path: Routes.settings, builder: (context, state) => const _Placeholder('Settings')),
      GoRoute(path: Routes.settingsPrivacy, builder: (context, state) => const _Placeholder('Privacy Settings')),
      GoRoute(path: Routes.share, builder: (context, state) => const _Placeholder('Share')),
    ],
  );
});

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
