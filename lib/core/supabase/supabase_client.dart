import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> initSupabase() async {
  assert(_supabaseUrl.isNotEmpty, 'SUPABASE_URL is not defined. Pass --dart-define=SUPABASE_URL=<value>');
  assert(_supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY is not defined. Pass --dart-define=SUPABASE_ANON_KEY=<value>');

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;
