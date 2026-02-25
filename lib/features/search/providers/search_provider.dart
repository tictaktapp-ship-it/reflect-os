import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/search/data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => const SearchRepository(),
);

/// Holds the current search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Fires the search_decisions RPC when the query is 2+ characters.
/// Returns an empty list for short/empty queries without hitting the network.
final searchResultsProvider = FutureProvider<List<Decision>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return [];
  return ref.read(searchRepositoryProvider).searchDecisions(query);
});
