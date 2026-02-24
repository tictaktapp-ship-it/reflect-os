# Reflect OS — Claude Code Context

## What this project is
Flutter app (Web + Android + iOS v1.0 / Windows + macOS v1.1).
Decision logging and reflection platform for executives and investment managers.
Supabase backend: PostgreSQL, Auth, Storage, Edge Functions, Realtime.

## Phase status
- Phase 1 (Product Spec): COMPLETE & LOCKED
- Phase 2 (Logical Data Model): COMPLETE & LOCKED
- Phase 3 (SQL Schema + Migrations 0001-0014): COMPLETE & LOCKED
- Phase 4 (Flutter Implementation): IN PROGRESS

## Non-negotiable rules
- NEVER query raw Supabase tables directly from Flutter.
  All reads go through canonical views (user_visible_*) or named RPCs.
- NEVER write or suggest SQL migrations. All schema changes go through Supabase Dashboard SQL Editor only.
- NEVER commit secrets, API keys, .env files, or google-services.json.
- NEVER use `flutter run` without `--release` unless explicitly told to.
- NEVER use `git add .` — always stage specific file paths only.
- NEVER assume the contents of a file. Read it first, then propose changes.
- NEVER invent route names, provider names, or table names. Check routes.dart / the schema first.

## Architecture decisions (locked)
- State management: Riverpod only. No other state management.
- Routing: go_router only. Route names follow /[feature]/[screen] convention.
- Folder structure: feature-first. lib/core/ for global concerns, lib/features/<name>/ per feature.
- Workspace context: single currentWorkspaceProvider in lib/core/providers/. Never hardcode a workspace ID.
- Subscription gate: subscriptionStatusProvider in lib/core/providers/. Gate enforced at routing level.

## Folder structure
lib/
  core/
    providers/       # authStateProvider, currentWorkspaceProvider, subscriptionStatusProvider
    routing/         # go_router config, route names, deep link patterns
    supabase/        # Supabase client init, env config
    design_system/   # tokens, theme, components
    utils/
  features/
    auth/
    decisions/
    outcomes/
    search/
    notifications/
    team/
    coaching/
    billing/
    export/
    import/
    settings/
    dashboard/
    initiatives/
    templates/
    calendar/
    vertical_config/
  main.dart

## Deep link patterns (locked - do not change)
- Calendar checkpoint: /decisions/detail/:id?checkpoint=:checkpointId
- Share link entry: /share/:token
- These must work through the subscription gate.

## Supabase project
- Project: reflect_os (eu-west-1)
- Migrations 0001-0014 applied and locked. Do not suggest schema changes.
- Key views: user_visible_decisions (and other user_visible_* views)
- Key RPCs: search_decisions, anonymise_user, save_outcome_update (and others from migration 0005)
- analytics_summary: precomputed. Never aggregate in Flutter.
- notification_queue: single source of truth for all notifications.

## Verification steps (run BEFORE proposing any implementation)
1. git status
2. flutter analyze
3. flutter test
4. Read each file you plan to edit before proposing changes.

## Commit discipline
- One logical change per commit.
- Stage specific paths only: git add lib/features/auth/repository/auth_repository.dart
- Never: git add .
- Commit format: feat(scope): description | fix(scope): description | refactor(scope): description
- Examples:
  feat(auth): add sign-in form validation
  fix(decisions): correct Draft lifecycle state transition
  refactor(routing): extract deep link handlers to separate file

## Key reference documents (read these before making decisions)
- Phase 1 product spec: https://www.notion.so/30ba15955ae6815886f8e6f2f43aa094
- Phase 3 schema: https://www.notion.so/30ba15955ae681ad9979f5bf50c71f55
- Screen inventory: https://www.notion.so/0e59e85d4cef4d1fac03530627dd0ca4
- Coding standards: https://www.notion.so/2d6596443b4c4ce3b762ffb91a99d2fc
- Phase 4 plan: https://www.notion.so/30ba15955ae681509268eac3a618a241
