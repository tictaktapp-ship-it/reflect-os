import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/widgets/reflect_logo.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/features/settings/providers/profile_provider.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

/// Brand app bar used by every screen in Reflect OS.
///
/// Dashboard mode (no title / centreContent):
///   Left  : logo
///   Centre: WorkspaceSwitcherChip + search bar
///   Right : screen-specific [actions] + user avatar
///
/// Sub-screen mode (title or centreContent provided):
///   Left  : [← back?] + logo
///   Centre: [centreContent] or title Text
///   Right : screen-specific [actions] + user avatar
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.centreContent,
    this.title,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = false,
    this.leading,
  });

  final Widget? centreContent;
  final String? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Widget? leading;

  bool get _isDashboardMode => title == null && centreContent == null;

  @override
  Size get preferredSize =>
      Size.fromHeight(60 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = automaticallyImplyLeading && Navigator.of(context).canPop();

    Widget leadingWidget;
    double leadingWidth;
    bool centreTitle;

    if (leading != null) {
      leadingWidget = leading!;
      leadingWidth = canPop ? 140 : 180;
      centreTitle = true;
    } else if (_isDashboardMode) {
      // Dashboard mode: workspace selector as leading, search fills title
      leadingWidget = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: WorkspaceSwitcherChip(),
      );
      leadingWidth = 220;
      centreTitle = false;
    } else {
      // Sub-screen: optional back arrow + logo
      leadingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPop)
            IconButton(
              icon: Icon(Icons.arrow_back, color: context.cs.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.only(left: 8),
            ),
          Padding(
            padding: EdgeInsets.only(left: canPop ? 0 : 16),
            child: const ReflectLogo(iconSize: 28),
          ),
        ],
      );
      leadingWidth = canPop ? 140 : 180;
      centreTitle = true;
    }

    final Widget centre;
    if (centreContent != null) {
      centre = centreContent!;
    } else if (title != null) {
      centre = Text(
        title!,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: context.cs.textPrimary,
        ),
      );
    } else {
      // Dashboard mode: search bar fills the title area
      centre = const _HeaderSearchBar();
    }

    final rightActions = [
      ...?actions,
      const _UserAvatarButton(),
      const SizedBox(width: 8),
    ];

    final cs = context.cs;
    return AppBar(
      backgroundColor: cs.backgroundSecondary,
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 60,
      automaticallyImplyLeading: false,
      leading: leadingWidget,
      leadingWidth: leadingWidth,
      title: centre,
      centerTitle: centreTitle,
      titleSpacing: _isDashboardMode ? 8 : NavigationToolbar.kMiddleSpacing,
      actions: rightActions,
      bottom: bottom,
      shape: Border(
        bottom: BorderSide(color: cs.borderDefault),
      ),
    );
  }
}

// ── Global header search bar ──────────────────────────────────────────────────

typedef _DecisionHit = ({String id, String title, String state});

class _HeaderSearchBar extends ConsumerStatefulWidget {
  const _HeaderSearchBar();

  @override
  ConsumerState<_HeaderSearchBar> createState() => _HeaderSearchBarState();
}

class _HeaderSearchBarState extends ConsumerState<_HeaderSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlay;
  Timer? _debounce;

  List<_DecisionHit> _decisions = [];
  List<WorkspaceMembership> _members = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _dismissOverlay();
          node.unfocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  // ── Query ──────────────────────────────────────────────────────────────────

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      _decisions = [];
      _members = [];
      _removeOverlay();
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    if (workspaceId == null || !mounted) return;

    setState(() => _loading = true);
    try {
      // ── Decisions (full-text prefix search via tsvector) ──────────────────
      final tsQuery = query
          .trim()
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => '$w:*')
          .join(' & ');
      final decRows = await supabase
          .from('decisions')
          .select('id, title, state')
          .eq('workspace_id', workspaceId)
          .isFilter('deleted_at', null)
          .textSearch('search_vector', tsQuery)
          .limit(6);

      // ── Members (memberships + profile names) ─────────────────────────────
      final memberRows = await supabase
          .from('user_visible_workspace_memberships')
          .select('*')
          .eq('workspace_id', workspaceId);

      List<WorkspaceMembership> members = [];
      if (memberRows.isNotEmpty) {
        final userIds =
            memberRows.map((r) => r['user_id'] as String).toList();
        final profileRows = await supabase
            .from('profiles')
            .select('user_id, display_name, avatar_url')
            .inFilter('user_id', userIds)
            .ilike('display_name', '%$query%')
            .limit(5);
        final profileMap = {
          for (final p in profileRows) p['user_id'] as String: p,
        };
        members = memberRows
            .where((r) => profileMap.containsKey(r['user_id'] as String))
            .map((r) => WorkspaceMembership.fromJson({
                  ...r,
                  'display_name':
                      profileMap[r['user_id'] as String]?['display_name'],
                  'avatar_url':
                      profileMap[r['user_id'] as String]?['avatar_url'],
                }))
            .toList();
      }

      if (!mounted) return;
      _decisions = decRows
          .map((r) => (
                id: r['id'] as String,
                title: r['title'] as String? ?? '',
                state: r['state'] as String? ?? '',
              ))
          .toList();
      _members = members;

      _showOverlay();
    } catch (e, st) {
      debugPrint('[Search] error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Overlay ────────────────────────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    if (!mounted) return;
    if (_decisions.isEmpty && _members.isEmpty) return;

    _overlay = OverlayEntry(
      builder: (_) => _SearchOverlayPanel(
        layerLink: _layerLink,
        decisions: _decisions,
        members: _members,
        onDismiss: _dismissOverlay,
        onDecisionTap: (id) {
          _dismissOverlay();
          _controller.clear();
          _focusNode.unfocus();
          context.push('/decisions/detail/$id');
        },
        onTeamTap: () {
          _dismissOverlay();
          _controller.clear();
          _focusNode.unfocus();
          context.push(Routes.team);
        },
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
  }

  void _dismissOverlay() {
    _removeOverlay();
    if (mounted) setState(() {});
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return CompositedTransformTarget(
      link: _layerLink,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search decisions, team...',
            hintStyle: TextStyle(color: cs.textTertiary, fontSize: 14),
            prefixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : Icon(Icons.search, color: cs.textTertiary, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.borderDefault),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: AppColorScheme.accent, width: 1.5),
            ),
            filled: true,
            fillColor: cs.backgroundElevated,
          ),
        ),
      ),
    );
  }
}

// ── Search results overlay panel ──────────────────────────────────────────────

class _SearchOverlayPanel extends StatelessWidget {
  const _SearchOverlayPanel({
    required this.layerLink,
    required this.decisions,
    required this.members,
    required this.onDismiss,
    required this.onDecisionTap,
    required this.onTeamTap,
  });

  final LayerLink layerLink;
  final List<_DecisionHit> decisions;
  final List<WorkspaceMembership> members;
  final VoidCallback onDismiss;
  final ValueChanged<String> onDecisionTap;
  final VoidCallback onTeamTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Transparent tap-outside barrier
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),

        // Panel anchored below the search field
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 6),
            child: Builder(
              builder: (context) {
                final cs = context.cs;
                return Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 380,
                    constraints: const BoxConstraints(maxHeight: 440),
                    decoration: BoxDecoration(
                      color: cs.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.borderDefault),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (decisions.isNotEmpty) ...[
                              _GroupHeader(
                                  label: 'Decisions',
                                  count: decisions.length),
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              ...decisions.map((d) => _DecisionTile(
                                    decision: d,
                                    onTap: () => onDecisionTap(d.id),
                                  )),
                            ],
                            if (decisions.isNotEmpty && members.isNotEmpty)
                              const SizedBox(height: 4),
                            if (members.isNotEmpty) ...[
                              _GroupHeader(
                                  label: 'Team Members',
                                  count: members.length),
                              const Divider(
                                  height: 1, indent: 16, endIndent: 16),
                              ...members.map((m) => _MemberTile(
                                    member: m,
                                    onTap: onTeamTap,
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets for the overlay ───────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.textTertiary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: cs.backgroundElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: cs.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.decision, required this.onTap});

  final _DecisionHit decision;
  final VoidCallback onTap;

  Color _stateBg(String state) => switch (state.toLowerCase()) {
        'active' => const Color(0x3319CBD6),
        'closed' => const Color(0x332EA073),
        'draft' => const Color(0x22606060),
        _ => const Color(0x22606060),
      };

  Color _stateFg(String state, BuildContext context) =>
      switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary,
        'closed' => AppColors.success,
        _ => context.cs.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                size: 16, color: context.cs.textTertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                decision.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: context.cs.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _stateBg(decision.state),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                decision.state,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _stateFg(decision.state, context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onTap});

  final WorkspaceMembership member;
  final VoidCallback onTap;

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = member.displayName ?? member.userId.substring(0, 8);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.18),
              child: Text(
                _initials(member.displayName),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: context.cs.textPrimary),
              ),
            ),
            Text(
              member.role,
              style: TextStyle(
                  fontSize: 11, color: context.cs.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User avatar button ────────────────────────────────────────────────────────

class _UserAvatarButton extends ConsumerWidget {
  const _UserAvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final authStatus = ref.watch(authStateProvider).valueOrNull;
    final email = authStatus is AuthAuthenticated
        ? authStatus.session.user.email ?? ''
        : '';

    final name = (profile?.displayName?.isNotEmpty == true)
        ? profile!.displayName!
        : email;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarUrl = profile?.avatarUrl;

    Widget avatar;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatar = Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        width: 32,
        height: 32,
        errorBuilder: (ctx, obj, st) => _initialsCircle(initial),
      );
    } else {
      avatar = _initialsCircle(initial);
    }

    return GestureDetector(
      onTap: () => _showUserProfileDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF19CBD6), width: 2.0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: avatar),
          ),
        ),
      ),
    );
  }

  Widget _initialsCircle(String initial) {
    return Container(
      color: const Color(0xFF19CBD6),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── User profile dialog ───────────────────────────────────────────────────────

void _showUserProfileDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: _ProfileDialogContent(
        onClose: () => Navigator.of(ctx).pop(),
      ),
    ),
  );
}

class _ProfileDialogContent extends ConsumerStatefulWidget {
  const _ProfileDialogContent({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_ProfileDialogContent> createState() =>
      _ProfileDialogContentState();
}

class _ProfileDialogContentState extends ConsumerState<_ProfileDialogContent> {
  bool _isUploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    if (file.bytes!.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image must be under 2MB'),
          backgroundColor: Color(0xFFDC4444),
        ));
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userId = supabase.auth.currentUser!.id;

      // Remove any existing avatar files for this user
      for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
        try {
          await supabase.storage
              .from('avatars')
              .remove(['$userId/avatar.$ext']);
        } catch (_) {}
      }

      final rawExt = file.extension?.toLowerCase() ?? 'jpg';
      final ext = rawExt == 'jpeg' ? 'jpg' : rawExt;
      const mimeTypes = {
        'jpg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'gif': 'image/gif',
      };
      final mimeType = mimeTypes[ext] ?? 'image/jpeg';
      final storagePath = '$userId/avatar.$ext';

      await supabase.storage.from('avatars').uploadBinary(
            storagePath,
            file.bytes!,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      final publicUrl =
          supabase.storage.from('avatars').getPublicUrl(storagePath);
      final avatarUrl =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await supabase
          .from('profiles')
          .update({'avatar_url': avatarUrl}).eq('user_id', userId);

      ref.invalidate(profileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Avatar updated'),
          backgroundColor: Color(0xFF2EA073),
        ));
      }
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          backgroundColor: const Color(0xFFDC4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _avatarImage(String? url, String? displayName, String? email) {
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (ctx, obj, st) => _initialsAvatar(displayName, email),
      );
    }
    return _initialsAvatar(displayName, email);
  }

  Widget _initialsAvatar(String? displayName, String? email) {
    final name = displayName ?? email ?? '?';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      color: const Color(0xFF19CBD6).withValues(alpha: 0.15),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF19CBD6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final currentUser = supabase.auth.currentUser;
    final email = currentUser?.email ?? '';
    final cs = context.cs;

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF19CBD6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Brand mark + close
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                SvgPicture.asset('assets/branding/icon.svg',
                    width: 24, height: 24),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: cs.textTertiary,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Avatar with edit button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0xFF19CBD6), width: 2.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: _avatarImage(
                          profile?.avatarUrl, profile?.displayName, email),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF19CBD6),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: cs.backgroundSecondary, width: 2),
                      ),
                      child: const Icon(Icons.edit,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
                if (_isUploading)
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Display name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              profile?.displayName?.isNotEmpty == true
                  ? profile!.displayName!
                  : email,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),

          // Email
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: Text(
              email,
              style: TextStyle(fontSize: 13, color: cs.textTertiary),
            ),
          ),

          Divider(color: cs.borderSubtle, height: 1),

          // Edit profile
          ListTile(
            leading: Icon(Icons.person_outline,
                color: cs.textSecondary, size: 20),
            title: Text('Edit profile',
                style: TextStyle(fontSize: 14, color: cs.textPrimary)),
            trailing:
                Icon(Icons.chevron_right, color: cs.textTertiary, size: 18),
            onTap: () {
              Navigator.pop(context);
              context.push(Routes.settings);
            },
          ),

          Divider(color: cs.borderSubtle, height: 1),

          // Sign out
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await supabase.auth.signOut();
              },
              child: Text(
                'Sign out',
                style: TextStyle(fontSize: 13, color: Colors.red.shade400),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
