import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/providers/auth_state_provider.dart';
import 'package:reflect_os/core/providers/theme_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/widgets/workspace_switcher_chip.dart';
import 'package:reflect_os/features/settings/providers/profile_provider.dart';

/// Brand app bar used by every screen in Reflect OS.
///
/// Left  : full logo (icon + wordmark) from assets/branding/logo-light.svg
/// Centre: [centreContent] if provided, else [title] as Text, else WorkspaceSwitcherChip
/// Right : screen-specific [actions] + workspace-settings tune icon + user avatar
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

  @override
  Size get preferredSize =>
      Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = automaticallyImplyLeading && Navigator.of(context).canPop();

    final leadingWidget = leading ??
        Row(
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

    final centre = centreContent ??
        (title != null
            ? Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              )
            : const WorkspaceSwitcherChip());

    final rightActions = [
      ...?actions,
      IconButton(
        icon: const Icon(Icons.tune_outlined, color: Color(0xFF64748B)),
        tooltip: 'Workspace settings',
        onPressed: () => context.push(Routes.settingsWorkspaces),
      ),
      const _UserAvatarButton(),
      const SizedBox(width: 8),
    ];

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      leading: leadingWidget,
      leadingWidth: canPop ? 140 : 180,
      title: centre,
      centerTitle: true,
      actions: rightActions,
      bottom: bottom,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE2E8F0)),
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
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showUserProfileSheet(context, ref, profile?.displayName, email),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFF19CBD6),
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
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
