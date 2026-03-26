import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/evidence/data/evidence_repository.dart';
import 'package:reflect_os/features/evidence/data/models/evidence_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final evidenceRepositoryProvider = Provider<EvidenceRepository>(
  (ref) => const EvidenceRepository(),
);

class EvidenceNotifier
    extends FamilyAsyncNotifier<List<EvidenceItem>, String> {
  RealtimeChannel? _channel;

  @override
  Future<List<EvidenceItem>> build(String decisionId) async {
    final items = await ref
        .read(evidenceRepositoryProvider)
        .getEvidenceForDecision(decisionId);

    // Subscribe to Realtime inserts so the UI updates without a full reload.
    _channel?.unsubscribe();
    _channel = supabase
        .channel('evidence:$decisionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'evidence_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'decision_id',
            value: decisionId,
          ),
          callback: (payload) {
            final current = state.valueOrNull;
            if (current != null) {
              final newItem = EvidenceItem.fromJson(
                  Map<String, dynamic>.from(payload.newRecord));
              state = AsyncData([...current, newItem]);
            }
          },
        )
        .subscribe();

    ref.onDispose(() => _channel?.unsubscribe());

    return items;
  }
}

final evidenceProvider = AsyncNotifierProvider.family<EvidenceNotifier,
    List<EvidenceItem>, String>(
  EvidenceNotifier.new,
);
