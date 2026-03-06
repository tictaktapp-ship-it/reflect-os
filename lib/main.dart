import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/design_system/theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/routing/router.dart';
import 'core/supabase/supabase_client.dart';
import 'core/utils/http_override.dart';
import 'features/calendar/providers/calendar_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }
  await initSupabase();
  runApp(const ProviderScope(child: ReflectApp()));
}

class ReflectApp extends ConsumerStatefulWidget {
  const ReflectApp({super.key});

  @override
  ConsumerState<ReflectApp> createState() => _ReflectAppState();
}

class _ReflectAppState extends ConsumerState<ReflectApp> {
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null && mounted) _handleLink(initial);
      _deepLinkSub = appLinks.uriLinkStream.listen(_handleLink);
    } catch (_) {}
  }

  void _handleLink(Uri uri) {
    if (uri.queryParameters['calendar_oauth'] == 'success') {
      final workspaceId = uri.queryParameters['workspace_id'];
      if (workspaceId != null) {
        ref.invalidate(calendarConnectionsProvider(workspaceId));
      }
    }
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Reflect OS',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
