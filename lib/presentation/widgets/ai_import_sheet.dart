import 'package:flutter/material.dart';

import '../../application/bulk_import_service.dart';

/// Embedded widget that replaces the old _BulkImportSlot placeholder.
/// It exposes an [onImported] callback so the parent sheet can propagate
/// confirmed events upward without coupling to the DB directly.
class AiImportSheet extends StatefulWidget {
  const AiImportSheet({super.key, required this.service, required this.onImported});

  final BulkImportService service;

  /// Called after the user confirms; receives the summary.
  final void Function(ImportSummary) onImported;

  @override
  State<AiImportSheet> createState() => _AiImportSheetState();
}

class _AiImportSheetState extends State<AiImportSheet> {
  final _controller = TextEditingController();
  List<ImportRecord>? _records;
  bool _importing = false;
  ImportSummary? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _records = widget.service.parse(text);
      _result = null;
    });
  }

  Future<void> _confirm() async {
    final records = _records;
    if (records == null) return;
    setState(() => _importing = true);
    try {
      final summary = await widget.service.confirm(records);
      if (!mounted) return;
      setState(() {
        _result = summary;
        _importing = false;
        _records = null;
        _controller.clear();
      });
      widget.onImported(summary);
    } catch (_) {
      if (!mounted) return;
      setState(() => _importing = false);
    }
  }

  void _reset() => setState(() {
        _records = null;
        _result = null;
        _controller.clear();
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_result != null) return _SuccessView(summary: _result!, onReset: _reset);
    if (_records != null) return _PreviewView(records: _records!, importing: _importing, onConfirm: _confirm, onBack: () => setState(() => _records = null));

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nhập nhiều sự kiện', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            'Mỗi sự kiện cách nhau bằng dòng trống. Các trường:\nTÊN · NGÀY · BẮT ĐẦU · KẾT THÚC · ĐỊA ĐIỂM · GHI CHÚ · ƯU TIÊN · BÁO TRƯỚC · LẶP LẠI · LẶP LẠI_SỐ',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'TÊN: Thiết kế phần mềm\nNGÀY: 2026-09-17\nBẮT ĐẦU: 09:30\nKẾT THÚC: 12:00\nĐỊA ĐIỂM: P1305-A1\n\nTÊN: Tiếng Anh CNTT\n...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Xem trước'),
          ),
        ],
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  const _PreviewView({required this.records, required this.importing, required this.onConfirm, required this.onBack});
  final List<ImportRecord> records;
  final bool importing;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validCount = records.where((r) => r.isValid).length;
    final invalidCount = records.length - validCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded), visualDensity: VisualDensity.compact),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Xem trước: $validCount hợp lệ${invalidCount > 0 ? ' · $invalidCount lỗi' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = records[i];
              if (r.isValid) {
                final e = r.event!;
                return _ValidTile(event: e);
              }
              return _ErrorTile(record: r);
            },
          ),
        ),
        if (validCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: importing
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check_rounded),
                    label: Text('Nhập $validCount sự kiện'),
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Text('Không có sự kiện hợp lệ để nhập.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

class _ValidTile extends StatelessWidget {
  const _ValidTile({required this.event});
  final event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = event;
    final start = e.start as DateTime;
    final end = e.end as DateTime;
    final timeStr =
        '${start.day}/${start.month}/${start.year}  ${_t(start)} – ${_t(end)}';
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.secondary.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: Icon(Icons.event_available_outlined, color: scheme.secondary),
        title: Text(e.title as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(timeStr + (e.location != null ? '\n${e.location}' : '')),
        isThreeLine: e.location != null,
      ),
    );
  }

  String _t(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.record});
  final ImportRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer.withValues(alpha: 0.4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bản ghi ${record.index + 1}: lỗi', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.error, fontSize: 13)),
                  const SizedBox(height: 2),
                  ...record.errors.map((e) => Text('• $e', style: TextStyle(fontSize: 12, color: scheme.onErrorContainer))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.summary, required this.onReset});
  final ImportSummary summary;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Nhập thành công!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text('Đã nhập ${summary.imported} sự kiện'
                '${summary.skipped > 0 ? ' · Bỏ qua ${summary.skipped} lỗi' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nhập thêm'),
            ),
          ],
        ),
      ),
    );
  }
}
