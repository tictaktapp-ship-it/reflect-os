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
import 'package:reflect_os/features/decisions/screens/meeting_capture_screen.dart';
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
import 'package:reflect_os/features/investment/screens/assets_screen.dart';
import 'package:reflect_os/features/settings/screens/data_privacy_screen.dart';
import 'package:reflect_os/features/settings/screens/vertical_settings_screen.dart';
import 'package:reflect_os/features/settings/screens/workspace_branding_screen.dart';
import 'package:reflect_os/features/sharing/screens/public_decision_view.dart';
import 'package:reflect_os/features/risk/data/models/risk_assessment.dart';
import 'package:reflect_os/features/risk/screens/risk_assessment_screen.dart';
import 'package:reflect_os/features/sharing/screens/share_links_screen.dart';
import 'package:reflect_os/features/templates/data/models/decision_template.dart';
import 'package:reflect_os/features/templates/screens/templates_screen.dart';
import 'package:reflect_os/features/team/screens/team_screen.dart';
import 'package:reflect_os/features/toolkit/data/models/tool_definition.dart';
import 'package:reflect_os/features/toolkit/data/models/tool_run.dart';
import 'package:reflect_os/features/toolkit/engine/calculator_engine.dart';
import 'package:reflect_os/features/toolkit/screens/tool_detail_screen.dart';
import 'package:reflect_os/features/toolkit/screens/tool_results_screen.dart';
import 'package:reflect_os/features/toolkit/screens/toolkit_screen.dart';
import 'package:reflect_os/features/demographic_packs/screens/packs_screen.dart';
import 'package:reflect_os/features/settings/screens/encryption_status_screen.dart';
import 'package:reflect_os/features/legal/providers/legal_consent_provider.dart';
import 'package:reflect_os/features/legal/screens/legal_acceptance_screen.dart';
import 'package:reflect_os/features/onboarding/first_run_provider.dart';
import 'package:reflect_os/features/onboarding/first_run_screen.dart';
import 'package:reflect_os/features/workspace/screens/workspace_management_screen.dart';
import 'package:reflect_os/features/workspace/screens/workspace_wizard_screen.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authStateProvider);
  final isAuthenticated = authStatus.valueOrNull is AuthAuthenticated;
  final subscriptionStatus = ref.watch(subscriptionStatusProvider);
  // Treat unknown/loading the same as active — only redirect when confirmed inactive.
  final isSubscribed =
      subscriptionStatus.valueOrNull != SubscriptionStatus.inactive;
  // Treat unknown/loading as accepted — avoids flashing the gate on every cold start.
  final hasAcceptedLegal =
      ref.watch(legalConsentCheckProvider).valueOrNull ?? true;

  return GoRouter(
    initialLocation: Routes.dashboard,
    redirect: (BuildContext context, GoRouterState state) {
      final isPublicRoute = state.matchedLocation.startsWith('/share/') ||
          state.matchedLocation.startsWith('/auth/');

      if (!isAuthenticated && !isPublicRoute) {
        return Routes.login;
      }

      // Legal gate — must be accepted before subscription screen or main app.
      if (isAuthenticated && !hasAcceptedLegal) {
        final isLegalRoute =
            state.matchedLocation == Routes.legalAcceptance;
        if (!isLegalRoute && !isPublicRoute) {
          return Routes.legalAcceptance;
        }
      }

      if (isAuthenticated && hasAcceptedLegal && !isSubscribed) {
        final isBillingRoute = state.matchedLocation.startsWith('/billing/');
        if (!isBillingRoute && !isPublicRoute) {
          return Routes.billingSubscribe;
        }
      }

      // First-run gate — show welcome screen to brand new users.
      if (isAuthenticated && hasAcceptedLegal && isSubscribed) {
        final isFirstRun = ref.read(firstRunProvider);
        final isWelcomeRoute = state.matchedLocation == Routes.welcome;
        if (isFirstRun && !isWelcomeRoute && !isPublicRoute) {
          return Routes.welcome;
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
        builder: (context, state) {
          final extra = state.extra;
          if (extra is DecisionTemplate) {
            return CreateDecisionScreen(initialTemplate: extra);
          } else if (extra is Map<String, dynamic>) {
            return CreateDecisionScreen(meetingCapture: extra);
          }
          return const CreateDecisionScreen();
        },
      ),
      GoRoute(
        path: Routes.decisionsMeetingCapture,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MeetingCaptureScreen(
            mode: extra?['mode'] as String?,
            source: extra?['source'] as String?,
          );
        },
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

      // Search — push above shell (accessed from top bar icon)
      GoRoute(
        path: Routes.search,
        builder: (context, state) => const SearchScreen(),
      ),

      // Settings — push above shell (accessed from top bar icon)
      // Sub-routes remain nested so /settings/privacy etc. continue to work.
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacySettingsScreen(),
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
            builder: (context, state) => const CalendarSettingsScreen(),
          ),
          GoRoute(
            path: 'vertical',
            builder: (context, state) => const VerticalSettingsScreen(),
          ),
          GoRoute(
            path: 'branding',
            builder: (context, state) => const WorkspaceBrandingScreen(),
          ),
          GoRoute(
            path: 'data-privacy',
            builder: (context, state) => const DataPrivacyScreen(),
          ),
          GoRoute(
            path: 'workspaces',
            builder: (context, state) => const WorkspaceManagementScreen(),
          ),
          GoRoute(
            path: 'workspace-wizard',
            builder: (context, state) => const WorkspaceWizardScreen(),
          ),
          GoRoute(
            path: 'encryption-status',
            builder: (context, state) => const EncryptionStatusScreen(),
          ),
        ],
      ),

      // Tool Kit — push above shell
      GoRoute(
        path: Routes.toolkit,
        builder: (context, state) => ToolkitScreen(
          decisionId: state.uri.queryParameters['decisionId'],
        ),
      ),
      // Tool Kit picker — dedicated route for projected outcome selection.
      // Outside the shell so context.push<String> / context.pop(value) works.
      GoRoute(
        path: Routes.toolkitPicker,
        builder: (context, state) => const ToolkitScreen(pickerMode: true),
      ),
      GoRoute(
        path: Routes.toolDetail,
        builder: (context, state) => ToolDetailScreen(
          toolId: state.pathParameters['toolId']!,
          decisionId: state.uri.queryParameters['decisionId'],
          tool: state.extra as ToolDefinition?,
        ),
      ),
      GoRoute(
        path: Routes.toolResults,
        builder: (context, state) {
          final extra = state.extra as ({
            ToolCalculationResult result,
            ToolRun run,
            ToolDefinition tool,
            String? decisionId,
          });
          return ToolResultsScreen(
            result:     extra.result,
            run:        extra.run,
            tool:       extra.tool,
            decisionId: extra.decisionId,
          );
        },
      ),

      // Demographic Packs — push above shell
      GoRoute(
        path: Routes.packs,
        builder: (context, state) => const PacksScreen(),
      ),

      // Bulk import — push above shell
      GoRoute(
        path: Routes.import,
        builder: (context, state) => const ImportScreen(),
      ),

      // Portfolio assets — push above shell
      GoRoute(
        path: Routes.investmentAssets,
        builder: (context, state) => const AssetsScreen(),
      ),

      // Risk assessment — push above shell
      GoRoute(
        path: Routes.decisionRiskAssessment,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final extra = state.extra as RiskAssessment?;
          return RiskAssessmentScreen(decisionId: id, existingAssessment: extra);
        },
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

      // Legal acceptance gate — outside the shell, no back-navigation
      GoRoute(
        path: Routes.legalAcceptance,
        builder: (context, state) => const LegalAcceptanceScreen(),
      ),

      // First-run onboarding — outside the shell
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const FirstRunScreen(),
      ),

      // Billing gate — outside the shell
      GoRoute(path: Routes.billingSubscribe, builder: (context, state) => const BillingSubscribeScreen()),

      // Main app shell — five primary destinations.
      // Branch index maps directly to NavigationBar/NavigationRail tab index.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0 — Home (Dashboard)
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          // 1 — Decisions
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.decisionsList,
              builder: (context, state) => const DecisionsListScreen(),
            ),
          ]),
          // 2 — Initiatives
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.initiativesList,
              builder: (context, state) => const InitiativesListScreen(),
            ),
          ]),
          // 3 — Team
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.team,
              builder: (context, state) => const TeamScreen(),
            ),
          ]),
          // 4 — Coach
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
