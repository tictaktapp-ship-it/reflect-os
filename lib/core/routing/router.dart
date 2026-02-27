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
import 'package:reflect_os/features/decisions/screens/edit_decision_screen.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/outcomes/screens/create_outcome_screen.dart';
import 'package:reflect_os/features/decisions/screens/decision_detail_screen.dart';
import 'package:reflect_os/features/decisions/screens/decisions_list_screen.dart';
import 'package:reflect_os/features/search/screens/search_screen.dart';
import 'package:reflect_os/features/dashboard/screens/dashboard_screen.dart';
import 'package:reflect_os/features/initiatives/screens/create_initiative_screen.dart';
import 'package:reflect_os/features/initiatives/screens/initiative_detail_screen.dart';
import 'package:reflect_os/features/initiatives/screens/initiatives_list_screen.dart';
import 'package:reflect_os/features/notifications/screens/notifications_screen.dart';
import 'package:reflect_os/features/billing/screens/billing_screen.dart';
import 'package:reflect_os/features/settings/screens/audit_log_screen.dart';
import 'package:reflect_os/features/settings/screens/privacy_settings_screen.dart';
import 'package:reflect_os/features/settings/screens/settings_screen.dart';
import 'package:reflect_os/features/calendar/screens/calendar_settings_screen.dart';
import 'package:reflect_os/features/import/screens/import_screen.dart';
import 'package:reflect_os/features/coaching/screens/coach_dashboard_screen.dart';
import 'package:reflect_os/features/settings/screens/vertical_settings_screen.dart';
import 'package:reflect_os/features/settings/screens/workspace_branding_screen.dart';
import 'package:reflect_os/features/sharing/screens/public_decision_view.dart';
import 'package:reflect_os/features/sharing/screens/share_links_screen.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';
import 'package:reflect_os/features/templates/screens/templates_screen.dart';
import 'package:reflect_os/features/team/screens/team_screen.dart';
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
      GoRoute(
        path: Routes.decisionsCreate,
        builder: (context, state) => CreateDecisionScreen(
          initialTemplate: state.extra as DecisionTemplate?,
        ),
      ),
      GoRoute(
        path: Routes.decisionsEdit,
        builder: (context, state) => EditDecisionScreen(
          decision: state.extra as Decision,
        ),
      ),
      GoRoute(path: Routes.initiativesCreate, builder: (context, state) => const CreateInitiativeScreen()),
      GoRoute(
        path: Routes.initiativesDetail,
        builder: (context, state) => InitiativeDetailScreen(
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: Routes.notifications, builder: (context, state) => const NotificationsScreen()),
      GoRoute(
        path: Routes.outcomesCreate,
        builder: (context, state) => CreateOutcomeScreen(
          decisionId: state.pathParameters['decisionId']!,
        ),
      ),

      // Bulk import — push above shell
      GoRoute(
        path: Routes.import,
        builder: (context, state) => const ImportScreen(),
      ),

      // Share links management — authenticated, push above shell
      GoRoute(
        path: Routes.decisionsShareLinks,
        builder: (context, state) => ShareLinksScreen(
          decisionId: state.pathParameters['id']!,
        ),
      ),

      // Public share entry — outside the shell, no auth required
      GoRoute(
        path: Routes.share,
        builder: (context, state) => PublicDecisionView(
          token: state.pathParameters['token']!,
        ),
      ),

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
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          // 3 — Initiatives
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.initiativesList,
              builder: (context, state) => const InitiativesListScreen(),
            ),
          ]),
          // 4 — Settings (privacy is a nested sub-route within this branch)
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) =>
                      const PrivacySettingsScreen(),
                ),
                GoRoute(
                  path: 'billing',
                  builder: (context, state) => const BillingScreen(),
                ),
                GoRoute(
                  path: 'audit-log',
                  builder: (context, state) => const AuditLogScreen(),
                ),
                GoRoute(
                  path: 'templates',
                  builder: (context, state) => const TemplatesScreen(),
                ),
                GoRoute(
                  path: 'calendar',
                  builder: (context, state) =>
                      const CalendarSettingsScreen(),
                ),
                GoRoute(
                  path: 'vertical',
                  builder: (context, state) =>
                      const VerticalSettingsScreen(),
                ),
                GoRoute(
                  path: 'branding',
                  builder: (context, state) =>
                      const WorkspaceBrandingScreen(),
                ),
              ],
            ),
          ]),
          // 5 — Team
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.team,
              builder: (context, state) => const TeamScreen(),
            ),
          ]),
          // 6 — Coaching
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.coachingDashboard,
              builder: (context, state) => const CoachDashboardScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

