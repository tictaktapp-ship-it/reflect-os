import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/providers/theme_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/core/widgets/change_password_dialog.dart';
import 'package:reflect_os/features/settings/providers/profile_provider.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';

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
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

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
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.only(left: 8),
            ),
          Padding(
            padding: EdgeInsets.only(left: canPop ? 0 : 16),
            child: SvgPicture.asset(
              'assets/branding/logo-light.svg',
              height: 36,
              fit: BoxFit.contain,
            ),
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
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
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

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 56,
      automaticallyImplyLeading: false,
      leading: leadingWidget,
      leadingWidth: leadingWidth,
      title: centre,
      centerTitle: centreTitle,
      titleSpacing: _isDashboardMode ? 8 : NavigationToolbar.kMiddleSpacing,
      actions: rightActions,
      bottom: bottom,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE5E7EB)),
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
            hintStyle: const TextStyle(color: Color(0xFF7D8494), fontSize: 14),
            prefixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : const Icon(Icons.search, color: Color(0xFF7D8494), size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF19CBD6), width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF4F5F7),
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
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380,
                constraints: const BoxConstraints(maxHeight: 440),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              label: 'Decisions', count: decisions.length),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ...decisions.map((d) => _DecisionTile(
                                decision: d,
                                onTap: () => onDecisionTap(d.id),
                              )),
                        ],
                        if (decisions.isNotEmpty && members.isNotEmpty)
                          const SizedBox(height: 4),
                        if (members.isNotEmpty) ...[
                          _GroupHeader(
                              label: 'Team Members', count: members.length),
                          const Divider(height: 1, indent: 16, endIndent: 16),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
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

  Color _stateFg(String state) => switch (state.toLowerCase()) {
        'active' => AppColors.accentPrimary,
        'closed' => AppColors.success,
        _ => const Color(0xFF64748B),
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 16, color: Color(0xFF94A3B8)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                decision.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1A1A2E)),
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
                  color: _stateFg(decision.state),
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
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1A1A2E)),
              ),
            ),
            Text(
              member.role,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8)),
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

    return GestureDetector(
      onTap: () =>
          _showUserProfileSheet(context, ref, profile?.displayName, email),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFF19CBD6),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ── User profile sheet ────────────────────────────────────────────────────────

void _showUserProfileSheet(
    BuildContext context, WidgetRef ref, String? displayName, String email) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      side: BorderSide(color: Color(0xFF19CBD6), width: 1.5),
    ),
    builder: (ctx) => _UserProfileSheetBody(
      displayName: displayName,
      email: email,
    ),
  );
}

class _UserProfileSheetBody extends ConsumerWidget {
  const _UserProfileSheetBody({
    required this.displayName,
    required this.email,
  });

  final String? displayName;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand icon
            Center(
              child: SvgPicture.asset('assets/branding/icon.svg', height: 36),
            ),
            const SizedBox(height: 14),
            // Name
            Center(
              child: Text(
                displayName?.isNotEmpty == true ? displayName! : email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Email
            Center(
              child: Text(
                email,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Change password
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: Color(0xFF19CBD6)),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                showChangePasswordDialog(context);
              },
            ),
            // Notifications
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_outlined,
                  color: Color(0xFF19CBD6)),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop();
                context.push(Routes.settingsPrivacy);
              },
            ),
            // Appearance
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.brightness_6_outlined,
                  color: Color(0xFF19CBD6)),
              title: const Text('Appearance'),
              subtitle: Text(themeMode == ThemeMode.light ? 'Light' : 'Dark'),
              trailing: Switch(
                value: themeMode == ThemeMode.light,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
            const Divider(),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.settings);
                },
                child: const Text('Manage profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
