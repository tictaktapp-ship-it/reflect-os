# Reflect OS

Flutter application — decision logging and reflection platform.

## Platforms
v1.0: Web (Chrome/Edge), Android, iOS
v1.1: Windows, macOS

## Environment variables

Supabase credentials are injected at build time via `--dart-define`. Never commit real values.

```
flutter run -d chrome --release \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

Or use a `dart_defines.json` file (also gitignored) with `--dart-define-from-file=dart_defines.json`.
See `.env.example` for required variable names.

## Running the app

Always run in release mode:
```
flutter run -d chrome --release
flutter run -d <android-device-id> --release
```

## Testing
```
flutter analyze
flutter test
```

## Rules
- Never query raw Supabase tables. Use views and RPCs only.
- Never commit secrets or .env files.
- See CLAUDE.md for full project rules used with Claude Code.

## Flutter version
[Record pinned version here after running: flutter --version]
