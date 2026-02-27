import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/debrief/data/debrief_repository.dart';
import 'package:reflect_os/features/debrief/data/models/decision_debrief.dart';

final debriefRepositoryProvider = Provider<DebriefRepository>(
  (ref) => const DebriefRepository(),
);

final debriefProvider =
    FutureProvider.family<DecisionDebrief?, String>((ref, decisionId) {
  return ref.read(debriefRepositoryProvider).getLatestDebrief(decisionId);
});
