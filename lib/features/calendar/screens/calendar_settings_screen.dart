import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/calendar/data/models/calendar_connection.dart';
import 'package:reflect_os/features/calendar/providers/calendar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';
import 'calendar_platform_stub.dart'
    if (dart.library.html) 'calendar_platform_web.dart';
import 'package:reflect_os/core/theme/app_radius.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen>
    with WidgetsBindingObserver {
  String? _workspaceId;
  bool _autoSync = true;
  bool _isLoading = true;
  bool _isDisconnecting = false;
  late final void Function() _stopListening;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stopListening = addCalendarMessageListener(_handleCalendarMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    if (kIsWeb) {
      final uri = Uri.base;
      if (uri.queryParameters['calendar_oauth'] == 'success') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.invalidate(calendarConnectionsProvider);
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(calendarConnectionsProvider);
    }
  }

  Future<void> _load() async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    if (!mounted) return;
    _workspaceId = workspaceId;

    if (workspaceId != null) {
      final prefs = await SharedPreferences.getInstance();
      final sync = prefs.getBool('calendar_sync_$workspaceId') ?? true;
      if (!mounted) return;
      setState(() {
        _autoSync = sync;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setAutoSync(bool value) async {
    setState(() => _autoSync = value);
    if (_workspaceId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('calendar_sync_$_workspaceId', value);
    }
  }

  void _handleCalendarMessage(dynamic data) {
    if (data is Map && data['type'] == 'calendar-oauth-success') {
      if (mounted && _workspaceId != null) {
        ref.invalidate(calendarConnectionsProvider(_workspaceId!));
      }
    }
  }

  Future<void> _connect(String provider) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _workspaceId == null) return;
    try {
      const isPopup = false;
      final uri = Uri.parse(
        'https://omazuyditjbtoupmipcr.supabase.co/functions/v1/calendar-oauth-initiate'
        '?provider=$provider&user_id=$userId&workspace_id=$_workspaceId&is_popup=$isPopup',
      );
      final resp = await http.get(uri);
      final authUrl = jsonDecode(resp.body)['url'] as String;
      final url = Uri.parse(authUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start $provider connection: $e')),
        );
      }
    }
  }

  Future<void> _disconnect(CalendarConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DialogShell(
        title: 'Disconnect ${connection.provider}?',
        child: const Text(
          'Future checkpoints will not be synced. '
          'Existing calendar events will not be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.destructive),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDisconnecting = true);
    try {
      await ref
          .read(calendarRepositoryProvider)
          .disconnectCalendar(connection.id);
      if (_workspaceId != null) {
        ref.invalidate(calendarConnectionsProvider(_workspaceId!));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${connection.provider} disconnected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disconnect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(calendarConnectionsProvider),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workspaceId == null
              ? const Center(
                  child: Text('No workspace found.'),
                )
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final connectionsAsync =
        ref.watch(calendarConnectionsProvider(_workspaceId!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Explanation ────────────────────────────────────────────
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Connect your calendar to automatically create events '
                    'for decision checkpoints.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Provider cards ─────────────────────────────────────────
        connectionsAsync.when(
          loading: () => const _ProviderCardShimmer(),
          error: (e, _) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load calendar connections.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.destructive),
              ),
            ),
          ),
          data: (connections) {
            final google = connections
                .where((c) =>
                    c.provider.toLowerCase().contains('google'))
                .firstOrNull;
            final outlook = connections
                .where((c) =>
                    c.provider.toLowerCase().contains('outlook') ||
                    c.provider.toLowerCase().contains('microsoft'))
                .firstOrNull;

            return Column(
              children: [
                _ProviderCard(
                  icon: Icons.calendar_today,
                  iconColor: Colors.teal,
                  providerName: 'Google Calendar',
                  connection: google,
                  isDisconnecting: _isDisconnecting,
                  onConnect: () => _connect('google'),
                  onDisconnect: google != null
                      ? () => _disconnect(google)
                      : null,
                ),
                const SizedBox(height: 8),
                _ProviderCard(
                  icon: Icons.calendar_month,
                  iconColor: Colors.blue,
                  providerName: 'Microsoft Outlook',
                  connection: outlook,
                  isDisconnecting: _isDisconnecting,
                  onConnect: () => _connect('microsoft'),
                  onDisconnect: outlook != null
                      ? () => _disconnect(outlook)
                      : null,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 8),

        // ── Auto-sync toggle ───────────────────────────────────────
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            secondary: const Icon(Icons.sync_outlined),
            title: const Text('Auto-sync checkpoints to calendar'),
            subtitle: const Text(
                'Automatically add checkpoint events when a decision is activated'),
            value: _autoSync,
            onChanged: _setAutoSync,
          ),
        ),

        // ── How it works ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'How it works',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _HowItWorksTile(
                  icon: Icons.play_circle_outline,
                  text:
                      'When you activate a decision, checkpoint dates are automatically added to your calendar.',
                ),
                _HowItWorksTile(
                  icon: Icons.link_outlined,
                  text:
                      'Events include the decision title and a deep link back to Reflect OS.',
                ),
                _HowItWorksTile(
                  icon: Icons.cancel_outlined,
                  text:
                      'Closing a decision cancels all future checkpoint events.',
                ),
                _HowItWorksTile(
                  icon: Icons.tune_outlined,
                  text: 'Toggle per-workspace in workspace settings.',
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Provider card ─────────────────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.icon,
    required this.iconColor,
    required this.providerName,
    required this.connection,
    required this.isDisconnecting,
    required this.onConnect,
    required this.onDisconnect,
  });

  final IconData icon;
  final Color iconColor;
  final String providerName;
  final CalendarConnection? connection;
  final bool isDisconnecting;
  final VoidCallback onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final isConnected = connection?.isConnected ?? false;

    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Provider icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdBR,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),

            // Provider name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    providerName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  if (isConnected && connection != null)
                    Text(
                      'Connected since ${DateFormat('d MMM yyyy').format(connection!.createdAt)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    )
                  else
                    _StatusChip(connected: false),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Action button
            if (isConnected)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(connected: true),
                  const SizedBox(height: 6),
                  isDisconnecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : OutlinedButton(
                          onPressed: onDisconnect,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.destructive,
                            side: BorderSide(color: AppColors.destructive),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Disconnect',
                              style: TextStyle(fontSize: 12)),
                        ),
                ],
              )
            else
              FilledButton(
                onPressed: onConnect,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Connect $providerName',
                    style: const TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: connected
            ? AppColors.success.withValues(alpha: 0.15)
            : Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
        borderRadius: AppRadius.smBR,
      ),
      child: Text(
        connected ? 'Connected' : 'Not connected',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: connected
                  ? AppColors.success
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── How it works tile ─────────────────────────────────────────────────────────

class _HowItWorksTile extends StatelessWidget {
  const _HowItWorksTile({
    required this.icon,
    required this.text,
    this.isLast = false,
  });
  final IconData icon;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

class _ProviderCardShimmer extends StatelessWidget {
  const _ProviderCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
