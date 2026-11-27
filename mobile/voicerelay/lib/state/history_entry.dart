import 'dart:convert';

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.at,
    required this.text,
    required this.ok,
    required this.ms,
    this.path,
    this.reason,
    this.app,
  });

  final String id;
  final DateTime at;
  final String text;
  final bool ok;
  final int ms;
  final String? path;
  final String? reason;
  final String? app;

  String get statusLabel {
    if (path == 'ime') return '已发送到输入法';
    return ok ? '已上屏' : '未送达';
  }

  String get timeLabel {
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'at': at.toIso8601String(),
        'text': text,
        'ok': ok,
        'ms': ms,
        'path': path,
        'reason': reason,
        'app': app,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        text: json['text'] as String? ?? '',
        ok: json['ok'] as bool? ?? false,
        ms: (json['ms'] as num?)?.toInt() ?? 0,
        path: json['path'] as String?,
        reason: json['reason'] as String?,
        app: json['app'] as String?,
      );

  static String encodeList(List<HistoryEntry> items) =>
      jsonEncode(items.map((item) => item.toJson()).toList());

  static List<HistoryEntry> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <HistoryEntry>[];
    try {
      final value = jsonDecode(raw);
      if (value is! List) return <HistoryEntry>[];
      return value
          .whereType<Map<String, dynamic>>()
          .map(HistoryEntry.fromJson)
          .toList();
    } catch (_) {
      return <HistoryEntry>[];
    }
  }
}
