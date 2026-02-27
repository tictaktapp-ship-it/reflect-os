import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/calendar/data/calendar_repository.dart';
import 'package:reflect_os/features/calendar/data/models/calendar_connection.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (_) => const CalendarRepository(),
);

final calendarConnectionsProvider =
    FutureProvider.family<List<CalendarConnection>, String>(
        (ref, workspaceId) {
  return ref.read(calendarRepositoryProvider).getConnections(workspaceId);
});

final calendarEventLinksProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, checkpointId) {
  return ref
      .read(calendarRepositoryProvider)
      .getEventLinksForCheckpoint(checkpointId);
});
