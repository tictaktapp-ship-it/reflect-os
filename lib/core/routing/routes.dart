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
  static const String decisionsMeetingCapture = '/decisions/meeting-capture';

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
  static const String settingsDataPrivacy = '/settings/data-privacy';

  // Billing
  static const String billingSubscribe = '/billing/subscribe';
  static const String settingsBilling = '/settings/billing';
  static const String settingsAuditLog = '/settings/audit-log';
  static const String settingsTemplates = '/settings/templates';

  // Import
  static const String import = '/import';

  // Calendar
  static const String settingsCalendar = '/settings/calendar';

  // Vertical
  static const String settingsVertical = '/settings/vertical';

  // Branding
  static const String settingsBranding = '/settings/branding';

  // Workspace management
  static const String settingsWorkspaces = '/settings/workspaces';

  // Workspace setup wizard
  static const String workspaceWizard = '/settings/workspace-wizard';

  // Encryption status
  static const String encryptionStatus = '/settings/encryption-status';

  // Coaching
  static const String coachingDashboard = '/coaching/dashboard';

  // Investment / Portfolio
  static const String investmentAssets = '/investment/assets';

  // Share links management (authenticated)
  static const String decisionsShareLinks = '/decisions/:id/share-links';

  // Tool Kit
  static const String toolkit = '/toolkit';
  static const String toolkitPicker = '/toolkit-picker';
  static const String toolDetail = '/toolkit/:toolId';
  static const String toolResults = '/toolkit/:toolId/results';

  // Demographic Packs
  static const String packs = '/packs';

  // Share
  // Must work without authentication — this is the public share link entry point.
  static const String share = '/share/:token';
}
