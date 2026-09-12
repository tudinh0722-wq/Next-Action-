import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/bulk_import_service.dart';

class AiImportSheet extends StatefulWidget {
  const AiImportSheet({super.key, required this.service, required this.onImported});

  final BulkImportService service;
  final void Function(ImportSummary) onImported;

  @override
  State<AiImportSheet> createState() => _AiImportSheetState();
}

class _AiImportSheetState extends State<AiImportSheet> {
  final _controller = TextEditingController();
  List<ImportRecord>? _records;
  bool _importing = false;
  ImportSummary? _result;

  static const _aiPrompt = '''Bạn là AI trích xuất dữ liệu lịch từ ảnh.

Hãy đọc TẤT CẢ các sự kiện nhìn thấy trong ảnh (thời khóa biểu, lịch học, lịch làm việc, giấy ghi lịch, ảnh chụp màn hình lịch...) và chuyển chúng thành đúng định dạng bên dưới để tôi copy vào ứng dụng NextA.

QUY TẮC:
1. Đọc toàn bộ ảnh và tạo một bản ghi cho MỖI sự kiện.
2. Không tự bịa hoặc suy đoán thông tin không có trong ảnh.
3. Ngày phải chuẩn hóa thành YYYY-MM-DD.
4. Giờ phải dùng định dạng 24 giờ HH:MM.
5. Nếu ảnh có cả ngày bắt đầu và kết thúc, giữ đúng ngày/giờ đó.
6. Nếu không thấy giờ kết thúc nhưng có giờ bắt đầu, để KẾT THÚC trống.
7. Địa điểm và ghi chú giữ nội dung có ý nghĩa từ ảnh, bỏ ký tự thừa.
8. ƯU TIÊN chỉ dùng 0, 1 hoặc 2. Nếu ảnh không thể hiện mức ưu tiên thì dùng 0.
9. BÁO TRƯỚC là số phút. Nếu ảnh không thể hiện nhắc trước thì để trống.
10. LẶP LẠI chỉ dùng: none, daily, weekly, weekdays, monthly. Nếu không lặp thì dùng none.
11. LẶP LẠI_SỐ là số lần lặp nếu ảnh thể hiện; nếu không có thì để trống.
12. Không thêm lời giải thích, không thêm Markdown, không dùng code block.
13. Chỉ trả về dữ liệu theo đúng mẫu. Mỗi sự kiện cách nhau bằng một dòng trống.

MẪU BẮT BUỘC:
TÊN: <tên sự kiện>
NGÀY: <YYYY-MM-DD>
BẮT ĐẦU: <HH:MM>
KẾT THÚC: <HH:MM>
ĐỊA ĐIỂM: <địa điểm hoặc để trống>
GHI CHÚ: <ghi chú hoặc để trống>
ƯU TIÊN: <0|1|2>
BÁO TRƯỚC: <số phút hoặc để trống>
LẶP LẠI: <none|daily|weekly|weekdays|monthly>
LẶP LẠI_SỐ: <số lần hoặc để trống>

Nếu ảnh có nhiều sự kiện, hãy xuất tất cả theo đúng mẫu trên. Nếu một trường không đọc được chắc chắn, để trống thay vì tự đoán.''';

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

  Future<void> _showPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Prompt đọc lịch từ ảnh'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: SelectableText(_aiPrompt, style: const TextStyle(fontSize: 12.5, height: 1.35)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _aiPrompt));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã copy prompt')));
              Navigator.pop(dialogContext);
            },
            child: const Text('Copy prompt'),
          ),
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
        ],
      ),
    );
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
    if (_result != null) {
      return _SuccessView(
        summary: _result!,
        onDone: () => Navigator.pop(context),
        onReset: _reset,
      );
    }
    if (_records != null) {
      return _PreviewView(
        records: _records!,
        importing: _importing,
        onConfirm: _confirm,
        onBack: () => setState(() => _records = null),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nhập nhiều sự kiện', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            'AI có thể đọc lịch từ ảnh rồi chuyển thành dữ liệu chuẩn để bạn copy vào đây.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _showPrompt,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Tạo prompt cho AI đọc ảnh'),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Dán kết quả AI vào đây...\n\nTÊN: Thiết kế phần mềm\nNGÀY: 2026-09-17\nBẮT ĐẦU: 09:30\nKẾT THÚC: 12:00\nĐỊA ĐIỂM: P1305-A1\n...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _parse, icon: const Icon(Icons.preview_outlined), label: const Text('Xem trước')),
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
              Expanded(child: Text('Xem trước: $validCount hợp lệ${invalidCount > 0 ? ' · $invalidCount lỗi' : ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
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
              if (r.isValid) return _ValidTile(event: r.event!);
              return _ErrorTile(record: r);
            },
          ),
        ),
        if (validCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: importing
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(onPressed: onConfirm, icon: const Icon(Icons.check_rounded), label: Text('Nhập $validCount sự kiện')),
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
  final dynamic event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = event;
    final start = e.start as DateTime;
    final end = e.end as DateTime;
    final timeStr = '${start.day}/${start.month}/${start.year}  ${_t(start)} – ${_t(end)}';
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.secondary.withValues(alpha: 0.4))),
      child: ListTile(
        leading: Icon(Icons.event_available_outlined, color: scheme.secondary),
        title: Text(e.title as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(timeStr + (e.location != null ? '\n${e.location}' : '')),
        isThreeLine: e.location != null,
      ),
    );
  }

  String _t(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: scheme.error.withValues(alpha: 0.5))),
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
  const _SuccessView({required this.summary, required this.onDone, required this.onReset});
  final ImportSummary summary;
  final VoidCallback onDone;
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
            Text('Đã nhập ${summary.imported} sự kiện${summary.skipped > 0 ? ' · Bỏ qua ${summary.skipped} lỗi' : ''}', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(onPressed: onReset, icon: const Icon(Icons.add_rounded), label: const Text('Nhập thêm')),
                const SizedBox(width: 10),
                FilledButton(onPressed: onDone, child: const Text('Xong')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
