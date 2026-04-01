import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/connectivity_provider.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/chat/providers/chat_providers.dart';
import 'package:reflect_os/features/chat/widgets/chat_panel_widget.dart';
import 'package:reflect_os/features/settings/providers/profile_provider.dart';
import 'package:reflect_os/widgets/reflect_logo.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _chatOpen = false;

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    final workspaceId =
        ref.watch(currentWorkspaceProvider).valueOrNull;
    final workspaceType =
        ref.watch(currentWorkspaceTypeProvider).valueOrNull;
    final isTeamWorkspace = workspaceType == 'team';
    final unreadCount = isTeamWorkspace && workspaceId != null
        ? ref.watch(chatUnreadCountProvider(workspaceId))
        : 0;

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              if (!isOnline) const _OfflineBanner(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 600) {
                      return _WideShell(
                        navigationShell: widget.navigationShell,
                        selectedIndex:
                            widget.navigationShell.currentIndex,
                        onDestinationSelected: _onDestinationSelected,
                        showChatButton: isTeamWorkspace,
                        chatUnreadCount: unreadCount,
                        onChatTap: () =>
                            setState(() => _chatOpen = !_chatOpen),
                      );
                    }
                    return _NarrowShell(
                      navigationShell: widget.navigationShell,
                      selectedIndex:
                          widget.navigationShell.currentIndex,
                      onDestinationSelected: _onDestinationSelected,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // New Decision FAB — shown on the Decisions tab (index 1)
        if (widget.navigationShell.currentIndex == 1)
          Positioned(
            bottom: 20,
            right: 20,
            child: _NewDecisionFab(
              onTap: () => context.push(Routes.decisionsCreate),
            ),
          ),
        // Chat panel — team workspaces only, toggled from nav pane
        if (isTeamWorkspace && workspaceId != null && _chatOpen)
          _buildChatPanel(context, workspaceId),
      ],
    );
  }

  void _closeChat() => setState(() => _chatOpen = false);

  Widget _buildChatPanel(BuildContext context, String workspaceId) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return Positioned.fill(
        child: ChatPanelWidget(
          workspaceId: workspaceId,
          onClose: _closeChat,
        ),
      );
    }
    return Positioned(
      bottom: 90,
      right: 24,
      child: SizedBox(
        width: 360,
        height: 520,
        child: ChatPanelWidget(
          workspaceId: workspaceId,
          onClose: _closeChat,
        ),
      ),
    );
  }
}

// ── New Decision FAB ───────────────────────────────────────────────────────────

class _NewDecisionFab extends StatelessWidget {
  const _NewDecisionFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: const Color(0xFF19CBD6),
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'New Decision',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'DMSans',
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Text(
        'You are offline — changes will sync when reconnected',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Wide layout ────────────────────────────────────────────────────────────────

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.navigationShell,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.showChatButton = false,
    this.chatUnreadCount = 0,
    this.onChatTap,
  });

  final StatefulNavigationShell navigationShell;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showChatButton;
  final int chatUnreadCount;
  final VoidCallback? onChatTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _NavPane(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            showChatButton: showChatButton,
            chatUnreadCount: chatUnreadCount,
            onChatTap: onChatTap,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

// ── Nav pane (240px wide) ──────────────────────────────────────────────────────

BoxDecoration _navTooltipDecoration() => BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: const Color(0xFF19CBD6).withValues(alpha: 0.4),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(4, 0),
        ),
      ],
    );

const TextStyle _navTooltipTextStyle = TextStyle(
  color: Color(0xFFF4F5F7),
  fontSize: 12,
  fontFamily: 'DMSans',
  height: 1.5,
);

class _NavPane extends StatelessWidget {
  const _NavPane({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.showChatButton = false,
    this.chatUnreadCount = 0,
    this.onChatTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showChatButton;
  final int chatUnreadCount;
  final VoidCallback? onChatTap;

  static const _items = [
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
      tooltipMessage:
          'Dashboard — decision health overview,\ncalibration scores and recent activity',
    ),
    _NavItem(
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      label: 'Decisions',
      tooltipMessage:
          'Log, review and manage decisions.\nBrowse by status, category or stakes.',
    ),
    _NavItem(
      icon: Icons.flag_outlined,
      selectedIcon: Icons.flag,
      label: 'Initiatives',
      tooltipMessage:
          'Group related decisions into strategic\nprogrammes and track collective progress.',
    ),
    _NavItem(
      icon: Icons.group_outlined,
      selectedIcon: Icons.group,
      label: 'Team',
      tooltipMessage:
          'Manage workspace members, roles\nand pending invitations.',
    ),
    _NavItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: 'Coach',
      tooltipMessage:
          'Connect with your coach or manage clients.\nView shared decisions and session notes.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: cs.backgroundSecondary,
        border: Border(
          right: BorderSide(color: cs.borderDefault, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: const ReflectLogo(iconSize: 30),
          ),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isSelected = selectedIndex == i;
            return _NavPaneItem(
              item: item,
              isSelected: isSelected,
              onTap: () => onDestinationSelected(i),
            );
          }),
          if (showChatButton)
            _ChatNavItem(
              unreadCount: chatUnreadCount,
              onTap: onChatTap ?? () {},
            ),
          const _ToolkitNavItem(),
          const Spacer(),
          const _NavPaneSettingsItem(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.tooltipMessage,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String tooltipMessage;
}

class _NavPaneItem extends StatelessWidget {
  const _NavPaneItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  static const _teal = AppColorScheme.accent;

  @override
  Widget build(BuildContext context) {
    final grey = context.cs.textSecondary;
    return Tooltip(
      message: item.tooltipMessage,
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      decoration: _navTooltipDecoration(),
      textStyle: _navTooltipTextStyle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ClipRRect(
          borderRadius: AppRadius.smBR,
          child: Material(
            color: isSelected
                ? _teal.withValues(alpha: 0.12)
                : Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      color: isSelected ? _teal : Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected ? _teal : grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected ? _teal : grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatNavItem extends StatelessWidget {
  const _ChatNavItem({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grey = context.cs.textSecondary;
    return Tooltip(
      message: 'Team messaging — real-time chat\nwith your workspace members.',
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      decoration: _navTooltipDecoration(),
      textStyle: _navTooltipTextStyle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ClipRRect(
          borderRadius: AppRadius.smBR,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Container(width: 3, color: Colors.transparent),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Row(
                          children: [
                            Badge(
                              isLabelVisible: unreadCount > 0,
                              label: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(fontSize: 9),
                              ),
                              child: Icon(Icons.chat_bubble_outline,
                                  size: 20, color: grey),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Chat',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolkitNavItem extends StatelessWidget {
  const _ToolkitNavItem();

  @override
  Widget build(BuildContext context) {
    final grey = context.cs.textSecondary;
    return Tooltip(
      message:
          'Analysis tools — run financial models,\ngenerate reports and attach to decisions.',
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      decoration: _navTooltipDecoration(),
      textStyle: _navTooltipTextStyle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ClipRRect(
          borderRadius: AppRadius.smBR,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(Routes.toolkit),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Row(
                          children: [
                            Icon(Icons.construction_outlined, size: 20, color: grey),
                            const SizedBox(width: 12),
                            Text(
                              'Toolkit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPaneSettingsItem extends StatelessWidget {
  const _NavPaneSettingsItem();

  @override
  Widget build(BuildContext context) {
    final grey = context.cs.textSecondary;
    return Tooltip(
      message: 'App settings, security,\ndata and privacy management.',
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      decoration: _navTooltipDecoration(),
      textStyle: _navTooltipTextStyle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ClipRRect(
          borderRadius: AppRadius.smBR,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(Routes.settings),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    const SizedBox(width: 3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 20, color: grey),
                            const SizedBox(width: 12),
                            Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Narrow layout (BottomNavigationBar) ───────────────────────────────────────

class _NarrowShell extends StatefulWidget {
  const _NarrowShell({
    required this.navigationShell,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  State<_NarrowShell> createState() => _NarrowShellState();
}

class _NarrowShellState extends State<_NarrowShell> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          decoration: InputDecoration(
            hintText: 'Search…',
            prefixIcon: const Icon(Icons.search_outlined, size: 18),
            suffixIcon: (_searchFocused || _searchController.text.isNotEmpty)
                ? IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      _searchFocus.unfocus();
                    },
                  )
                : null,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: AppRadius.smBR,
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smBR,
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              context.push(Routes.search);
            }
          },
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: _UserAvatarButton(),
          ),
        ],
      ),
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Decisions',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Initiatives',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'Coach',
          ),
        ],
      ),
    );
  }
}

// ── User Avatar Button (narrow shell only) ────────────────────────────────────

class _UserAvatarButton extends ConsumerWidget {
  const _UserAvatarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final email = supabase.auth.currentUser?.email ?? '';
    final avatarUrl = profile?.avatarUrl;
    final initials = _initials(profile?.displayName ?? email);

    return IconButton(
      tooltip: 'Profile & Settings',
      onPressed: () => context.push(Routes.settings),
      icon: CircleAvatar(
        radius: 14,
        backgroundColor: AppColors.accentPrimary,
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null
            ? Text(
                initials,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'[\s@]+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
