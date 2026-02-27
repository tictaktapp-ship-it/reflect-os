abstract final class Routes {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';

  // Home
  static const String home = '/home';

  // Dashboard (shell tab)
  static const String dashboard = '/dashboard';

  // Decisions
  static const String decisionsList = '/decisions/list';
  static const String decisionsDetail = '/decisions/detail/:id';
  static const String decisionsCreate = '/decisions/create';
  static const String decisionsEdit = '/decisions/edit/:id';

  // Outcomes
  static const String outcomesCreate = '/outcomes/create/:decisionId';

  // Search
  static const String search = '/search';

  // Notifications
  static const String notifications = '/notifications';

  // Initiatives
  static const String initiativesList = '/initiatives/list';
  static const String initiativesDetail = '/initiatives/detail/:id';
  static const String initiativesCreate = '/initiatives/create';

  // Team
  static const String team = '/team';

  // Settings
  static const String settings = '/settings';
  static const String settingsPrivacy = '/settings/privacy';

  // Billing
  static const String billingSubscribe = '/billing/subscribe';
  static const String settingsBilling = '/settings/billing';
  static const String settingsAuditLog = '/settings/audit-log';
  static const String settingsTemplates = '/settings/templates';

  // Import
  static const String import = '/import';

  // Calendar
  static const String settingsCalendar = '/settings/calendar';

  // Share links management (authenticated)
  static const String decisionsShareLinks = '/decisions/:id/share-links';

  // Share
  // Must work without authentication — this is the public share link entry point.
  static const String share = '/share/:token';
}
