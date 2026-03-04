/// Central store for Supabase table names, view names, and RPC identifiers.
/// Use these constants instead of hard-coded strings in repositories.
abstract final class SupabaseTables {
  static const String toolDefinitions = 'tool_definitions';
  static const String demographicPacks = 'demographic_packs';
  static const String workspaceSettings = 'workspace_settings';
}

abstract final class SupabaseViews {
  static const String toolDefinitions = 'user_visible_tool_definitions';
  static const String toolRuns = 'user_visible_tool_runs';
  static const String demographicPacks = 'user_visible_demographic_packs';
  static const String workspaceToolRuns = 'v_workspace_tool_runs';
  static const String workspaceDemographicPacks = 'v_workspace_demographic_packs';
}

abstract final class SupabaseRpcs {
  static const String runTool = 'run_tool';
  static const String approveAndInjectToolOutput =
      'approve_and_inject_tool_output';
  static const String setWorkspaceDefaultPack = 'set_workspace_default_pack';
  static const String setWorkspaceDefaultDemographicPack =
      'set_workspace_default_demographic_pack';
  static const String setWorkspaceEncryptionMode =
      'set_workspace_encryption_mode';
}
