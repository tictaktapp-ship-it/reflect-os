import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/providers/subscription_status_provider.dart';
import 'package:reflect_os/core/routing/app_shell.dart';
import 'package:reflect_os/features/auth/screens/forgot_password_screen.dart';
import 'package:reflect_os/features/auth/screens/home_screen.dart';
import 'package:reflect_os/features/auth/screens/login_screen.dart';
import 'package:reflect_os/features/auth/screens/register_screen.dart';
import 'package:reflect_os/features/billing/screens/billing_subscribe_screen.dart';
import 'package:reflect_os/features/decisions/screens/create_decision_screen.dart';
import 'package:reflect_os/features/outcomes/screens/create_outcome_screen.dart';
import 'package:reflect_os/features/decisions/screens/decision_detail_screen.dart';
import 'package:reflect_os/features/decisions/screens/decisions_list_screen.dart';
import 'package:reflect_os/features/search/screens/search_screen.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authStateProvider);
  final isAuthenticated = authStatus.valueOrNull is AuthAuthenticated;
  final subscriptionStatus = ref.watch(subscriptionStatusProvider);
  final isSubscribed =
      subscriptionStatus.valueOrNull == SubscriptionStatus.active;

  return GoRouter(
    initialLocation: Routes.decisionsList,
    redirect: (BuildContext context, GoRouterState state) {
      final isPublicRoute = state.matchedLocation.startsWith('/share/') ||
          state.matchedLocation.startsWith('/auth/');

      if (!isAuthenticated && !isPublicRoute) {
        return Routes.login;
      }

      if (isAuthenticated && !isSubscribed) {
        final isBillingRoute = state.matchedLocation.startsWith('/billing/');
        if (!isBillingRoute && !isPublicRoute) {
          return Routes.billingSubscribe;
        }
      }

      return null;
    },
    routes: [
      // Auth routes — outside the shell, no navigation chrome
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),

      // Legacy home placeholder — outside the shell
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),

      // Detail / create routes — push above the shell (no nav chrome)
      GoRoute(
        path: Routes.decisionsDetail,
        builder: (context, state) => DecisionDetailScreen(
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: Routes.decisionsCreate, builder: (context, state) => const CreateDecisionScreen()),
      GoRoute(
        path: Routes.outcomesCreate,
        builder: (context, state) => CreateOutcomeScreen(
          decisionId: state.pathParameters['decisionId']!,
        ),
      ),

      // Public share entry — outside the shell, no auth required
      GoRoute(path: Routes.share, builder: (context, state) => const _Placeholder('Share')),

      // Billing gate — outside the shell
      GoRoute(path: Routes.billingSubscribe, builder: (context, state) => const BillingSubscribeScreen()),

      // Main app shell — wraps the four primary destinations
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0 — Decisions
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.decisionsList,
              builder: (context, state) => const DecisionsListScreen(),
            ),
          ]),
          // 1 — Search
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.search,
              builder: (context, state) => const SearchScreen(),
            ),
          ]),
          // 2 — Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.dashboard,
              builder: (context, state) => const _Placeholder('Dashboard'),
            ),
          ]),
          // 3 — Settings (privacy is a nested sub-route within this branch)
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              builder: (context, state) => const _Placeholder('Settings'),
              routes: [
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) =>
                      const _Placeholder('Privacy Settings'),
                ),
              ],
            ),
          ]),
        ],
      ),
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
