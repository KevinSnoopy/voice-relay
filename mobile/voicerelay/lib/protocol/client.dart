import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../transport/tcp_transport.dart';
import '../transport/transport.dart';
import 'wire.dart';

class RelayException implements Exception {
  RelayException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RelayResult {
  RelayResult({
    required this.ok,
    required this.text,
    required this.ms,
    required this.len,
    this.reason,
    this.path,
    this.asrMs,
    this.injectMs,
  });

  final bool ok;
  final String text;
  final int ms;
  final int len;
  final String? reason;
  final String? path;
  final int? asrMs;
  final int? injectMs;

  factory RelayResult.fromJson(Map<String, dynamic> json) {
    return RelayResult(
      ok: json['ok'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      ms: (json['ms'] as num?)?.toInt() ?? 0,
      len: (json['len'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      path: json['path'] as String?,
      asrMs: (json['asrMs'] as num?)?.toInt(),
      injectMs: (json['injectMs'] as num?)?.toInt(),
    );
  }
}

/// Implements docs/02 over any byte transport (TCP or BLE).
/// V1 sends 16 kHz mono PCM16 in 40 ms frames; the Mac also accepts Opus.
class VoiceRelayClient {
  VoiceRelayClient({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  RelayTransport? _transport;
  StreamSubscription<List<int>>? _subscription;
  final FrameDecoder _decoder = FrameDecoder();
  final List<Frame> _inbox = <Frame>[];
  final StreamController<Frame> _frames = StreamController<Frame>.broadcast();
  final List<int> _pcm = <int>[];
  Timer? _pingTimer;

  int _audioSeq = 0;
  int _packets = 0;
  int _audioMs = 0;
  int _cmdCounter = 0;
  String _mid = '';
  bool _connected = false;
  DateTime? _lastPongAt;

  String macName = '';
  String backend = 'A';
  String model = '';
  String transportName = '';

  void Function(int level)? onLevel;
  void Function(String app, String bundleId, String focus, bool editable)? onFrontApp;
  void Function(String backend, String model)? onState;
  void Function()? onDisconnected;
  void Function(String message)? onError;

  bool get isConnected => _connected;

  Future<void> connect({
    required String host,
    required int port,
    required String code,
    required String name,
  }) async {
    final transport = TcpTransport(host: host, port: port);
    await transport.connect();
    await connectWith(transport, code: code, name: name, label: '局域网');
  }

  Future<void> connectWith(
    RelayTransport transport, {
    required String code,
    required String name,
    String label = '传输',
  }) async {
    await close();
    _transport = transport;
    transportName = label;
    _mid = 'flutter-${_now().millisecondsSinceEpoch.toRadixString(16)}';
    _subscription = transport.incoming.listen(
      _onData,
      onError: (Object error) => _fail('连接出错：$error'),
      onDone: _handleDisconnect,
      cancelOnError: true,
    );

    try {
      _sendJson(MsgType.hello, <String, dynamic>{
        'v': protocolVersion,
        'client': 'flutter/1.0',
        'mid': _mid,
        'name': name,
        'caps': <String>['pcm16', 'cmd'],
      });

      final ack = await _waitFor(MsgType.helloAck, const Duration(seconds: 8));
      final ackJson = decodeJson(ack.payload);
      macName = ackJson['name'] as String? ?? 'Mac';
      backend = ackJson['backend'] as String? ?? 'A';
      model = ackJson['model'] as String? ?? '';
      final challenge = base64Decode(ackJson['challenge'] as String);
      final key = hkdfSha256(
        ikm: utf8.encode(code),
        salt: utf8.encode(ackJson['mid'] as String),
        info: utf8.encode('VoiceRelay-Pairing-v1'),
      );
      _send(Frame(type: MsgType.auth, payload: hmacSha256(key, challenge)));
      await _waitFor(MsgType.authOk, const Duration(seconds: 8));
      _connected = true;
      _lastPongAt = _now();
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final lastPong = _lastPongAt;
        if (lastPong == null || _now().difference(lastPong).inSeconds >= 15) {
          _fail('连接超时，未收到 Mac 心跳');
          return;
        }
        _send(Frame(
          type: MsgType.ping,
          payload: uint32le(_now().millisecondsSinceEpoch ~/ 1000),
        ));
      });
    } catch (error) {
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _transport?.close();
    _transport = null;
    _connected = false;
    _lastPongAt = null;
    _inbox.clear();
    _decoder.reset();
    _pcm.clear();
  }

  void startStream() {
    if (!_connected) throw RelayException('还没有连接 Mac');
    _pcm.clear();
    _audioSeq = 0;
    _packets = 0;
    _audioMs = 0;
    _sendJson(MsgType.streamStart, <String, dynamic>{'sr': 16000, 'ch': 1, 'codec': 'pcm16'});
  }

  /// Feed any-size PCM16 mono 16 kHz chunks; frames are cut to 40 ms.
  void sendPcm(List<int> chunk) {
    if (!_connected) return;
    _pcm.addAll(chunk);
    const frameBytes = 640 * 2;
    while (_pcm.length >= frameBytes) {
      final frame = _pcm.sublist(0, frameBytes);
      _pcm.removeRange(0, frameBytes);
      _sendAudio(frame);
    }
  }

  Future<RelayResult> stopStream() async {
    if (!_connected) throw RelayException('连接已断开');
    if (_pcm.isNotEmpty) {
      final rest = List<int>.from(_pcm);
      _pcm.clear();
      _sendAudio(rest);
    }
    _sendJson(MsgType.streamStop, <String, dynamic>{'n': _packets});
    final frame = await _waitFor(MsgType.result, const Duration(seconds: 5), failOnError: false);
    return RelayResult.fromJson(decodeJson(frame.payload));
  }

  Future<void> cancelStream() async {
    if (!_connected) return;
    _pcm.clear();
    try {
      await sendCommand(0x07);
    } catch (_) {
      // Cancelling is best effort.
    }
  }

  Future<Map<String, dynamic>> sendCommand(
    int subtype, {
    Map<String, dynamic> args = const <String, dynamic>{},
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!_connected) throw RelayException('连接已断开');
    final counter = ++_cmdCounter;
    final builder = BytesBuilder();
    builder.addByte(subtype);
    builder.add(uint32le(counter));
    builder.add(encodeJson(args));
    _send(Frame(type: MsgType.command, payload: builder.toBytes()));
    final frame = await _waitFor(MsgType.commandAck, timeout);
    final json = decodeJson(frame.payload);
    if ((json['sub'] as num?)?.toInt() != subtype) {
      throw RelayException('指令回执不匹配');
    }
    return json;
  }

  Future<Frame> _waitFor(MsgType type, Duration timeout, {bool failOnError = true}) {
    final existing = _inbox.indexWhere((frame) => frame.type == type);
    if (existing >= 0) {
      return Future<Frame>.value(_inbox.removeAt(existing));
    }
    if (!failOnError) {
      _inbox.removeWhere((frame) => frame.type == MsgType.error);
    } else {
      final errorIndex = _inbox.indexWhere((frame) => frame.type == MsgType.error);
      if (errorIndex >= 0) {
        return Future<Frame>.error(_errorFromFrame(_inbox.removeAt(errorIndex)));
      }
    }
    final completer = Completer<Frame>();
    late StreamSubscription<Frame> subscription;
    subscription = _frames.stream.listen((frame) {
      if (completer.isCompleted) return;
      if (frame.type == type) {
        final index = _inbox.indexOf(frame);
        if (index >= 0) _inbox.removeAt(index);
        completer.complete(frame);
        subscription.cancel();
      } else if (frame.type == MsgType.error) {
        if (failOnError) {
          completer.completeError(_errorFromFrame(frame));
          subscription.cancel();
        } else {
          final index = _inbox.indexOf(frame);
          if (index >= 0) _inbox.removeAt(index);
        }
      }
    });
    return completer.future.timeout(timeout, onTimeout: () {
      subscription.cancel();
      throw RelayException('等待 Mac 回应超时');
    });
  }

  void _sendAudio(List<int> samples) {
    final builder = BytesBuilder();
    builder.add(uint16le(_audioSeq & 0xFFFF));
    builder.add(uint32le(_audioMs));
    builder.add(samples);
    _send(Frame(
      type: MsgType.audio,
      payload: builder.toBytes(),
      seq: _audioSeq & 0x3F,
    ));
    _audioSeq++;
    _packets++;
    _audioMs += 40;
  }

  void _sendJson(MsgType type, Map<String, dynamic> value) {
    _send(Frame(type: type, payload: encodeJson(value)));
  }

  void _send(Frame frame) {
    final transport = _transport;
    if (transport == null) return;
    try {
      transport.send(frame.encode());
    } catch (error) {
      _fail('发送失败：$error');
    }
  }

  void _onData(List<int> data) {
    try {
      for (final frame in _decoder.add(data)) {
        switch (frame.type) {
          case MsgType.pong:
            _lastPongAt = _now();
            break;
          case MsgType.level:
            final json = decodeJson(frame.payload);
            onLevel?.call((json['level'] as num?)?.toInt() ?? 0);
            break;
          case MsgType.state:
            final json = decodeJson(frame.payload);
            backend = json['backend'] as String? ?? backend;
            model = json['model'] as String? ?? model;
            onState?.call(backend, model);
            onFrontApp?.call(
              json['app'] as String? ?? '',
              json['bundleId'] as String? ?? '',
              json['focus'] as String? ?? '',
              json['editable'] as bool? ?? true,
            );
            break;
          case MsgType.helloAck:
          case MsgType.authOk:
          case MsgType.commandAck:
          case MsgType.result:
          case MsgType.error:
            _inbox.add(frame);
            break;
          default:
            break;
        }
        _frames.add(frame);
      }
    } catch (error) {
      _fail('协议解析失败：$error');
    }
  }

  RelayException _errorFromFrame(Frame frame) {
    try {
      final json = decodeJson(frame.payload);
      final code = (json['code'] as num?)?.toInt() ?? 0;
      return RelayException('0x${code.toRadixString(16)} ${json['message'] ?? '错误'}');
    } catch (_) {
      return RelayException('Mac 返回错误');
    }
  }

  void _handleDisconnect() {
    final wasConnected = _connected;
    _connected = false;
    _lastPongAt = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    if (wasConnected) onDisconnected?.call();
  }

  void _fail(String message) {
    _handleDisconnect();
    onError?.call(message);
    unawaited(close());
  }
}
