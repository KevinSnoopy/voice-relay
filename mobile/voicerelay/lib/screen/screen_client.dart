import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../protocol/wire.dart' show hkdfSha256, hmacSha256;

class ScreenWindow {
  ScreenWindow({
    required this.id,
    required this.app,
    required this.title,
    required this.width,
    required this.height,
    required this.focused,
    required this.current,
  });

  final int id;
  final String app;
  final String title;
  final int width;
  final int height;
  final bool focused;
  final bool current;

  factory ScreenWindow.fromJson(Map<String, dynamic> json) => ScreenWindow(
        id: (json['id'] as num?)?.toInt() ?? 0,
        app: json['app'] as String? ?? '未知 App',
        title: json['title'] as String? ?? '',
        width: (json['w'] as num?)?.toInt() ?? 0,
        height: (json['h'] as num?)?.toInt() ?? 0,
        focused: json['focused'] as bool? ?? false,
        current: json['current'] as bool? ?? false,
      );

  String get displayTitle => title.trim().isEmpty ? app : title.trim();
}

class ScreenState {
  ScreenState({
    required this.state,
    required this.follow,
    required this.fps,
    this.windowId,
    this.title,
    this.app,
    this.error,
  });

  final String state;
  final bool follow;
  final int fps;
  final int? windowId;
  final String? title;
  final String? app;
  final String? error;

  factory ScreenState.fromJson(Map<String, dynamic> json) => ScreenState(
        state: json['state'] as String? ?? 'unknown',
        follow: json['follow'] as bool? ?? true,
        fps: (json['fps'] as num?)?.toInt() ?? 30,
        windowId: (json['windowId'] as num?)?.toInt(),
        title: json['title'] as String?,
        app: json['app'] as String?,
        error: json['message'] as String?,
      );
}

/// Dedicated newline-JSON screen channel on Mac's port+1, plus a WebRTC video track.
class ScreenClient extends ChangeNotifier {
  ScreenClient({
    required this.host,
    required this.port,
    required this.code,
  });

  final String host;
  final int port;
  final String code;

  final List<ScreenWindow> windows = <ScreenWindow>[];
  final Map<int, Uint8List> thumbnails = <int, Uint8List>{};

  ScreenState? state;
  String? error;
  bool connected = false;
  bool authenticated = false;
  bool remoteDescriptionSet = false;
  MediaStream? remoteStream;

  RTCPeerConnection? _peer;
  Socket? _socket;
  StreamSubscription<String>? _subscription;
  final StringBuffer _buffer = StringBuffer();
  final Map<String, List<Completer<Map<String, dynamic>>>> _pending = {};
  final Map<String, List<Map<String, dynamic>>> _inbox = {};
  final List<Map<String, dynamic>> _pendingRemoteIce = [];
  String _mid = '';
  bool _disposed = false;

  Future<void> connect() async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;
    _subscription = socket.cast<List<int>>().transform(utf8.decoder).listen(
      _onText,
      onError: (Object value) => _fail('屏幕通道连接出错：$value'),
      onDone: () {
        if (!_disposed) _fail('屏幕通道已断开');
      },
      cancelOnError: true,
    );

    _mid = 'flutter-screen-${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}';
    _send(<String, dynamic>{
      'op': 'hello',
      'v': 1,
      'mid': _mid,
      'name': '语音遥控',
    });
    final challenge = await _waitFor('challenge', const Duration(seconds: 8));
    final macMid = challenge['mid'] as String? ?? '';
    final key = hkdfSha256(
      ikm: utf8.encode(code),
      salt: utf8.encode(macMid),
      info: utf8.encode('VoiceRelay-Pairing-v1'),
    );
    final challengeBytes = base64Decode(challenge['challenge'] as String? ?? '');
    final mac = hmacSha256(key, challengeBytes);
    _send(<String, dynamic>{'op': 'auth', 'mac': base64Encode(mac)});
    await _waitFor('auth_ok', const Duration(seconds: 8));
    authenticated = true;
    connected = true;
    notifyListeners();
  }

  Future<void> start({int width = 1600, int height = 1000, int fps = 30}) async {
    if (!authenticated) throw StateError('屏幕通道未认证');
    await WebRTC.initialize(options: <String, dynamic>{'zeroPlayoutDelay': true});
    final peer = await createPeerConnection(<String, dynamic>{
      'iceServers': <Map<String, dynamic>>[],
      'sdpSemantics': 'unifiedPlan',
      'bundlePolicy': 'max-bundle',
    });
    _peer = peer;
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send(<String, dynamic>{
        'op': 'ice',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };
    peer.onTrack = (event) async {
      MediaStream? stream;
      if (event.streams.isNotEmpty) {
        stream = event.streams.first;
      } else {
        stream = await createLocalMediaStream('screen');
        await stream.addTrack(event.track);
      }
      remoteStream = stream;
      notifyListeners();
    };
    peer.onConnectionState = (value) {
      if (value == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        error = 'WebRTC 连接失败';
        notifyListeners();
      }
    };

    _send(<String, dynamic>{
      'op': 'start',
      'width': width,
      'height': height,
      'fps': fps,
      'follow': true,
    });
    final offer = await _waitFor('offer', const Duration(seconds: 12));
    final sdp = offer['sdp'] as String? ?? '';
    await peer.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    remoteDescriptionSet = true;
    for (final ice in _pendingRemoteIce) {
      await _addRemoteIce(ice);
    }
    _pendingRemoteIce.clear();
    final answer = await peer.createAnswer();
    await peer.setLocalDescription(answer);
    _send(<String, dynamic>{'op': 'answer', 'sdp': answer.sdp});
  }

  void requestWindows() {
    _send(<String, dynamic>{'op': 'list'});
  }

  void selectWindow(int windowId, {bool follow = false}) {
    _send(<String, dynamic>{'op': 'select', 'windowId': windowId, 'follow': follow});
  }

  void switchWindow(int windowId) {
    _send(<String, dynamic>{'op': 'switch', 'windowId': windowId, 'follow': false});
  }

  void setFollow(bool enabled) {
    _send(<String, dynamic>{'op': 'follow', 'enabled': enabled});
  }

  Future<void> stop() async {
    _send(<String, dynamic>{'op': 'stop'});
  }

  void _onText(String chunk) {
    _buffer.write(chunk);
    var value = _buffer.toString();
    var newline = value.indexOf('\n');
    while (newline >= 0) {
      final line = value.substring(0, newline).trim();
      value = value.substring(newline + 1);
      if (line.isNotEmpty) _onMessage(line);
      newline = value.indexOf('\n');
    }
    _buffer
      ..clear()
      ..write(value);
  }

  void _onMessage(String line) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final op = json['op'] as String? ?? '';
    if (op == 'ice') {
      if (remoteDescriptionSet) {
        unawaited(_addRemoteIce(json));
      } else {
        _pendingRemoteIce.add(json);
      }
      return;
    }
    final waiters = _pending[op];
    if (waiters != null && waiters.isNotEmpty) {
      waiters.removeAt(0).complete(json);
      return;
    }
    if (op == 'challenge' || op == 'auth_ok' || op == 'offer') {
      _inbox.putIfAbsent(op, () => <Map<String, dynamic>>[]).add(json);
      return;
    }
    switch (op) {
      case 'windows':
        final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
        windows
          ..clear()
          ..addAll(raw.map((item) => ScreenWindow.fromJson(item as Map<String, dynamic>)));
        notifyListeners();
        break;
      case 'thumb':
        final id = (json['id'] as num?)?.toInt() ?? 0;
        final data = json['data'] as String? ?? '';
        try {
          thumbnails[id] = base64Decode(data);
          notifyListeners();
        } catch (_) {}
        break;
      case 'state':
      case 'window':
        state = ScreenState.fromJson(json);
        notifyListeners();
        break;
      case 'error':
        error = json['message'] as String? ?? '屏幕共享错误';
        notifyListeners();
        break;
    }
  }

  Future<void> _addRemoteIce(Map<String, dynamic> json) async {
    final peer = _peer;
    if (peer == null) return;
    final candidate = json['candidate'] as String? ?? '';
    if (candidate.isEmpty) return;
    await peer.addCandidate(RTCIceCandidate(
      candidate,
      json['sdpMid'] as String?,
      (json['sdpMLineIndex'] as num?)?.toInt(),
    ));
  }

  Future<Map<String, dynamic>> _waitFor(String op, Duration timeout) {
    final queued = _inbox[op];
    if (queued != null && queued.isNotEmpty) {
      return Future<Map<String, dynamic>>.value(queued.removeAt(0));
    }
    final completer = Completer<Map<String, dynamic>>();
    _pending.putIfAbsent(op, () => <Completer<Map<String, dynamic>>>[]).add(completer);
    return completer.future.timeout(timeout, onTimeout: () {
      _pending[op]?.remove(completer);
      throw TimeoutException('等待 Mac 屏幕回应超时：$op');
    });
  }

  void _send(Map<String, dynamic> value) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(utf8.encode('${jsonEncode(value)}\n'));
    } catch (error) {
      _fail('发送屏幕指令失败：$error');
    }
  }

  void _fail(String message) {
    if (_disposed) return;
    error = message;
    connected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _socket?.destroy();
    _peer?.close();
    _peer = null;
    remoteStream?.dispose();
    remoteStream = null;
    super.dispose();
  }
}
