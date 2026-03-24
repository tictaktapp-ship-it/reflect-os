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
        if (isTeamWorkspace && workspaceId != null) ...[
          if (_chatOpen)
            _buildChatPanel(context, workspaceId),
          Positioned(
            bottom: 24,
            right: 24,
            child: _ChatFab(
              unreadCount: unreadCount,
              onPressed: () =>
                  setState(() => _chatOpen = !_chatOpen),
            ),
          ),
        ],
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

// ── Chat FAB ───────────────────────────────────────────────────────────────────

class _ChatFab extends StatelessWidget {
  const _ChatFab({required this.unreadCount, required this.onPressed});

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF19CBD6),
      onPressed: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.chat_bubble_outline, color: Colors.white),
          if (unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: CircleAvatar(
                radius: 8,
                backgroundColor: const Color(0xFFDC4444),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
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
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

// ── Nav pane (80px wide) ───────────────────────────────────────────────────────

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
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    _NavItem(
        icon: Icons.task_alt_outlined,
        selectedIcon: Icons.task_alt,
        label: 'Decisions'),
    _NavItem(
        icon: Icons.flag_outlined, selectedIcon: Icons.flag, label: 'Initiatives'),
    _NavItem(
        icon: Icons.group_outlined, selectedIcon: Icons.group, label: 'Team'),
    _NavItem(
        icon: Icons.psychology_outlined,
        selectedIcon: Icons.psychology,
        label: 'Coach'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
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
          if (showChatButton) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            _ChatNavItem(
              unreadCount: chatUnreadCount,
              onTap: onChatTap ?? () {},
            ),
          ],
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
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
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

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.accentPrimary : null;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: isSelected
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: AppColors.accentPrimary, width: 3),
                ),
                color: AppColors.accentPrimary.withValues(alpha: 0.08),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(fontSize: 9),
                ),
                child: const Icon(Icons.chat_bubble_outline, size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'Chat',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
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
    return InkWell(
      onTap: () => context.push(Routes.settings),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.settings_outlined, size: 22),
            const SizedBox(height: 4),
            Text(
              'Settings',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
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
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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
