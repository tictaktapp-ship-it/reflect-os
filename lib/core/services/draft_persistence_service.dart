import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';

class DraftPersistenceService {
  static const _prefix = 'draft_';

  Future<void> saveDraft(Decision decision) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix${decision.id}', jsonEncode(decision.toJson()));
  }

  Future<Decision?> loadDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$id');
    if (raw == null) return null;
    return Decision.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<List<Decision>> loadAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    final drafts = <Decision>[];
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        drafts.add(
            Decision.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Skip corrupted entries silently.
      }
    }
    return drafts;
  }

  Future<void> deleteDraft(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$id');
  }
}
