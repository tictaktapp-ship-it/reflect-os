import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/connectivity_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/decision.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/features/settings/providers/profile_provider.dart';
import 'package:reflect_os/features/team/data/models/workspace_membership.dart';
import 'package:reflect_os/features/team/providers/team_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Column(
      children: [
        if (!isOnline) const _OfflineBanner(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 600) {
                return _WideShell(
                  navigationShell: widget.navigationShell,
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                );
              }
              return _NarrowShell(
                navigationShell: widget.navigationShell,
                selectedIndex: widget.navigationShell.currentIndex,
                onDestinationSelected: _onDestinationSelected,
              );
            },
          ),
        ),
      ],
    );
  }
}

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

class _WideShell extends ConsumerStatefulWidget {
  const _WideShell({
    required this.navigationShell,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  ConsumerState<_WideShell> createState() => _WideShellState();
}

class _WideShellState extends ConsumerState<_WideShell> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = '';
  bool _showResults = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.trim();
          _showResults = _searchQuery.isNotEmpty;
        });
      }
    });
  }

  void _dismissSearch() {
    setState(() {
      _searchQuery = '';
      _showResults = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // ── Global top strip ────────────────────────────────────────
              _GlobalHeader(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onDismissSearch: _dismissSearch,
              ),
              // ── Main row: nav pane + content ────────────────────────────
              Expanded(
                child: Row(
                  children: [
                    _NavPane(
                      selectedIndex: widget.selectedIndex,
                      onDestinationSelected: widget.onDestinationSelected,
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: widget.navigationShell),
                  ],
                ),
              ),
            ],
          ),
          // ── Search results overlay ──────────────────────────────────────
          if (_showResults)
            Positioned(
              top: 48,
              right: 16,
              child: _SearchResultsPanel(
                query: _searchQuery,
                onDismiss: _dismissSearch,
              ),
            ),
          // ── Tap outside to dismiss ──────────────────────────────────────
          if (_showResults)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _dismissSearch,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Global header strip ────────────────────────────────────────────────────────

class _GlobalHeader extends ConsumerWidget {
  const _GlobalHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onDismissSearch,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onDismissSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Colors.black12;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: dividerColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SvgPicture.asset('assets/branding/icon.svg', height: 28),
          const Spacer(),
          SizedBox(
            width: 280,
            height: 32,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search decisions, team…',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.black54),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.black54),
                        onPressed: onDismissSearch,
                        padding: EdgeInsets.zero,
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const _UserAvatarButton(),
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
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

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

// ── Search results panel ───────────────────────────────────────────────────────

class _SearchResultsPanel extends ConsumerWidget {
  const _SearchResultsPanel({
    required this.query,
    required this.onDismiss,
  });

  final String query;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decisionsAsync = ref.watch(searchProvider(query));
    final membersAsync = ref.watch(teamMembersProvider);

    final decisions = decisionsAsync.valueOrNull ?? <Decision>[];
    final allMembers = membersAsync.valueOrNull ?? <WorkspaceMembership>[];
    final lowerQuery = query.toLowerCase();
    final members = allMembers.where((m) {
      final name = (m.displayName ?? '').toLowerCase();
      return name.contains(lowerQuery);
    }).toList();

    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        width: 380,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text(
                    'Search results for "$query"',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Decisions section
                  _ResultsSectionHeader(
                      title: 'Decisions', count: decisions.length),
                  if (decisionsAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )),
                    )
                  else if (decisions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'No decisions found',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                      ),
                    )
                  else
                    ...decisions.map(
                      (d) => ListTile(
                        dense: true,
                        title: Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(d.state),
                        leading: const Icon(Icons.task_alt_outlined, size: 18),
                        onTap: () {
                          onDismiss();
                          context.push('/decisions/detail/${d.id}');
                        },
                      ),
                    ),

                  // Team members section
                  _ResultsSectionHeader(
                      title: 'Team Members', count: members.length),
                  if (members.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'No team members found',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                      ),
                    )
                  else
                    ...members.map(
                      (m) => ListTile(
                        dense: true,
                        title: Text(
                          m.displayName ?? m.userId.substring(0, 8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(m.role),
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundImage: m.avatarUrl != null
                              ? NetworkImage(m.avatarUrl!)
                              : null,
                          backgroundColor: AppColors.accentPrimary,
                          child: m.avatarUrl == null
                              ? Text(
                                  (m.displayName ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white),
                                )
                              : null,
                        ),
                        onTap: () {
                          onDismiss();
                          context.push(Routes.team);
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsSectionHeader extends StatelessWidget {
  const _ResultsSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accentPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
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

// ── User Avatar Button ─────────────────────────────────────────────────────────

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
