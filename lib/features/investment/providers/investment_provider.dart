import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/features/investment/data/investment_repository.dart';
import 'package:reflect_os/features/investment/data/models/asset.dart';
import 'package:reflect_os/features/investment/data/models/ic_vote.dart';

final investmentRepositoryProvider = Provider<InvestmentRepository>(
  (_) => const InvestmentRepository(),
);

/// All assets for the current workspace, sorted by name.
final workspaceAssetsProvider = FutureProvider<List<Asset>>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return [];
  return ref
      .read(investmentRepositoryProvider)
      .getAssetsForWorkspace(workspaceId);
});

/// Assets linked to a specific decision.
final linkedAssetsProvider =
    FutureProvider.family<List<Asset>, String>((ref, decisionId) {
  return ref.read(investmentRepositoryProvider).getLinkedAssets(decisionId);
});

/// IC votes cast on a specific decision.
final icVotesForDecisionProvider =
    FutureProvider.family<List<IcVote>, String>((ref, decisionId) {
  return ref
      .read(investmentRepositoryProvider)
      .getVotesForDecision(decisionId);
});
