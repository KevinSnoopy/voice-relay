import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicerelay/protocol/client.dart';
import 'package:voicerelay/protocol/wire.dart';
import 'package:voicerelay/transport/transport.dart';

void main() {
  test('IME submission is not parsed as confirmed delivery', () {
    final result = RelayResult.fromJson(<String, dynamic>{
      'ok': false,
      'text': '',
      'ms': 12,
      'len': 0,
      'reason': 'ime_unconfirmed',
      'path': 'ime',
      'asrMs': 0,
      'injectMs': 0,
    });

    expect(result.ok, isFalse);
    expect(result.reason, 'ime_unconfirmed');
    expect(result.path, 'ime');
    expect(result.text, isEmpty);
  });

  test('confirmed AX delivery keeps its result metadata', () {
    final result = RelayResult.fromJson(<String, dynamic>{
      'ok': true,
      'text': '你好',
      'ms': 420,
      'len': 2,
      'reason': null,
      'path': 'ax',
      'asrMs': 300,
      'injectMs': 20,
    });

    expect(result.ok, isTrue);
    expect(result.text, '你好');
    expect(result.ms, 420);
    expect(result.asrMs, 300);
    expect(result.injectMs, 20);
  });

  test('frame decoder accepts fragmented pong and state frames', () {
    final pong = Frame(type: MsgType.pong, payload: uint32le(123)).encode();
    final state = Frame(
      type: MsgType.state,
      payload: encodeJson(<String, dynamic>{
        'app': '备忘录',
        'bundleId': 'com.apple.TextEdit',
        'backend': 'A',
        'model': '已加载',
        'connected': true,
        'port': 8787,
        'focus': '正文',
        'editable': true,
      }),
    ).encode();
    final decoder = FrameDecoder();
    final bytes = <int>[...pong, ...state];

    expect(decoder.add(bytes.sublist(0, 3)), isEmpty);
    final frames = decoder.add(bytes.sublist(3));

    expect(frames.map((frame) => frame.type), [MsgType.pong, MsgType.state]);
    expect(decodeJson(frames[1].payload)['backend'], 'A');
    expect(decodeJson(frames[1].payload)['model'], '已加载');
  });

  test('wire JSON preserves Chinese text', () {
    final decoded = decodeJson(encodeJson(<String, dynamic>{'text': '已发送到输入法'}));
    expect(decoded['text'], '已发送到输入法');
    expect(jsonEncode(decoded), contains('已发送到输入法'));
  });

  test('missing pong disconnects after heartbeat timeout', () {
    fakeAsync((async) {
      final transport = _FakeTransport(respondToPing: false);
      var now = DateTime(2026, 1, 1);
      final client = VoiceRelayClient(now: () => now);
      var disconnected = false;
      String? error;
      client.onDisconnected = () => disconnected = true;
      client.onError = (message) => error = message;

      final connecting = client.connectWith(
        transport,
        code: '123456',
        name: '测试手机',
      );
      async.flushMicrotasks();
      expect(client.isConnected, isTrue);

      now = now.add(const Duration(seconds: 16));
      async.elapse(const Duration(seconds: 16));
      async.flushMicrotasks();

      expect(client.isConnected, isFalse);
      expect(disconnected, isTrue);
      expect(error, contains('心跳'));
      connecting.then((_) {}, onError: (Object _) {});
    });
  });

  test('pong keeps the connection alive', () {
    fakeAsync((async) {
      final transport = _FakeTransport(respondToPing: true);
      var now = DateTime(2026, 1, 1);
      final client = VoiceRelayClient(now: () => now);
      var disconnected = false;
      client.onDisconnected = () => disconnected = true;

      final connecting = client.connectWith(
        transport,
        code: '123456',
        name: '测试手机',
      );
      async.flushMicrotasks();
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
      }

      expect(client.isConnected, isTrue);
      expect(disconnected, isFalse);
      connecting.then((_) {}, onError: (Object _) {});
      client.close();
      async.flushMicrotasks();
    });
  });
}

class _FakeTransport implements RelayTransport {
  _FakeTransport({required this.respondToPing});

  final bool respondToPing;
  final _incoming = StreamController<List<int>>.broadcast(sync: true);
  final _decoder = FrameDecoder();

  @override
  Stream<List<int>> get incoming => _incoming.stream;

  @override
  Future<void> connect() async {}

  @override
  void send(List<int> bytes) {
    for (final frame in _decoder.add(bytes)) {
      switch (frame.type) {
        case MsgType.hello:
          _incoming.add(Frame(
            type: MsgType.helloAck,
            payload: encodeJson(<String, dynamic>{
              'v': 1,
              'name': '测试 Mac',
              'mid': 'test-mac',
              'backend': 'A',
              'perms': <String, bool>{'accessibility': true},
              'challenge': base64Encode(List<int>.filled(32, 1)),
              'model': '已加载',
            }),
          ).encode());
          break;
        case MsgType.auth:
          _incoming.add(Frame(
            type: MsgType.authOk,
            payload: encodeJson(<String, dynamic>{'session': 'test-session'}),
          ).encode());
          break;
        case MsgType.ping:
          if (respondToPing) {
            _incoming.add(Frame(type: MsgType.pong, payload: frame.payload).encode());
          }
          break;
        default:
          break;
      }
    }
  }

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) await _incoming.close();
  }
}
