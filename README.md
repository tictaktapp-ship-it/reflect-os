# Reflect OS

Flutter application — decision logging and reflection platform.

## Platforms
v1.0: Web (Chrome/Edge), Android, iOS
v1.1: Windows, macOS

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
