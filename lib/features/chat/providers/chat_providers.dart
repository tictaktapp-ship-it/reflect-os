import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/chat/data/models/chat_attachment_model.dart';
import 'package:reflect_os/features/chat/data/models/chat_message_model.dart';
import 'package:reflect_os/features/chat/data/models/chat_reaction_model.dart';
import 'package:reflect_os/features/workspace/providers/workspace_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Workspace type helper ──────────────────────────────────────────────────────

final currentWorkspaceTypeProvider = FutureProvider<String?>((ref) async {
  final workspaceId = await ref.watch(currentWorkspaceProvider.future);
  if (workspaceId == null) return null;
  final workspaces = await ref.watch(userWorkspacesProvider.future);
  try {
    return workspaces.firstWhere((w) => w.id == workspaceId).workspaceType;
  } catch (_) {
    return null;
  }
});

// ── Messages notifier ──────────────────────────────────────────────────────────

class ChatMessagesNotifier
    extends StateNotifier<AsyncValue<List<ChatMessageModel>>> {
  ChatMessagesNotifier(this._workspaceId)
      : super(const AsyncValue.loading()) {
    _load();
    _subscribe();
  }

  final String _workspaceId;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    try {
      final rows = await supabase
          .from('chat_messages')
          .select('*, profiles(display_name, avatar_url), chat_attachments(*)')
          .eq('workspace_id', _workspaceId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(50);

      final messages = (rows as List)
          .map((r) => ChatMessageModel.fromJson(r as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();

      // Load reactions for these messages
      if (messages.isNotEmpty) {
        final ids = messages.map((m) => m.id).toList();
        final reactionRows = await supabase
            .from('chat_reactions')
            .select()
            .inFilter('message_id', ids);

        final reactionsByMsg = <String, List<ChatReactionModel>>{};
        for (final r in reactionRows as List) {
          final reaction =
              ChatReactionModel.fromJson(r as Map<String, dynamic>);
          reactionsByMsg
              .putIfAbsent(reaction.messageId, () => [])
              .add(reaction);
        }

        final withReactions = messages
            .map((m) =>
                m.copyWith(reactions: reactionsByMsg[m.id] ?? const []))
            .toList();
        if (mounted) state = AsyncValue.data(withReactions);
      } else {
        if (mounted) state = const AsyncValue.data([]);
      }
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  void _subscribe() {
    _channel = supabase
        .channel('chat_msgs:$_workspaceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workspace_id',
            value: _workspaceId,
          ),
          callback: _onMessageInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'workspace_id',
            value: _workspaceId,
          ),
          callback: _onMessageUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_reactions',
          callback: _onReactionChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'chat_reactions',
          callback: _onReactionChange,
        )
        .subscribe();
  }

  Future<void> _onMessageInsert(PostgresChangePayload payload) async {
    final msgId = payload.newRecord['id'] as String?;
    if (msgId == null) return;

    try {
      final rows = await supabase
          .from('chat_messages')
          .select('*, profiles(display_name, avatar_url), chat_attachments(*)')
          .eq('id', msgId)
          .limit(1);

      if (rows.isEmpty) return;
      var msg = ChatMessageModel.fromJson(rows.first);

      // Attachment rows may not yet be visible via join; fetch separately.
      if (msg.hasAttachment && msg.attachments.isEmpty) {
        try {
          final attachRows = await supabase
              .from('chat_attachments')
              .select()
              .eq('message_id', msg.id);
          final attachments = (attachRows as List)
              .map((a) =>
                  ChatAttachmentModel.fromJson(a as Map<String, dynamic>))
              .toList();
          msg = msg.copyWith(attachments: attachments);
        } catch (_) {}
      }

      final current = state.valueOrNull ?? [];
      if (mounted) state = AsyncValue.data([...current, msg]);

      // Record delivery for messages from others
      final userId = supabase.auth.currentUser?.id;
      if (userId != null && msg.senderUserId != userId) {
        supabase.from('chat_deliveries').upsert({
          'message_id': msg.id,
          'user_id': userId,
        }, onConflict: 'message_id,user_id').catchError((_) {});
      }
    } catch (_) {}
  }

  void _onMessageUpdate(PostgresChangePayload payload) {
    final id = payload.newRecord['id'] as String?;
    if (id == null) return;

    final current = state.valueOrNull;
    if (current == null) return;

    final updated = current.map((m) {
      if (m.id != id) return m;
      final deletedAtRaw = payload.newRecord['deleted_at'];
      final editedAtRaw = payload.newRecord['edited_at'];
      return m.copyWith(
        content: payload.newRecord['content'] as String? ?? m.content,
        editedAt: editedAtRaw == null
            ? m.editedAt
            : DateTime.parse(editedAtRaw as String).toLocal(),
        deletedAt: deletedAtRaw == null
            ? m.deletedAt
            : DateTime.parse(deletedAtRaw as String).toLocal(),
      );
    }).toList();

    if (mounted) state = AsyncValue.data(updated);
  }

  Future<void> _onReactionChange(PostgresChangePayload payload) async {
    final messageId = (payload.newRecord['message_id'] ??
        payload.oldRecord['message_id']) as String?;
    if (messageId == null) return;

    try {
      final rows = await supabase
          .from('chat_reactions')
          .select()
          .eq('message_id', messageId);

      final reactions = (rows as List)
          .map((r) => ChatReactionModel.fromJson(r as Map<String, dynamic>))
          .toList();

      final current = state.valueOrNull;
      if (current == null) return;

      final updated = current.map((m) {
        if (m.id != messageId) return m;
        return m.copyWith(reactions: reactions);
      }).toList();

      if (mounted) state = AsyncValue.data(updated);
    } catch (_) {}
  }

  Future<void> sendMessage({
    required String content,
    String? replyToMessageId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('chat_messages').insert({
      'workspace_id': _workspaceId,
      'sender_user_id': userId,
      'content': content.trim(),
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
    });
  }

  Future<void> editMessage(String messageId, String content) async {
    await supabase.from('chat_messages').update({
      'content': content.trim(),
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await supabase.from('chat_messages').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', messageId);
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await supabase
        .from('chat_reactions')
        .select()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji)
        .maybeSingle();

    if (existing != null) {
      await supabase
          .from('chat_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);
    } else {
      await supabase.from('chat_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier,
    AsyncValue<List<ChatMessageModel>>, String>(
  (ref, workspaceId) => ChatMessagesNotifier(workspaceId),
);

// ── Last-read provider ─────────────────────────────────────────────────────────

final chatMyLastReadAtProvider =
    FutureProvider.family<DateTime?, String>((ref, workspaceId) async {
  final authStatus = ref.watch(authStateProvider).valueOrNull;
  final userId =
      authStatus is AuthAuthenticated ? authStatus.session.user.id : null;
  if (userId == null) return null;

  final row = await supabase
      .from('chat_read_receipts')
      .select('last_read_at')
      .eq('workspace_id', workspaceId)
      .eq('user_id', userId)
      .maybeSingle();

  if (row == null) return null;
  return DateTime.parse(row['last_read_at'] as String).toLocal();
});

// ── Unread count ───────────────────────────────────────────────────────────────

final chatUnreadCountProvider = Provider.family<int, String>((ref, workspaceId) {
  final messages =
      ref.watch(chatMessagesProvider(workspaceId)).valueOrNull ?? [];
  final lastReadAt =
      ref.watch(chatMyLastReadAtProvider(workspaceId)).valueOrNull;
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return 0;

  return messages
      .where((m) =>
          !m.isDeleted &&
          m.senderUserId != userId &&
          (lastReadAt == null || m.createdAt.isAfter(lastReadAt)))
      .length;
});

// ── Online presence ────────────────────────────────────────────────────────────

class ChatPresenceNotifier extends StateNotifier<Set<String>> {
  ChatPresenceNotifier(this._workspaceId, this._currentUserId)
      : super(const {}) {
    _subscribe();
  }

  final String _workspaceId;
  final String _currentUserId;
  RealtimeChannel? _channel;

  void _subscribe() {
    final ch = supabase.channel('chat_presence:$_workspaceId');
    _channel = ch
        .onPresenceSync((_) => _updatePresence())
        .onPresenceJoin((_) => _updatePresence())
        .onPresenceLeave((_) => _updatePresence())
        .subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track({
          'user_id': _currentUserId,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });
  }

  void _updatePresence() {
    final presenceList = _channel?.presenceState();
    if (presenceList == null) return;
    final onlineIds = presenceList
        .expand((s) => s.presences)
        .map((p) => p.payload['user_id'] as String?)
        .whereType<String>()
        .toSet();
    if (mounted) state = onlineIds;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final chatOnlinePresenceProvider = StateNotifierProvider.family<
    ChatPresenceNotifier, Set<String>, String>(
  (ref, workspaceId) {
    final userId = supabase.auth.currentUser?.id ?? '';
    return ChatPresenceNotifier(workspaceId, userId);
  },
);
