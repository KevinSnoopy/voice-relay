import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import '../state/history_entry.dart';
import 'theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final items = state.history;
        return Scaffold(
          appBar: AppBar(
            title: const Text('历史记录'),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () => _clear(context),
                  child: const Text('清空'),
                ),
            ],
          ),
          body: SafeArea(
            child: items.isEmpty
                ? const _EmptyHistory()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _HistoryTile(
                      entry: items[index],
                      onCopy: () => _copy(context, items[index].text),
                      onDelete: () => state.deleteHistory(items[index].id),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _clear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史记录？'),
        content: const Text('只删除手机上的本地记录，不影响 Mac 上的最近一条。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) await state.clearHistory();
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: vrPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.history_rounded, color: vrPrimary, size: 30),
            ),
            const SizedBox(height: 14),
            const Text('还没有历史记录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: vrInk)),
            const SizedBox(height: 6),
            const Text(
              '每次识别并尝试上屏后，文字会保存在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: vrMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.onCopy,
    required this.onDelete,
  });

  final HistoryEntry entry;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = entry.path == 'ime'
        ? vrPrimary
        : entry.ok
            ? vrSuccess
            : vrWarning;
    final icon = entry.path == 'ime'
        ? Icons.arrow_upward_rounded
        : entry.ok
            ? Icons.check_circle_rounded
            : Icons.error_outline_rounded;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: vrRecording.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: vrRecording),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: vrSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: vrBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.45, color: vrInk),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Meta(text: entry.timeLabel),
                      _Meta(text: entry.statusLabel, color: color),
                      if (entry.app != null && entry.app!.isNotEmpty) _Meta(text: entry.app!),
                      if (entry.ms > 0) _Meta(text: '${entry.ms} ms'),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '复制',
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 17, color: vrMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text, this.color = vrMuted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: color)),
    );
  }
}
