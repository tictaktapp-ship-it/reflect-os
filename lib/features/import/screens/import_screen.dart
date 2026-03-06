import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:reflect_os/core/design_system/tokens.dart';
import 'package:reflect_os/core/providers/current_workspace_provider.dart';
import 'package:reflect_os/core/routing/routes.dart';
import 'package:reflect_os/core/supabase/supabase_client.dart';
import 'package:reflect_os/features/decisions/data/models/category.dart';
import 'package:reflect_os/features/decisions/data/models/create_decision_input.dart';
import 'package:reflect_os/features/decisions/providers/decisions_provider.dart';

// ── Column mapping targets ─────────────────────────────────────────────────────

enum _ColumnTarget {
  skip,
  title,
  description,
  stakes,
  category,
  decisionDeadline,
}

extension _ColumnTargetLabel on _ColumnTarget {
  String get label => switch (this) {
        _ColumnTarget.skip => 'Skip',
        _ColumnTarget.title => 'Title (required)',
        _ColumnTarget.description => 'Description',
        _ColumnTarget.stakes => 'Stakes',
        _ColumnTarget.category => 'Category',
        _ColumnTarget.decisionDeadline => 'Decision Deadline',
      };
}

// ── Import step ────────────────────────────────────────────────────────────────

enum _ImportStep { upload, preview, importing, done }

// ── Screen ─────────────────────────────────────────────────────────────────────

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _ImportStep _step = _ImportStep.upload;
  String? _fileName;

  List<String> _headers = [];
  List<List<String>> _dataRows = [];

  // column index → target field
  Map<int, _ColumnTarget> _columnMapping = {};

  int _importProgress = 0;
  int _importTotal = 0;
  int _importedCount = 0;
  int _skippedCount = 0;

  bool get _titleMapped =>
      _columnMapping.values.contains(_ColumnTarget.title);

  // ── File picker ───────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;
    final text = String.fromCharCodes(bytes);
    if (mounted) _parseCSV(file.name, text);
  }

  // ── CSV parsing ───────────────────────────────────────────────────────────

  void _parseCSV(String fileName, String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV file is empty.')),
      );
      return;
    }

    final headers =
        lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
    final dataRows = lines
        .skip(1)
        .map((line) =>
            line.split(',').map((c) => c.trim().replaceAll('"', '')).toList())
        .toList();

    // Auto-detect mappings from header names
    final mapping = <int, _ColumnTarget>{};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase();
      if (h == 'title' || h == 'decision' || h == 'name') {
        mapping[i] = _ColumnTarget.title;
      } else if (h.contains('desc') || h == 'context' || h == 'detail') {
        mapping[i] = _ColumnTarget.description;
      } else if (h == 'stakes' || h == 'priority' || h == 'importance') {
        mapping[i] = _ColumnTarget.stakes;
      } else if (h == 'category' || h == 'type') {
        mapping[i] = _ColumnTarget.category;
      } else if (h.contains('deadline') ||
          h.contains('due') ||
          h.contains('date')) {
        mapping[i] = _ColumnTarget.decisionDeadline;
      } else {
        mapping[i] = _ColumnTarget.skip;
      }
    }

    setState(() {
      _fileName = fileName;
      _headers = headers;
      _dataRows = dataRows;
      _columnMapping = mapping;
      _step = _ImportStep.preview;
    });
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _doImport() async {
    final workspaceId = await ref.read(currentWorkspaceProvider.future);
    if (workspaceId == null) return;

    // Load categories for name → ID resolution
    List<Category> categories = [];
    try {
      categories = await ref.read(categoriesProvider.future);
    } catch (_) {
      // Non-fatal — category mapping will be skipped
    }

    final repo = ref.read(decisionsRepositoryProvider);

    setState(() {
      _step = _ImportStep.importing;
      _importTotal = _dataRows.length;
      _importProgress = 0;
      _importedCount = 0;
      _skippedCount = 0;
    });

    // Build column index lookups (first match wins)
    int? idxFor(_ColumnTarget target) {
      for (final entry in _columnMapping.entries) {
        if (entry.value == target) return entry.key;
      }
      return null;
    }

    final titleIdx = idxFor(_ColumnTarget.title);
    final descIdx = idxFor(_ColumnTarget.description);
    final stakesIdx = idxFor(_ColumnTarget.stakes);
    final categoryIdx = idxFor(_ColumnTarget.category);
    final deadlineIdx = idxFor(_ColumnTarget.decisionDeadline);

    int imported = 0;
    int skipped = 0;

    for (int i = 0; i < _dataRows.length; i++) {
      if (mounted) setState(() => _importProgress = i + 1);

      final row = _dataRows[i];
      String cell(int? idx) =>
          (idx != null && idx < row.length) ? row[idx].trim() : '';

      final title = cell(titleIdx);
      if (title.isEmpty) {
        skipped++;
        continue;
      }

      final description = cell(descIdx);
      final stakesRaw = cell(stakesIdx);
      final categoryName = cell(categoryIdx);
      final deadlineRaw = cell(deadlineIdx);

      // Resolve stakes (must be exact enum value)
      const validStakes = ['Low', 'Medium', 'High', 'Critical'];
      final stakes = stakesRaw.isEmpty
          ? null
          : validStakes
              .where((s) => s.toLowerCase() == stakesRaw.toLowerCase())
              .firstOrNull;

      // Resolve category by name
      final categoryId = categoryName.isEmpty
          ? null
          : categories
              .where(
                  (c) => c.name.toLowerCase() == categoryName.toLowerCase())
              .map((c) => c.id)
              .firstOrNull;

      // Parse deadline (ISO-8601 or yyyy-MM-dd)
      DateTime? deadline;
      if (deadlineRaw.isNotEmpty) {
        try {
          deadline = DateTime.parse(deadlineRaw);
        } catch (_) {
          // Invalid date — skip field
        }
      }

      try {
        await repo.createDecision(CreateDecisionInput(
          workspaceId: workspaceId,
          title: title,
          descriptionEncrypted: description.isEmpty ? null : description,
          stakes: stakes,
          categoryId: categoryId,
          decisionDeadline: deadline,
        ));
        imported++;
      } catch (_) {
        skipped++;
      }
    }

    // Record the import job (best-effort)
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('import_jobs').insert({
          'workspace_id': workspaceId,
          'created_by_user_id': userId,
          'source_type': 'csv',
          'status': 'completed',
          'total_rows': _dataRows.length,
          'processed_rows': imported,
          if (skipped > 0)
            'error_summary':
                '$skipped row${skipped == 1 ? '' : 's'} skipped (missing title or invalid data)',
        });
      }
    } catch (_) {
      // Non-fatal
    }

    ref.invalidate(decisionsProvider);

    if (mounted) {
      setState(() {
        _importedCount = imported;
        _skippedCount = skipped;
        _step = _ImportStep.done;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: switch (_step) {
        _ImportStep.upload => _UploadStep(onPickFile: _pickFile),
        _ImportStep.preview => _PreviewStep(
            fileName: _fileName ?? '',
            headers: _headers,
            dataRows: _dataRows,
            columnMapping: _columnMapping,
            titleMapped: _titleMapped,
            onMappingChanged: (idx, target) {
              setState(() => _columnMapping[idx] = target);
            },
            onImport: _titleMapped ? _doImport : null,
          ),
        _ImportStep.importing => _ImportingStep(
            progress: _importProgress,
            total: _importTotal,
          ),
        _ImportStep.done => _DoneStep(
            importedCount: _importedCount,
            skippedCount: _skippedCount,
            onViewDecisions: () => context.go(Routes.decisionsList),
          ),
      },
    );
  }
}

// ── Step 1 — Upload ────────────────────────────────────────────────────────────

class _UploadStep extends StatelessWidget {
  const _UploadStep({required this.onPickFile});
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: onPickFile,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_file_outlined,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Upload CSV file',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click to select a .csv file from your device',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CSV must include a header row. Supported columns:\n'
              'Title (required), Description, Stakes, Category, Decision Deadline',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2 — Preview & Map ─────────────────────────────────────────────────────

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.fileName,
    required this.headers,
    required this.dataRows,
    required this.columnMapping,
    required this.titleMapped,
    required this.onMappingChanged,
    required this.onImport,
  });

  final String fileName;
  final List<String> headers;
  final List<List<String>> dataRows;
  final Map<int, _ColumnTarget> columnMapping;
  final bool titleMapped;
  final void Function(int colIdx, _ColumnTarget target) onMappingChanged;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final previewRows = dataRows.take(5).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // File info
        Card(
          color: Theme.of(context).colorScheme.surface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(fileName),
            subtitle: Text(
              '${dataRows.length} data row${dataRows.length == 1 ? '' : 's'} detected',
            ),
          ),
        ),

        // Column mapping
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Map columns',
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
          child: Column(
            children: [
              for (int i = 0; i < headers.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              headers[i],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (previewRows.isNotEmpty)
                              Text(
                                i < previewRows[0].length
                                    ? previewRows[0][i]
                                    : '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      DropdownButton<_ColumnTarget>(
                        value: columnMapping[i] ?? _ColumnTarget.skip,
                        underline: const SizedBox.shrink(),
                        onChanged: (target) {
                          if (target != null) onMappingChanged(i, target);
                        },
                        items: _ColumnTarget.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Preview table
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Preview (first ${previewRows.length} rows)',
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
          margin: const EdgeInsets.only(bottom: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 48,
              columnSpacing: 20,
              columns: headers
                  .map((h) => DataColumn(
                        label: Text(
                          h,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ))
                  .toList(),
              rows: previewRows
                  .map((row) => DataRow(
                        cells: List.generate(
                          headers.length,
                          (i) => DataCell(
                            Text(
                              i < row.length ? row[i] : '',
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),

        // Validation hint
        if (!titleMapped)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'Map at least one column to "Title (required)" before importing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                ),
              ],
            ),
          ),

        // Import button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.upload_outlined),
            label: Text(
              'Import ${dataRows.length} decision${dataRows.length == 1 ? '' : 's'} as Drafts',
            ),
            onPressed: onImport,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {},
            // handled by popping via AppBar back button
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

// ── Step 3 — Importing ────────────────────────────────────────────────────────

class _ImportingStep extends StatelessWidget {
  const _ImportingStep({required this.progress, required this.total});
  final int progress;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Importing $progress of $total…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? progress / total : 0,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4 — Done ─────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.importedCount,
    required this.skippedCount,
    required this.onViewDecisions,
  });
  final int importedCount;
  final int skippedCount;
  final VoidCallback onViewDecisions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: AppColors.success),
            const SizedBox(height: 20),
            Text(
              '$importedCount decision${importedCount == 1 ? '' : 's'} imported as Drafts',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (skippedCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Text(
                    '$skippedCount row${skippedCount == 1 ? '' : 's'} skipped (missing required fields)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('View Decisions'),
              onPressed: onViewDecisions,
            ),
          ],
        ),
      ),
    );
  }
}
