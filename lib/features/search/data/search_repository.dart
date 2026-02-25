import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';

class SearchRepository {
  const SearchRepository();

  /// Calls the search_decisions RPC. Returns decisions whose title or
  /// description match the query. Results are mapped to the Decision model
  /// since the RPC returns the same shape as user_visible_decisions.
  Future<List<Decision>> searchDecisions(String query) async {
    final rows = await supabase.rpc(
      'search_decisions',
      params: {'p_query': query},
    ) as List<dynamic>;

    return rows
        .map((row) => Decision.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
