import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/settings/data/models/vertical_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VerticalRepository {
  const VerticalRepository();

  static const String _defaultVertical = 'general';

  Future<List<VerticalConfig>> getVerticals() async {
    final rows = await supabase
        .from('vertical_configs')
        .select()
        .order('vertical_name');
    return rows.map((r) => VerticalConfig.fromJson(r)).toList();
  }

  Future<VerticalConfig?> getCurrentVertical(String workspaceId) async {
    final prefs = await SharedPreferences.getInstance();
    final name =
        prefs.getString('vertical_$workspaceId') ?? _defaultVertical;

    final rows = await supabase
        .from('vertical_configs')
        .select()
        .eq('vertical_name', name)
        .limit(1);

    if (rows.isEmpty) return null;
    return VerticalConfig.fromJson(rows.first);
  }

  Future<void> setVertical(String workspaceId, String verticalName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vertical_$workspaceId', verticalName);
  }
}
