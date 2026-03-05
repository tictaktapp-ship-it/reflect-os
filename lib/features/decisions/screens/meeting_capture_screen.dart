import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';

class MeetingCaptureScreen extends ConsumerStatefulWidget {
  const MeetingCaptureScreen({super.key});

  @override
  ConsumerState<MeetingCaptureScreen> createState() =>
      _MeetingCaptureScreenState();
}

class _MeetingCaptureScreenState
    extends ConsumerState<MeetingCaptureScreen> {
  final _notesController = TextEditingController();
  bool _isExtracting = false;
  String? _errorMessage;
  bool _isNetworkError = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _wordCount {
    final text = _notesController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  Future<void> _extract() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _isNetworkError = false;
    });

    try {
      final response = await supabase.functions.invoke(
        'extract-decision-from-meeting',
        body: {'meeting_notes': notes},
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null || (data['title'] as String?)?.isEmpty == true) {
        throw Exception('No decision could be extracted from these notes.');
      }

      if (!mounted) return;
      context.push(
        Routes.decisionsCreate,
        extra: <String, dynamic>{
          'title': data['title'] as String? ?? '',
          'description': data['description'] as String? ?? '',
          'stakes': data['stakes'] as String?,
          'category': data['category'] as String?,
          'fromMeeting': true,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isNetwork = msg.contains('Failed to fetch') ||
          msg.contains('XMLHttpRequest') ||
          msg.contains('NetworkError');
      setState(() {
        _isExtracting = false;
        _isNetworkError = isNetwork;
        _errorMessage = isNetwork
            ? 'Could not reach the AI service. This may be a network '
                'restriction.'
            : 'Failed to extract decision: $msg';
      });
    }
  }

  void _fillManually() {
    context.push(Routes.decisionsCreate);
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _wordCount;
    final hasEnoughWords = wordCount >= 100;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/images/reflect-icon-dark.svg'
                  : 'assets/images/reflect-icon-light.svg',
              height: 160,
            ),
            const SizedBox(width: 8),
            const Text('Capture from Meeting'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Instruction card ────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 20,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Paste your meeting notes and AI will extract the '
                      'key decision, description, stakes, and category for you.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Notes text field ─────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surface,
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _notesController,
                minLines: 8,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Paste your meeting notes here...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // ── Word count hint ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              wordCount == 0
                  ? 'Works best with 100+ words'
                  : hasEnoughWords
                      ? '$wordCount words — ready to extract'
                      : '$wordCount words — works best with 100+',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: hasEnoughWords
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
            ),
          ),

          // ── Error message ────────────────────────────────────────────
          if (_errorMessage != null) ...[
            Card(
              color: AppColors.destructive.withValues(alpha: 0.08),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: AppColors.destructive,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.destructive),
                          ),
                        ),
                      ],
                    ),
                    if (_isNetworkError) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _fillManually,
                        child: const Text('Fill in manually instead'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // ── Extract button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_isExtracting || _notesController.text.trim().isEmpty)
                  ? null
                  : _extract,
              child: _isExtracting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Analysing meeting notes...'),
                      ],
                    )
                  : const Text('Extract Decision'),
            ),
          ),

          const SizedBox(height: 12),

          // ── Manual fallback ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _fillManually,
              child: const Text('Fill in manually'),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
