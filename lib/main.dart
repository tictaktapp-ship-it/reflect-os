import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/design_system/theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/routing/router.dart';
import 'core/supabase/supabase_client.dart';
import 'core/utils/http_override.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }
  await initSupabase();
  runApp(const ProviderScope(child: ReflectApp()));
}

class ReflectApp extends ConsumerWidget {
  const ReflectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
