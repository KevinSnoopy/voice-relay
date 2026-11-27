import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/recorder.dart';
import '../protocol/client.dart';
import 'history_entry.dart';
import '../transport/ble_transport.dart';

enum Phase { disconnected, connecting, connected, listening, recognizing, delivered, submitted, failed }

enum AppScreen { welcome, permissions, discover, home }

class QuickCommandResult {
  const QuickCommandResult({required this.ok, required this.message, required this.subtype});

  final bool ok;
  final String message;
  final int subtype;
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final VoiceRelayClient client = VoiceRelayClient();
  final MicRecorder recorder = MicRecorder();

  Phase phase = Phase.disconnected;
  AppScreen screen = AppScreen.welcome;
  String host = '';
  int port = 8787;
  String code = '';
  String macName = '';
  String transportLabel = '局域网';
  String bleDeviceId = '';
  String frontApp = '';
  String frontBundle = '';
  String frontFocus = '';
  bool frontEditable = true;
  String recentText = '';
  List<HistoryEntry> history = <HistoryEntry>[];
  int latencyMs = 0;
  int level = 0;
  String? error;
  String? notice;
  bool busy = false;
  bool controlBusy = false;
  bool micGranted = false;
  bool localNetworkGranted = false;
  bool bluetoothGranted = false;
  bool cameraGranted = false;
  bool permissionsLoaded = false;
  DateTime? recentAt;
  DateTime? startedAt;

  Timer? _ticker;
  bool _cancelBySwipe = false;
  bool _recordingStarting = false;
  bool _stopRequested = false;

  bool get connected => client.isConnected;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    client.onLevel = (value) {
      level = value;
      notifyListeners();
    };
    client.onFrontApp = (app, bundle, focus, editable) {
      frontApp = app;
      frontBundle = bundle;
      frontFocus = focus;
      frontEditable = editable;
      notifyListeners();
    };
    client.onState = (_, __) => notifyListeners();
    client.onDisconnected = () {
      _ticker?.cancel();
      _ticker = null;
      _recordingStarting = false;
      _stopRequested = false;
      startedAt = null;
      level = 0;
      frontApp = '';
      frontBundle = '';
      frontFocus = '';
      frontEditable = false;
      unawaited(_resetRecording());
      if (phase != Phase.disconnected) {
        phase = Phase.disconnected;
        error = '连接中断了，先检查 Mac 端是否在运行';
        notifyListeners();
      }
    };
    client.onError = (message) {
      error = message;
      notifyListeners();
    };
    unawaited(refreshPermissions());
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString('host') ?? '';
    port = prefs.getInt('port') ?? 8787;
    code = prefs.getString('code') ?? '';
    bleDeviceId = prefs.getString('bleDevice') ?? '';
    recentText = prefs.getString('recentText') ?? '';
    history = HistoryEntry.decodeList(prefs.getString('history'));
    if (host.isNotEmpty) {
      screen = AppScreen.home;
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshPermissions());
    }
  }

  void go(AppScreen next) {
    screen = next;
    notifyListeners();
  }

  Future<bool> connect({String? address, int? newPort, String? newCode, String? name}) async {
    host = (address ?? host).trim();
    port = newPort ?? port;
    code = (newCode ?? code).trim();
    if (host.isEmpty) {
      error = '请填写 Mac 的 IP 地址';
      notifyListeners();
      return false;
    }
    if (port < 1 || port > 65535) {
      error = '端口必须在 1 到 65535 之间';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      error = '配对码是 6 位数字';
      notifyListeners();
      return false;
    }
    await _resetRecording();
    busy = true;
    error = null;
    phase = Phase.connecting;
    notifyListeners();
    try {
      await client.connect(host: host, port: port, code: code, name: name ?? '语音遥控');
      macName = client.macName;
      transportLabel = client.transportName;
      phase = Phase.connected;
      screen = AppScreen.home;
      markLocalNetworkVerified();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('host', host);
      await prefs.setInt('port', port);
      await prefs.setString('code', code);
      return true;
    } catch (e) {
      phase = Phase.disconnected;
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> connectBle(BluetoothDevice device, {String? pairingCode}) async {
    final chosenCode = (pairingCode ?? code).trim();
    if (!RegExp(r'^\d{6}$').hasMatch(chosenCode)) {
      error = '配对码是 6 位数字';
      notifyListeners();
      return false;
    }
    if (!await requestBluetooth()) {
      error = '蓝牙权限未开启，无法连接';
      notifyListeners();
      return false;
    }
    await _resetRecording();
    busy = true;
    error = null;
    phase = Phase.connecting;
    notifyListeners();
    final transport = BleTransport(device: device);
    try {
      await transport.connect();
      await client.connectWith(transport, code: chosenCode, name: '语音遥控', label: '蓝牙');
      code = chosenCode;
      macName = client.macName;
      transportLabel = '蓝牙';
      bleDeviceId = device.remoteId.str;
      phase = Phase.connected;
      screen = AppScreen.home;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('code', code);
      await prefs.setString('bleDevice', bleDeviceId);
      return true;
    } catch (e) {
      error = e.toString();
      phase = Phase.disconnected;
      await transport.close();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _resetRecording();
    await client.close();
    phase = Phase.disconnected;
    screen = AppScreen.discover;
    notifyListeners();
  }

  Future<bool> requestMic() async {
    micGranted = await recorder.ensurePermission();
    notifyListeners();
    return micGranted;
  }

  Future<bool> requestLocalNetwork() async {
    notifyListeners();
    return localNetworkGranted;
  }

  void markLocalNetworkVerified() {
    localNetworkGranted = true;
    notifyListeners();
  }

  Future<bool> requestBluetooth() async {
    if (kIsWeb) {
      bluetoothGranted = false;
      notifyListeners();
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final scan = await _requestPermission(Permission.bluetoothScan);
      final connect = await _requestPermission(Permission.bluetoothConnect);
      bluetoothGranted = scan && connect;
    } else {
      bluetoothGranted = await _requestPermission(Permission.bluetooth);
    }
    notifyListeners();
    return bluetoothGranted;
  }

  Future<bool> requestCamera() async {
    cameraGranted = await _requestPermission(Permission.camera);
    notifyListeners();
    return cameraGranted;
  }

  Future<void> refreshPermissions() async {
    micGranted = await _hasPermission(Permission.microphone);
    cameraGranted = await _hasPermission(Permission.camera);
    localNetworkGranted = connected || (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (kIsWeb) {
      bluetoothGranted = false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final scan = await _hasPermission(Permission.bluetoothScan);
      final connect = await _hasPermission(Permission.bluetoothConnect);
      bluetoothGranted = scan && connect;
    } else {
      bluetoothGranted = await _hasPermission(Permission.bluetooth);
    }
    permissionsLoaded = true;
    notifyListeners();
  }

  Future<bool> _hasPermission(Permission permission) async {
    try {
      return (await permission.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
    try {
      return (await permission.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> startRecording() async {
    if (!connected || _recordingStarting || phase == Phase.listening || phase == Phase.recognizing) return;
    _recordingStarting = true;
    _stopRequested = false;
    _cancelBySwipe = false;
    error = null;
    notice = null;
    level = 0;
    try {
      client.startStream();
      await recorder.start((Uint8List chunk) => client.sendPcm(chunk));
      if (!connected) {
        await recorder.stop();
        return;
      }
      startedAt = DateTime.now();
      phase = Phase.listening;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final start = startedAt;
        if (start == null) return;
        if (DateTime.now().difference(start).inSeconds >= 60) {
          stopRecording();
        } else {
          notifyListeners();
        }
      });
      notifyListeners();
      if (_stopRequested) {
        final cancel = _cancelBySwipe;
        _stopRequested = false;
        _recordingStarting = false;
        await stopRecording(cancel: cancel);
      }
    } catch (e) {
      await recorder.stop();
      startedAt = null;
      if (connected) phase = Phase.connected;
      error = '无法开始录音：$e';
    } finally {
      _recordingStarting = false;
    }
    notifyListeners();
  }

  void markSwipeCancel() {
    _cancelBySwipe = true;
  }

  Future<void> stopRecording({bool cancel = false}) async {
    if (_recordingStarting) {
      _stopRequested = cancel || _cancelBySwipe;
      return;
    }
    if (phase != Phase.listening) return;
    _ticker?.cancel();
    _ticker = null;
    await recorder.stop();
    startedAt = null;
    if (!connected) {
      phase = Phase.disconnected;
      error = '连接中断了，先检查 Mac 端是否在运行';
      notifyListeners();
      return;
    }
    if (cancel || _cancelBySwipe) {
      await client.cancelStream();
      phase = connected ? Phase.connected : Phase.disconnected;
      notifyListeners();
      return;
    }
    phase = Phase.recognizing;
    notifyListeners();
    try {
      final result = await client.stopStream();
      if (!connected) {
        phase = Phase.disconnected;
        error = '连接中断了，先检查 Mac 端是否在运行';
        notifyListeners();
        return;
      }
      final imeSubmitted = result.path == 'ime' && result.reason == 'ime_unconfirmed';
      if (result.text.isNotEmpty) recentText = result.text;
      await _recordHistory(result);
      latencyMs = result.ms;
      recentAt = DateTime.now();
      phase = result.ok ? Phase.delivered : (imeSubmitted ? Phase.submitted : Phase.failed);
      error = result.ok || imeSubmitted ? null : humanReason(result.reason);
      final prefs = await SharedPreferences.getInstance();
      if (recentText.isNotEmpty) {
        await prefs.setString('recentText', recentText);
      }
    } catch (e) {
      phase = connected ? Phase.failed : Phase.disconnected;
      error = connected ? e.toString() : '连接中断了，先检查 Mac 端是否在运行';
    }
    notifyListeners();
  }

  Future<void> _recordHistory(RelayResult result) async {
    final text = result.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final entry = HistoryEntry(
      id: '${now.microsecondsSinceEpoch}',
      at: now,
      text: text,
      ok: result.ok,
      ms: result.ms,
      path: result.path,
      reason: result.reason,
      app: frontApp.isEmpty ? null : frontApp,
    );
    history.insert(0, entry);
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', HistoryEntry.encodeList(history));
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history = <HistoryEntry>[];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('history');
    notifyListeners();
  }

  Future<void> deleteHistory(String id) async {
    history = history.where((entry) => entry.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', HistoryEntry.encodeList(history));
    notifyListeners();
  }

  Future<void> sendCommand(int subtype, {Map<String, dynamic> args = const {}}) async {
    try {
      final ack = await client.sendCommand(subtype, args: args);
      notice = ack['ok'] == true ? '已发送' : '没发出去：${ack['code'] ?? ''}';
    } catch (e) {
      notice = '没发出去：$e';
    }
    notifyListeners();
  }

  Future<QuickCommandResult> sendQuickCommand(int subtype, {Map<String, dynamic> args = const {}}) async {
    if (!connected) {
      final result = QuickCommandResult(ok: false, message: '未连接 Mac', subtype: subtype);
      notice = result.message;
      notifyListeners();
      return result;
    }
    if (controlBusy) {
      return QuickCommandResult(ok: false, message: '正在处理上一条命令', subtype: subtype);
    }
    controlBusy = true;
    notice = '正在发送…';
    notifyListeners();
    var result = QuickCommandResult(ok: false, message: '操作失败', subtype: subtype);
    final isAppSwitch = subtype == 0x01 || subtype == 0x0B || subtype == 0x0C || subtype == 0x0D;
    try {
      final ack = await client.sendCommand(
        subtype,
        args: args,
        timeout: Duration(seconds: isAppSwitch || subtype == 0x0E ? 8 : 4),
      );
      final detail = ack['detail'] as String?;
      final ok = ack['ok'] == true;
      final message = ok ? (detail ?? '操作完成') : '操作失败：${detail ?? ack['code'] ?? '未知错误'}';
      result = QuickCommandResult(ok: ok, message: message, subtype: subtype);
      notice = message;
    } catch (e) {
      result = QuickCommandResult(ok: false, message: '操作失败：$e', subtype: subtype);
      notice = result.message;
    } finally {
      if (isAppSwitch) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      controlBusy = false;
      notifyListeners();
    }
    return result;
  }

  String get elapsedLabel {
    final start = startedAt;
    if (start == null) return '0:00';
    final seconds = DateTime.now().difference(start).inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  static String humanReason(String? reason) {
    switch (reason) {
      case 'no_accessibility':
        return 'Mac 没拿到辅助功能权限；请在 Mac 上授权后重试';
      case 'no_focus':
        return '当前没有可输入的位置';
      case 'secure_input':
        return '密码框不支持语音输入';
      case 'direct_injection_failed':
        return '这个输入框不支持直接写入，文字已保留';
      case 'asr_not_ready':
        return 'Mac 端识别引擎还没准备好';
      case 'empty_audio':
      case 'empty_text':
        return '没有识别到文字，再说一次';
      case 'timeout':
        return '识别超时，没拿到文字';
      case 'asr_failed':
        return 'Mac 识别失败，请再试一次';
      case 'ime_unconfirmed':
        return '已发送到输入法，上屏结果未确认';
      default:
        return reason ?? '上屏失败';
    }
  }

  Future<void> _resetRecording() async {
    _ticker?.cancel();
    _ticker = null;
    _recordingStarting = false;
    _stopRequested = false;
    _cancelBySwipe = false;
    startedAt = null;
    level = 0;
    try {
      await recorder.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    recorder.dispose();
    client.close();
    super.dispose();
  }
}
