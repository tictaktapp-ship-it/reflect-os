import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/sharing/data/models/share_link.dart';

class PublicDecisionView extends StatefulWidget {
  const PublicDecisionView({required this.token, super.key});

  final String token;

  @override
  State<PublicDecisionView> createState() => _PublicDecisionViewState();
}

class _PublicDecisionViewState extends State<PublicDecisionView> {
  _ViewState _state = _ViewState.loading;
  Map<String, dynamic>? _decision;
  List<Map<String, dynamic>> _outcomes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // 1. Resolve the token → share link row.
      final linkRow = await supabase
          .from('share_links')
          .select()
          .eq('token_hash', widget.token)
          .isFilter('deleted_at', null)
          .maybeSingle();

      if (linkRow == null) {
        if (mounted) setState(() => _state = _ViewState.invalid);
        return;
      }

      final shareLink = ShareLink.fromJson(linkRow);
      if (!shareLink.isActive) {
        if (mounted) setState(() => _state = _ViewState.invalid);
        return;
      }

      // 2. Fetch decision from the canonical view.
      final decisionRow = await supabase
          .from('user_visible_decisions')
          .select()
          .eq('id', shareLink.decisionId)
          .maybeSingle();

      if (decisionRow == null) {
        if (mounted) setState(() => _state = _ViewState.invalid);
        return;
      }

      // 3. Fetch outcomes — best-effort, empty list on failure.
      List<Map<String, dynamic>> outcomes = [];
      try {
        final rows = await supabase
            .from('outcome_updates')
            .select()
            .eq('decision_id', shareLink.decisionId)
            .order('created_at', ascending: false);
        outcomes = List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        // Outcomes may not be accessible via anon key; that's fine.
      }

      if (mounted) {
        setState(() {
          _decision = decisionRow;
          _outcomes = outcomes;
          _state = _ViewState.loaded;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _state = _ViewState.invalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/branding/icon.svg'
                  : 'assets/branding/icon.svg',
              height: 160,
            ),
            const SizedBox(width: 8),
            const Text('Shared Decision'),
          ],
        ),
      ),
      body: switch (_state) {
        _ViewState.loading => const Center(child: CircularProgressIndicator()),
        _ViewState.invalid => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link_off,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This link is invalid or has expired.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The share link may have been revoked or never existed.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        _ViewState.loaded => _DecisionBody(
            decision: _decision!,
            outcomes: _outcomes,
          ),
      },
    );
  }
}

enum _ViewState { loading, invalid, loaded }

class _DecisionBody extends StatelessWidget {
  const _DecisionBody({
    required this.decision,
    required this.outcomes,
  });

  final Map<String, dynamic> decision;
  final List<Map<String, dynamic>> outcomes;

  String _fmt(String? isoDate) {
    if (isoDate == null) return '—';
    return DateFormat('d MMM yyyy').format(DateTime.parse(isoDate).toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final title = decision['title'] as String? ?? '—';
    final state = decision['state'] as String? ?? '—';
    final stakes = decision['stakes'] as String?;
    final description = decision['description_encrypted'] as String?;
    final createdAt = decision['created_at'] as String?;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title & state
        Card(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                _StateBadge(state: state),
              ],
            ),
          ),
        ),

        // Overview
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stakes != null) _Row(label: 'Stakes', value: stakes),
                _Row(label: 'Created', value: _fmt(createdAt)),
              ],
            ),
          ),
        ),

        // Description
        if (description != null && description.isNotEmpty)
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(description,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),

        // Outcomes
        if (outcomes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 20, bottom: 8),
            child: Text(
              'Outcomes',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          ...outcomes.map((o) {
            final text = o['outcome_text_encrypted'] as String?;
            final score = o['outcome_quality_score'] as int?;
            final date = o['created_at'] as String?;
            return Card(
              color: Theme.of(context).colorScheme.surface,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _fmt(date),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        if (score != null) ...[
                          const Spacer(),
                          Text(
                            'Quality: $score/10',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    if (text != null && text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(text,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 32),
        Center(
          child: Text(
            'Shared via Reflect OS · Read only',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state.toLowerCase()) {
      'active' => AppColors.accentHover,
      'closed' => AppColors.success,
      'archived' => AppColors.textMuted,
      _ => AppColors.textSecondary,
    };
    final bg = color.withValues(alpha: 0.15);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
