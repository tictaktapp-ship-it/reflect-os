import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/services/draft_persistence_service.dart';

final draftPersistenceServiceProvider = Provider<DraftPersistenceService>(
  (_) => DraftPersistenceService(),
);
