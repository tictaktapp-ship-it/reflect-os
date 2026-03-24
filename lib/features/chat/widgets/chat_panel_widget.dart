import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/chat/data/models/chat_message_model.dart';
import 'package:reflect_os/features/chat/providers/chat_providers.dart';
import 'package:reflect_os/features/chat/widgets/chat_message_bubble.dart';
import 'package:reflect_os/features/chat/widgets/emoji_picker_sheet.dart';
import 'package:reflect_os/features/chat/widgets/online_members_sheet.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:reflect_os/features/team/data/team_repository.dart';

class ChatPanelWidget extends ConsumerStatefulWidget {
  const ChatPanelWidget({
    super.key,
    required this.workspaceId,
    required this.onClose,
  });

  final String workspaceId;
  final VoidCallback onClose;

  @override
  ConsumerState<ChatPanelWidget> createState() => _ChatPanelWidgetState();
}

class _ChatPanelWidgetState extends ConsumerState<ChatPanelWidget> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  ChatMessageModel? _replyingTo;
  String? _editingMessageId;
  bool _canSend = false;

  int _memberCount = 0;
  List<WorkspaceMembership> _members = [];
  Map<String, int> _deliveryCountByMsg = {};
  Map<String, DateTime> _readReceiptsByUser = {}; // userId → lastReadAt

  Timer? _readReceiptTimer;

  static final _dateFmt = DateFormat('MMMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final canSend = _textController.text.trim().isNotEmpty;
      if (canSend != _canSend) setState(() => _canSend = canSend);
    });
    _loadMetadata();
    _updateReadReceipt();
    _readReceiptTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateReadReceipt(),
    );
  }

  @override
  void dispose() {
    _readReceiptTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final repo = const TeamRepository();
      final memberships =
          await repo.getWorkspaceMemberships(widget.workspaceId);
      if (!mounted) return;
      setState(() {
        _members = memberships;
        _memberCount = memberships.length;
      });
      await _loadDeliveryAndReadData();
    } catch (_) {}
  }

  Future<void> _loadDeliveryAndReadData() async {
    try {
      final msgs =
          ref.read(chatMessagesProvider(widget.workspaceId)).valueOrNull;
      if (msgs == null || msgs.isEmpty) return;

      final msgIds = msgs.map((m) => m.id).toList();

      // Delivery counts
      final deliveries = await supabase
          .from('chat_deliveries')
          .select('message_id')
          .inFilter('message_id', msgIds);

      final counts = <String, int>{};
      for (final d in deliveries as List) {
        final mid = d['message_id'] as String;
        counts[mid] = (counts[mid] ?? 0) + 1;
      }

      // Read receipts
      final receipts = await supabase
          .from('chat_read_receipts')
          .select('user_id, last_read_at')
          .eq('workspace_id', widget.workspaceId);

      final readMap = <String, DateTime>{};
      for (final r in receipts as List) {
        readMap[r['user_id'] as String] =
            DateTime.parse(r['last_read_at'] as String).toLocal();
      }

      if (!mounted) return;
      setState(() {
        _deliveryCountByMsg = counts;
        _readReceiptsByUser = readMap;
      });
    } catch (_) {}
  }

  Future<void> _updateReadReceipt() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final msgs =
        ref.read(chatMessagesProvider(widget.workspaceId)).valueOrNull;
    if (msgs == null || msgs.isEmpty) return;

    final latestId = msgs.last.id;
    try {
      await supabase.from('chat_read_receipts').upsert({
        'workspace_id': widget.workspaceId,
        'user_id': userId,
        'last_read_message_id': latestId,
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'workspace_id,user_id');

      ref.invalidate(chatMyLastReadAtProvider(widget.workspaceId));
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final replyId = _replyingTo?.id;
    final editId = _editingMessageId;

    _textController.clear();
    setState(() {
      _replyingTo = null;
      _editingMessageId = null;
    });

    final notifier =
        ref.read(chatMessagesProvider(widget.workspaceId).notifier);
    if (editId != null) {
      await notifier.editMessage(editId, text);
    } else {
      await notifier.sendMessage(
          content: text, replyToMessageId: replyId);
    }
    _updateReadReceipt();
    _scrollToBottom();
  }

  MessageDeliveryStatus _computeStatus(ChatMessageModel msg) {
    if (_memberCount <= 1) return MessageDeliveryStatus.read;
    final others = _memberCount - 1;

    final currentUserId = supabase.auth.currentUser?.id;
    int readCount = 0;
    for (final entry in _readReceiptsByUser.entries) {
      if (entry.key == currentUserId) continue;
      if (!entry.value.isBefore(msg.createdAt)) readCount++;
    }
    if (readCount >= others) return MessageDeliveryStatus.read;

    final deliveryCount = _deliveryCountByMsg[msg.id] ?? 0;
    if (deliveryCount >= others) return MessageDeliveryStatus.delivered;

    return MessageDeliveryStatus.sent;
  }

  @override
  Widget build(BuildContext context) {
    return _buildPanel(context);
  }

  Widget _buildPanel(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF19CBD6), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildMessageList(context)),
              _buildReplyBanner(),
              _buildInputRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF19CBD6),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.chat_bubble, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Team Chat',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.people_outline,
                color: Colors.white, size: 20),
            tooltip: 'Members',
            onPressed: () => showOnlineMembersSheet(
              context,
              workspaceId: widget.workspaceId,
              members: _members,
              ref: ref,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.workspaceId));
    final currentUserId = supabase.auth.currentUser?.id ?? '';

    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Failed to load messages',
            style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (messages) {
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet.\nSay hello to your team!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          );
        }

        // Build items with date separators
        final items = <_ChatListItem>[];
        for (int i = 0; i < messages.length; i++) {
          final msg = messages[i];
          if (i == 0 ||
              !_sameDay(messages[i - 1].createdAt, msg.createdAt)) {
            items.add(_ChatListItem.dateSeparator(msg.createdAt));
          }
          items.add(_ChatListItem.message(msg));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification &&
                _scrollController.position.atEdge &&
                _scrollController.position.pixels > 0) {
              _updateReadReceipt();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isSeparator) {
                return _buildDateSeparator(item.date!);
              }
              final msg = item.message!;
              final isMine = msg.senderUserId == currentUserId;
              final replyTo = msg.replyToMessageId != null
                  ? messages.where(
                      (m) => m.id == msg.replyToMessageId).firstOrNull
                  : null;

              return ChatMessageBubble(
                key: ValueKey(msg.id),
                message: msg,
                isMine: isMine,
                currentUserId: currentUserId,
                replyToMessage: replyTo,
                deliveryStatus:
                    isMine ? _computeStatus(msg) : MessageDeliveryStatus.sent,
                onReply: () => setState(() => _replyingTo = msg),
                onReact: (emoji) => ref
                    .read(chatMessagesProvider(widget.workspaceId).notifier)
                    .toggleReaction(msg.id, emoji),
                onEdit: isMine
                    ? () {
                        _textController.text = msg.content;
                        setState(() {
                          _editingMessageId = msg.id;
                          _replyingTo = null;
                        });
                      }
                    : null,
                onDelete: () => ref
                    .read(chatMessagesProvider(widget.workspaceId).notifier)
                    .deleteMessage(msg.id),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _dateFmt.format(date),
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _buildReplyBanner() {
    final editId = _editingMessageId;
    final replyTo = _replyingTo;
    if (editId == null && replyTo == null) return const SizedBox.shrink();

    final label = editId != null ? 'Editing message' : 'Replying to ${replyTo!.senderName ?? 'message'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFF0FAFA),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Color(0xFF19CBD6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF19CBD6)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _replyingTo = null;
              _editingMessageId = null;
              if (_editingMessageId != null) _textController.clear();
            }),
            child: const Icon(Icons.close, size: 16,
                color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(BuildContext context) {
    final hintText = _replyingTo != null
        ? 'Replying to ${_replyingTo!.senderName ?? 'message'}...'
        : _editingMessageId != null
            ? 'Edit message...'
            : 'Message team...';

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.emoji_emotions_outlined,
                color: Color(0xFF19CBD6)),
            onPressed: () => showEmojiPickerSheet(
              context,
              onEmojiSelected: (emoji) {
                final text = _textController.text;
                final sel = _textController.selection;
                final newText =
                    text.replaceRange(sel.start, sel.end, emoji);
                _textController.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                      offset: sel.start + emoji.length),
                );
              },
            ),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                    fontSize: 13, color: Color(0xFF9CA3AF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFF19CBD6)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: _canSend
                  ? const Color(0xFF19CBD6)
                  : const Color(0xFFD1D5DB),
            ),
            onPressed: _canSend ? _sendMessage : null,
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── List item helper ───────────────────────────────────────────────────────────

class _ChatListItem {
  const _ChatListItem._({this.message, this.date});

  final ChatMessageModel? message;
  final DateTime? date;

  bool get isSeparator => date != null;

  factory _ChatListItem.message(ChatMessageModel m) =>
      _ChatListItem._(message: m);

  factory _ChatListItem.dateSeparator(DateTime d) =>
      _ChatListItem._(date: d);
}
