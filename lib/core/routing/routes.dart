abstract final class Routes {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';

  // Home
  static const String home = '/home';

  // Decisions
  static const String decisionsList = '/decisions/list';
  static const String decisionsDetail = '/decisions/detail/:id';
  static const String decisionsCreate = '/decisions/create';

  // Outcomes
  static const String outcomesCreate = '/outcomes/create/:decisionId';

  // Search
  static const String search = '/search';

  // Settings
  static const String settings = '/settings';
  static const String settingsPrivacy = '/settings/privacy';

  // Share
  // Must work without authentication — this is the public share link entry point.
  static const String share = '/share/:token';
}
