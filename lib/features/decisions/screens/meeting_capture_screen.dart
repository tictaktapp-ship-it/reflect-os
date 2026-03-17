import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';
import 'package:reflect_os/widgets/app_header.dart';
import 'package:reflect_os/widgets/dialog_shell.dart';

class MeetingCaptureScreen extends ConsumerStatefulWidget {
  const MeetingCaptureScreen({super.key, this.mode, this.source});

  /// 'multiple' → POST mode:multiple, handle bulk review step.
  /// null / any other value → single-decision mode (default).
  final String? mode;

  /// 'add_decision' → when extraction yields a single decision, pop back
  /// with the result data instead of pushing a new CreateDecisionScreen.
  final String? source;

  @override
  ConsumerState<MeetingCaptureScreen> createState() =>
      _MeetingCaptureScreenState();
}

class _MeetingCaptureScreenState extends ConsumerState<MeetingCaptureScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Tab 1: Paste notes ───────────────────────────────────────────────────
  final _notesController = TextEditingController();

  // ── Tab 2: Upload file ───────────────────────────────────────────────────
  String? _uploadedFileName;
  String? _uploadedFileContent;

  // ── Tab 3: Add link ──────────────────────────────────────────────────────
  final _linkController = TextEditingController();
  String? _linkError;

  // ── Tab 4: Audio / Video ─────────────────────────────────────────────────
  String? _audioFileName;
  final _transcriptController = TextEditingController();
  final _transcriptPasteController = TextEditingController();

  // ── Shared state ─────────────────────────────────────────────────────────
  bool _isExtracting = false;
  String? _errorMessage;

  // ── Categories (loaded on init for category-name → UUID mapping) ─────────
  List<Category> _workspaceCategories = [];

  // ── Review step ──────────────────────────────────────────────────────────
  bool _inReviewMode = false;
  List<Map<String, dynamic>> _extractedDecisions = [];
  Set<int> _selectedIndices = {};
  bool _isCreating = false;

  static const _extractContentUrl =
      'https://omazuyditjbtoupmipcr.supabase.co/functions/v1/extract-decisions-from-content';
  static const _extractMeetingUrl =
      '$supabaseProjectUrl/functions/v1/extract-decision-from-meeting';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    // Load categories immediately so they are ready before any extraction.
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _linkController.dispose();
    _transcriptController.dispose();
    _transcriptPasteController.dispose();
    super.dispose();
  }

  // ── Category loading ──────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) return;
      final cats = await ref
          .read(decisionsRepositoryProvider)
          .getCategories(workspaceId);
      debugPrint('[MeetingCapture] Loaded ${cats.length} categories: '
          '${cats.map((c) => '${c.name}(${c.id})').join(', ')}');
      if (mounted) setState(() => _workspaceCategories = cats);
    } catch (e) {
      debugPrint('[MeetingCapture] Failed to load categories: $e');
    }
  }

  /// Resolves an AI-returned category name to its workspace UUID.
  /// Falls back to the first category if no exact match. Returns null if
  /// the categories list is empty.
  String? _resolveCategoryId(String? name) {
    if (name == null || name.isEmpty || _workspaceCategories.isEmpty) {
      return null;
    }
    try {
      return _workspaceCategories
          .firstWhere(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
            orElse: () => _workspaceCategories.first,
          )
          .id;
    } catch (_) {
      return null;
    }
  }

  int get _wordCount {
    final text = _notesController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  // ── AI consent dialog ─────────────────────────────────────────────────────

  Future<bool> _showAIConsentDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DialogShell(
        title: 'AI-Powered Extraction',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _consentBullet(
              Icons.smart_toy_outlined,
              'Your content will be sent to an AI model for analysis',
            ),
            const SizedBox(height: 10),
            _consentBullet(
              Icons.lock_outline,
              'Data is processed securely and not used to train AI models',
            ),
            const SizedBox(height: 10),
            _consentBullet(
              Icons.edit_note_outlined,
              'Extracted decisions are drafts — review before saving',
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF19CBD6)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'I understand, continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _consentBullet(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF19CBD6)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  // ── Session helper ────────────────────────────────────────────────────────

  Future<String> _getAccessToken() async {
    var session = supabase.auth.currentSession;
    if (session == null) {
      final refreshed = await supabase.auth.refreshSession();
      session = refreshed.session;
    }
    if (session == null) {
      throw Exception('Not authenticated — please sign in again.');
    }
    return session.accessToken;
  }

  // ── Shared category payload ───────────────────────────────────────────────

  List<Map<String, String>> get _categoriesPayload =>
      _workspaceCategories.map((c) => {'id': c.id, 'name': c.name}).toList();

  // ── Extraction helpers ────────────────────────────────────────────────────

  /// Calls the extract-decision-from-meeting function (Tab 1).
  Future<List<Map<String, dynamic>>> _callMeetingExtract(String notes) async {
    final token = await _getAccessToken();
    final response = await http.post(
      Uri.parse(_extractMeetingUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'meeting_notes': notes,
        'mode': 'multiple',
        'categories': _categoriesPayload,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final decisions = (data?['decisions'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    if (decisions == null || decisions.isEmpty) {
      throw Exception('No decisions could be extracted from your notes.');
    }
    return decisions;
  }

  /// Calls the extract-decisions-from-content function (Tabs 2, 3, 4).
  Future<List<Map<String, dynamic>>> _callContentExtract({
    required String content,
    required String contentType, // 'text' | 'url' | 'transcript'
  }) async {
    final token = await _getAccessToken();
    final response = await http.post(
      Uri.parse(_extractContentUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'content': content,
        'content_type': contentType,
        'mode': 'multiple',
        'categories': _categoriesPayload,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final decisions = (data?['decisions'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    if (decisions == null || decisions.isEmpty) {
      throw Exception('No decisions could be extracted.');
    }
    return decisions;
  }

  // ── Handle extraction result ──────────────────────────────────────────────

  void _handleDecisions(List<Map<String, dynamic>> decisions) {
    if (!mounted) return;
    if (decisions.length > 1) {
      setState(() {
        _isExtracting = false;
        _extractedDecisions = decisions;
        _selectedIndices = Set.from(List.generate(decisions.length, (i) => i));
        _inReviewMode = true;
      });
      return;
    }
    // Single decision
    setState(() => _isExtracting = false);
    final single = decisions.first;
    final result = <String, dynamic>{
      'title': single['title'] as String? ?? '',
      'description': single['description'] as String? ?? '',
      'stakes': single['stakes'] as String?,
      'category': single['category'] as String?,
      'fromMeeting': true,
    };
    if (widget.source == 'add_decision') {
      context.pop(result);
    } else {
      context.push(Routes.decisionsCreate, extra: result);
    }
  }

  // ── Tab 1: Extract from pasted notes ─────────────────────────────────────

  Future<void> _extractFromNotes() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) return;

    final consented = await _showAIConsentDialog();
    if (!consented || !mounted) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final decisions = await _callMeetingExtract(notes);
      _handleDecisions(decisions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Failed to extract decisions: $e';
      });
    }
  }

  // ── Tab 2: Extract from uploaded file ────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'docx', 'md', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final content = const Utf8Decoder(allowMalformed: true).convert(bytes);
    setState(() {
      _uploadedFileName = file.name;
      _uploadedFileContent = content;
      _errorMessage = null;
    });
  }

  Future<void> _extractFromFile() async {
    final content = _uploadedFileContent;
    if (content == null || content.isEmpty) return;

    final consented = await _showAIConsentDialog();
    if (!consented || !mounted) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final decisions = await _callContentExtract(
        content: content,
        contentType: 'text',
      );
      _handleDecisions(decisions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Failed to extract decisions: $e';
      });
    }
  }

  // ── Tab 3: Extract from link ──────────────────────────────────────────────

  bool _isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _extractFromLink() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) return;
    if (!_isValidUrl(url)) {
      setState(() => _linkError = 'Please enter a valid http/https URL');
      return;
    }

    final consented = await _showAIConsentDialog();
    if (!consented || !mounted) return;

    setState(() {
      _isExtracting = true;
      _linkError = null;
      _errorMessage = null;
    });

    try {
      final decisions = await _callContentExtract(
        content: url,
        contentType: 'url',
      );
      _handleDecisions(decisions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Failed to extract decisions: $e';
      });
    }
  }

  // ── Tab 4: Extract from audio/video ──────────────────────────────────────

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'mp4', 'wav', 'm4a', 'mov', 'webm', 'ogg'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _audioFileName = result.files.first.name;
      _transcriptController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _extractFromTranscript({required bool fromUploadCard}) async {
    final transcript = fromUploadCard
        ? _transcriptController.text.trim()
        : _transcriptPasteController.text.trim();
    if (transcript.isEmpty) return;

    final consented = await _showAIConsentDialog();
    if (!consented || !mounted) return;

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final decisions = await _callContentExtract(
        content: transcript,
        contentType: 'transcript',
      );
      _handleDecisions(decisions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Failed to extract decisions: $e';
      });
    }
  }

  // ── Create selected decisions ─────────────────────────────────────────────

  Future<void> _createSelected() async {
    final selected =
        _selectedIndices.map((i) => _extractedDecisions[i]).toList();
    if (selected.isEmpty) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final workspaceId = await ref.read(currentWorkspaceProvider.future);
      if (workspaceId == null) {
        throw Exception('No workspace found. Please contact support.');
      }

      final currentUserId = supabase.auth.currentUser?.id ?? 'unknown';

      debugPrint('[MeetingCapture] Creating ${selected.length} decision(s).'
          '\n  workspaceId=$workspaceId'
          '\n  userId=$currentUserId'
          '\n  categories available: ${_workspaceCategories.length}');

      for (final d in selected) {
        final rawConf = d['confidence'] ?? d['initial_confidence'];
        final initialConfidence = rawConf is int
            ? rawConf
            : rawConf is num
                ? rawConf.toInt()
                : null;

        final catName = d['category'] as String?;
        final categoryId = _resolveCategoryId(catName);

        debugPrint('[MeetingCapture] Insert payload:'
            '\n  title=${d['title']}'
            '\n  state=Draft'
            '\n  categoryName=$catName  →  categoryId=$categoryId'
            '\n  stakes=${d['stakes']}'
            '\n  initialConfidence=$initialConfidence');

        final input = CreateDecisionInput(
          workspaceId: workspaceId,
          title: d['title'] as String? ?? '',
          state: 'Draft',
          categoryId: categoryId,
          stakes: d['stakes'] as String?,
          initialConfidence: initialConfidence,
          descriptionEncrypted:
              (d['description'] as String?)?.isNotEmpty == true
                  ? d['description'] as String
                  : null,
        );

        final createdId =
            await ref.read(decisionsRepositoryProvider).createDecision(input);
        debugPrint('[MeetingCapture] Created decision id=$createdId');
      }

      ref.invalidate(decisionsProvider);

      if (!mounted) return;
      context.go(Routes.decisionsList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} '
            'decision${selected.length == 1 ? '' : 's'} '
            'created',
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('[MeetingCapture] _createSelected error: $e\n$stack');
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create decisions: $e'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  void _fillManually() => context.push(Routes.decisionsCreate);

  // ── Review step ───────────────────────────────────────────────────────────

  Widget _buildReviewStep(BuildContext context) {
    final selectedCount = _selectedIndices.length;
    return Scaffold(
      appBar: AppHeader(
        title: 'Review Extracted Decisions',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => setState(() {
            _inReviewMode = false;
            _isExtracting = false;
          }),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.surface,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.auto_awesome_outlined,
                            size: 20, color: Color(0xFF19CBD6)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_extractedDecisions.length} decisions were '
                            'extracted. Select the ones you want to create.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── DEBUG: tap to print resolution info ─────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _debugPrintResolution,
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: const Text('Debug info',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                    ),
                  ),
                ),

                ..._extractedDecisions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  final selected = _selectedIndices.contains(i);
                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: selected
                          ? const BorderSide(
                              color: Color(0xFF19CBD6), width: 1.5)
                          : const BorderSide(
                              color: Color(0xFFE2E8F0), width: 1),
                    ),
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: (_) => setState(() {
                        if (selected) {
                          _selectedIndices.remove(i);
                        } else {
                          _selectedIndices.add(i);
                        }
                      }),
                      activeColor: const Color(0xFF19CBD6),
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding:
                          const EdgeInsets.fromLTRB(8, 8, 16, 8),
                      title: Text(
                        d['title'] as String? ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((d['description'] as String?)?.isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 4),
                            Text(
                              d['description'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if ((d['stakes'] as String?)?.isNotEmpty == true ||
                              (d['category'] as String?)?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 6,
                                children: [
                                  if ((d['category'] as String?)
                                          ?.isNotEmpty ==
                                      true)
                                    _CategoryBadge(
                                        label: d['category'] as String),
                                  if ((d['stakes'] as String?)?.isNotEmpty ==
                                      true)
                                    _StakesBadge(
                                        label: d['stakes'] as String),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF19CBD6)),
                onPressed: (selectedCount == 0 || _isCreating)
                    ? null
                    : _createSelected,
                child: _isCreating
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
                          Text('Creating decisions...'),
                        ],
                      )
                    : Text(
                        'Create $selectedCount '
                        'decision${selectedCount == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _debugPrintResolution() async {
    final workspaceId = ref.read(currentWorkspaceProvider).valueOrNull;
    final userId = supabase.auth.currentUser?.id;
    debugPrint('[DEBUG] workspaceId=$workspaceId  userId=$userId');
    debugPrint('[DEBUG] categories (${_workspaceCategories.length}): '
        '${_workspaceCategories.map((c) => '${c.name}=${c.id}').join(', ')}');
    for (final d in _extractedDecisions) {
      final catName = d['category'] as String?;
      final catId = _resolveCategoryId(catName);
      debugPrint('[DEBUG] "${d['title']}"  '
          'category="$catName" → id=$catId  '
          'stakes=${d['stakes']}');
    }
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_inReviewMode) return _buildReviewStep(context);

    return Scaffold(
      appBar: AppHeader(
        title: 'Capture from Meeting',
        automaticallyImplyLeading: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: const Color(0xFF19CBD6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF19CBD6),
          tabs: const [
            Tab(text: 'Paste notes'),
            Tab(text: 'Upload file'),
            Tab(text: 'Add link'),
            Tab(text: 'Audio / Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPasteNotesTab(),
          _buildUploadFileTab(),
          _buildAddLinkTab(),
          _buildAudioVideoTab(),
        ],
      ),
    );
  }

  // ── TAB 1: Paste notes ────────────────────────────────────────────────────

  Widget _buildPasteNotesTab() {
    final wordCount = _wordCount;
    final hasEnoughWords = wordCount >= 100;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_outlined,
                    size: 20, color: Color(0xFF19CBD6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paste your meeting notes and AI will extract the '
                    'key decisions, descriptions, stakes, and categories.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),

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

        if (_errorMessage != null) _buildErrorCard(),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_isExtracting || _notesController.text.trim().isEmpty)
                ? null
                : _extractFromNotes,
            child: _isExtracting
                ? _loadingRow('Analysing meeting notes...')
                : const Text('Extract Decisions'),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _fillManually,
            child: const Text('Fill in manually'),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 2: Upload file ────────────────────────────────────────────────────

  Widget _buildUploadFileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.upload_file_outlined,
                    size: 20, color: Color(0xFF19CBD6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Upload a document and AI will extract decisions from it. '
                    'Supports PDF, TXT, DOCX, MD, and CSV.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),

        GestureDetector(
          onTap: _pickFile,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _uploadedFileName != null
                    ? const Color(0xFF19CBD6)
                    : const Color(0xFFCBD5E1),
                width: _uploadedFileName != null ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _uploadedFileName != null
                      ? Icons.description_outlined
                      : Icons.cloud_upload_outlined,
                  size: 36,
                  color: _uploadedFileName != null
                      ? const Color(0xFF19CBD6)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                Text(
                  _uploadedFileName ?? 'Click to select a file',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: _uploadedFileName != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _uploadedFileName != null
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_uploadedFileName == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'PDF · TXT · DOCX · MD · CSV',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ),
                if (_uploadedFileName != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _uploadedFileName = null;
                      _uploadedFileContent = null;
                    }),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ),
        ),

        if (_errorMessage != null) _buildErrorCard(),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed:
                (_isExtracting || _uploadedFileContent == null)
                    ? null
                    : _extractFromFile,
            child: _isExtracting
                ? _loadingRow('Analysing document...')
                : const Text('Extract Decisions'),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 3: Add link ───────────────────────────────────────────────────────

  Widget _buildAddLinkTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.link_outlined,
                    size: 20, color: Color(0xFF19CBD6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Enter a URL and AI will extract decisions from the page content.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),

        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                errorText: _linkError,
                prefixIcon: const Icon(Icons.link,
                    size: 18, color: Color(0xFF94A3B8)),
              ),
              onChanged: (_) => setState(() => _linkError = null),
            ),
          ),
        ),

        if (_errorMessage != null) _buildErrorCard(),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed:
                (_isExtracting || _linkController.text.trim().isEmpty)
                    ? null
                    : _extractFromLink,
            child: _isExtracting
                ? _loadingRow('Fetching and analysing...')
                : const Text('Extract Decisions'),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 4: Audio / Video ──────────────────────────────────────────────────

  Widget _buildAudioVideoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Card A: Upload audio/video ───────────────────────────────────
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_outlined,
                        size: 20, color: Color(0xFF19CBD6)),
                    const SizedBox(width: 8),
                    Text(
                      'Upload audio or video',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: _pickAudioFile,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _audioFileName != null
                            ? const Color(0xFF19CBD6)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _audioFileName != null
                              ? Icons.audio_file_outlined
                              : Icons.upload_outlined,
                          color: _audioFileName != null
                              ? const Color(0xFF19CBD6)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _audioFileName ?? 'Select audio or video file',
                            style: TextStyle(
                              color: _audioFileName != null
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF94A3B8),
                              fontWeight: _audioFileName != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_audioFileName != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () =>
                                setState(() => _audioFileName = null),
                          ),
                      ],
                    ),
                  ),
                ),

                if (_audioFileName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: Color(0xFF854D0E)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Transcription not yet supported. '
                            'Please paste your transcript below.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF854D0E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _transcriptController,
                    minLines: 4,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Paste the transcript here...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF19CBD6)),
                      onPressed: (_isExtracting ||
                              _transcriptController.text.trim().isEmpty)
                          ? null
                          : () =>
                              _extractFromTranscript(fromUploadCard: true),
                      child: _isExtracting
                          ? _loadingRow('Analysing transcript...')
                          : const Text(
                              'Extract Decisions',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Card B: Paste transcript ─────────────────────────────────────
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.article_outlined,
                        size: 20, color: Color(0xFF19CBD6)),
                    const SizedBox(width: 8),
                    Text(
                      'Paste transcript',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _transcriptPasteController,
                  minLines: 6,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: 'Paste meeting or call transcript here...',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF19CBD6)),
                    onPressed: (_isExtracting ||
                            _transcriptPasteController.text.trim().isEmpty)
                        ? null
                        : () => _extractFromTranscript(fromUploadCard: false),
                    child: _isExtracting
                        ? _loadingRow('Analysing transcript...')
                        : const Text(
                            'Extract Decisions',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_errorMessage != null) _buildErrorCard(),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildErrorCard() {
    return Card(
      color: AppColors.destructive.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline,
                size: 18, color: AppColors.destructive),
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
      ),
    );
  }

  Widget _loadingRow(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

// ── Category badge ────────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF0E7490)),
      ),
    );
  }
}

// ── Stakes badge ──────────────────────────────────────────────────────────────

class _StakesBadge extends StatelessWidget {
  const _StakesBadge({required this.label});
  final String label;

  static ({Color bg, Color fg}) _palette(String label) =>
      switch (label.toLowerCase()) {
        'low' => (
            bg: const Color(0xFFF0FDF4),
            fg: const Color(0xFF166534),
          ),
        'medium' => (
            bg: const Color(0xFFFEF9C3),
            fg: const Color(0xFF854D0E),
          ),
        'high' => (
            bg: const Color(0xFFFFF7ED),
            fg: const Color(0xFF9A3412),
          ),
        'critical' => (
            bg: const Color(0xFFFEF2F2),
            fg: const Color(0xFF991B1B),
          ),
        _ => (
            bg: const Color(0xFFF1F5F9),
            fg: const Color(0xFF64748B),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final c = _palette(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: c.fg),
      ),
    );
  }
}
