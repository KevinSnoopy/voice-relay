import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../discovery/ble_scan.dart';
import '../discovery/mdns.dart';
import '../state/app_state.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'screen_preview_card.dart';
import 'theme.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    switch (state.screen) {
      case AppScreen.welcome:
        return WelcomeScreen(state: state);
      case AppScreen.permissions:
        return PermissionsScreen(state: state);
      case AppScreen.discover:
        return DiscoverScreen(state: state);
      case AppScreen.home:
        return HomeScreen(state: state);
    }
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(colors: [vrPrimaryLight, vrPrimary]),
                    boxShadow: [
                      BoxShadow(color: vrPrimary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.laptop_mac_rounded, size: 14, color: vrInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(child: _Pill(text: '遥控器 + 麦克风')),
              const SizedBox(height: 16),
              const Text(
                '按住说话，\n字出现在 Mac 上',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: vrInk),
              ),
              const SizedBox(height: 10),
              const Text(
                '手机只负责说，Mac 负责写。先在 Mac 上装一个配套 App，两端连上就能用。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: vrMuted),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: vrSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: vrBorder),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('连上后的样子', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Spacer(),
                        _Pill(text: '延迟因设备而异', color: vrSuccess),
                      ],
                    ),
                    SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _DeviceDot(icon: Icons.smartphone_rounded, label: '手机'),
                        Icon(Icons.graphic_eq_rounded, color: vrPrimary),
                        _DeviceDot(icon: Icons.laptop_mac_rounded, label: 'Mac'),
                      ],
                    ),
                    SizedBox(height: 14),
                    Text(
                      '录音不进云，文字在本机识别后直接送到光标。',
                      style: TextStyle(fontSize: 11, color: vrMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => state.go(AppScreen.permissions), child: const Text('开始设置')),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => state.go(AppScreen.discover),
                child: const Text('我已经装好了 Mac 端'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  @override
  void initState() {
    super.initState();
    widget.state.requestMic();
    widget.state.refreshPermissions();
  }

  Future<void> _requestMic() async {
    await widget.state.requestMic();
  }

  Future<void> _requestBluetooth() => widget.state.requestBluetooth();

  @override
  Widget build(BuildContext context) {
    final mic = widget.state.micGranted;
    return Scaffold(
      appBar: AppBar(title: const Text('还差几个权限')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Text('第 2 步 / 共 3 步', style: TextStyle(fontSize: 11, color: vrMuted)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 2 / 3,
                            minHeight: 5,
                            backgroundColor: vrBorder,
                            valueColor: AlwaysStoppedAnimation(vrPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('只开必要的，随时能在系统设置里关掉。', style: TextStyle(fontSize: 13, color: vrMuted)),
                  const SizedBox(height: 16),
                  _PermissionCard(
                    icon: Icons.mic_none_rounded,
                    title: '麦克风',
                    required: true,
                    granted: mic,
                    description: '收音必需',
                    why: '不给权限，按钮按下去也没有声音。',
                    onTap: mic ? null : _requestMic,
                  ),
                  const SizedBox(height: 10),
                  _PermissionCard(
                    icon: Icons.wifi_tethering_rounded,
                    title: '本地网络',
                    required: false,
                    granted: widget.state.localNetworkGranted,
                    description: 'Android 无需单独授权；iOS 首次访问时询问',
                    why: '发现或连接成功后显示已验证。',
                    onTap: null,
                    pendingLabel: '待验证',
                  ),
                  const SizedBox(height: 10),
                  _PermissionCard(
                    icon: Icons.bluetooth_rounded,
                    title: '蓝牙',
                    required: false,
                    granted: widget.state.bluetoothGranted,
                    description: 'BLE 备用通道',
                    why: '网络不通时改走蓝牙。',
                    onTap: widget.state.bluetoothGranted ? null : _requestBluetooth,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '拒了也没关系：去「设置 › 隐私」里可以重新打开，回来点一下就会变勾选态。',
                    style: TextStyle(fontSize: 11, color: vrMuted, height: 1.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: mic ? () => widget.state.go(AppScreen.discover) : null,
                    child: Text(mic ? '下一步' : '麦克风未授权，下一步不可用'),
                  ),
                  TextButton(
                    onPressed: () => widget.state.go(AppScreen.discover),
                    child: const Text('先跳过'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, required this.state});

  final AppState state;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _code;
  final MdnsDiscovery _mdns = MdnsDiscovery();
  final BleScanner _bleScanner = BleScanner();
  List<DiscoveredMac> _nearby = const [];
  List<ScanResult> _bleNearby = const [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.state.host);
    _port = TextEditingController(text: widget.state.port.toString());
    _code = TextEditingController(text: widget.state.code);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final ok = await widget.state.connect(
      address: _host.text,
      newPort: int.tryParse(_port.text.trim()) ?? 8787,
      newCode: _code.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.state.error ?? '连接失败')));
    }
  }

  Future<void> _scanMdns() async {
    setState(() => _scanning = true);
    try {
      final found = await _mdns.discover();
      if (!mounted) return;
      if (found.isNotEmpty) widget.state.markLocalNetworkVerified();
      setState(() => _nearby = found);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('局域网扫描失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _scanBle() async {
    if (!await widget.state.requestBluetooth()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先允许蓝牙权限')));
      }
      return;
    }
    setState(() => _scanning = true);
    try {
      final found = await _bleScanner.scan();
      if (!mounted) return;
      setState(() => _bleNearby = found);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('蓝牙扫描失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connectBle(BluetoothDevice device) async {
    final ok = await widget.state.connectBle(device, pairingCode: _code.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.state.error ?? '蓝牙连接失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.state.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('连接 Mac')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: 160,
              height: 160,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: vrPrimary.withValues(alpha: 0.06),
                border: Border.all(color: vrPrimary.withValues(alpha: 0.15)),
              ),
              child: const Icon(Icons.radar_rounded, size: 72, color: vrPrimary),
            ),
            const Text('把你的 Mac 连上', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              '在 Mac 菜单栏打开 VoiceRelay，能看到 IP、端口和 6 位配对码。',
              style: TextStyle(fontSize: 13, color: vrMuted, height: 1.5),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.wifi_find_rounded),
                    title: const Text('附近的 Mac'),
                    subtitle: Text(_nearby.isEmpty ? '扫描局域网广播，或直接手填 IP' : '发现 ${_nearby.length} 台'),
                    trailing: TextButton(
                      onPressed: _scanning ? null : _scanMdns,
                      child: Text(_scanning ? '扫描中…' : '扫描'),
                    ),
                  ),
                  for (final mac in _nearby)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.laptop_mac_rounded, size: 20),
                      title: Text(mac.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${mac.host}:${mac.port}', style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        _host.text = mac.host;
                        _port.text = mac.port.toString();
                      },
                    ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bluetooth_rounded),
                    title: const Text('蓝牙备用通道'),
                    subtitle: Text(_bleNearby.isEmpty ? '网络不通时用 BLE 连接' : '发现 ${_bleNearby.length} 台'),
                    trailing: TextButton(
                      onPressed: _scanning ? null : _scanBle,
                      child: const Text('扫描'),
                    ),
                  ),
                  for (final result in _bleNearby)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.bluetooth_searching_rounded, size: 20),
                      title: Text(result.device.platformName.isEmpty ? '未命名设备' : result.device.platformName, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(result.device.remoteId.str, style: const TextStyle(fontSize: 10)),
                      onTap: () => _connectBle(result.device),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ScanScreen(state: widget.state)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('扫码配对'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _host,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Mac IP', hintText: '192.168.2.18'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '端口'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: '配对码', counterText: ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _connect,
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('连接'),
            ),
            const SizedBox(height: 10),
            if (widget.state.error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: vrWarning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(widget.state.error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
              ),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('连不上时先看这四项', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      '① 手机和 Mac 在同一 Wi-Fi ② Mac 端 App 在运行 ③ 已允许辅助功能 ④ 防火墙没拦 8787。公司 Wi-Fi 常在客户端隔离，这时改用蓝牙或手填 IP。',
                      style: TextStyle(fontSize: 11, color: vrMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => widget.state.go(AppScreen.welcome),
              child: const Text('返回欢迎页'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double? _pressY;
  bool _cancelled = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final connected = state.connected;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StatusBar(
              state: state,
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  ScreenPreviewCard(
                    host: state.host,
                    port: state.port,
                    code: state.code,
                    macName: state.macName,
                    enabled: state.connected && state.transportLabel != '蓝牙',
                  ),
                  _MacControlCard(state: state),
                  const SizedBox(height: 10),
                  if (state.phase == Phase.failed && state.error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: vrWarning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: vrWarning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: vrWarning, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(state.error!, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                          ),
                          TextButton(
                            onPressed: () => _copy(context, state.recentText),
                            child: const Text('复制'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (state.phase == Phase.delivered) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: vrSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: vrSuccess, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '已出现在 Mac 上 · ${state.latencyMs} ms',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (state.phase == Phase.submitted) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: vrPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, color: vrPrimary, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '已发送到输入法，上屏结果未确认',
                              style: TextStyle(fontSize: 12, color: vrPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!connected)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: vrBorder.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.link_off_rounded, size: 18, color: vrMuted),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('还没连上 Mac', style: TextStyle(fontSize: 12, color: vrMuted))),
                          TextButton(
                            onPressed: () => state.go(AppScreen.discover),
                            child: const Text('去连接'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (state.phase == Phase.listening)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${state.elapsedLabel} / 1:00 · 上滑取消',
                  style: const TextStyle(fontSize: 11, color: vrRecording),
                ),
              ),
            _HoldButton(
              state: state,
              enabled: state.connected && state.phase != Phase.recognizing,
              onDown: _handleDown,
              onMove: _handleMove,
              onUp: _handleUp,
              onCancel: _handleCancel,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _handleDown(PointerDownEvent event) {
    final state = widget.state;
    if (!state.connected || state.phase == Phase.listening || state.phase == Phase.recognizing) return;
    _pressY = event.position.dy;
    _cancelled = false;
    HapticFeedback.mediumImpact();
    state.startRecording();
  }

  void _handleMove(PointerMoveEvent event) {
    if (_pressY == null || widget.state.phase != Phase.listening || _cancelled) return;
    if (event.position.dy - _pressY! < -64) {
      _cancelled = true;
      widget.state.markSwipeCancel();
      HapticFeedback.mediumImpact();
    }
  }

  void _handleUp(PointerUpEvent event) {
    if (_pressY == null) return;
    _pressY = null;
    widget.state.stopRecording(cancel: _cancelled);
  }

  void _handleCancel(PointerCancelEvent event) {
    if (_pressY == null) return;
    _pressY = null;
    widget.state.stopRecording(cancel: true);
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(state: widget.state)));
  }

  void _copy(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制')));
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state, required this.onSettings});

  final AppState state;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state.phase) {
      Phase.connected => ('已连接', vrSuccess),
      Phase.listening => ('正在收音', vrRecording),
      Phase.recognizing => ('正在识别', vrPrimary),
      Phase.delivered => ('已上屏', vrSuccess),
      Phase.submitted => ('已发送到输入法', vrPrimary),
      Phase.failed => ('上屏失败', vrWarning),
      Phase.connecting => ('正在连接', vrWarning),
      Phase.disconnected => ('未连接', vrMuted),
    };
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.macName.isEmpty ? '未连接 Mac' : state.macName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: vrMuted),
            ),
          ),
          if (state.phase == Phase.listening) ...[
            Text(state.elapsedLabel, style: const TextStyle(fontSize: 11, color: vrRecording)),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: vrMuted.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              !state.connected
                  ? '未连接'
                  : '${state.client.backend == 'B' ? 'B · 输入法' : 'A · 本地'} · ${state.transportLabel}',
              style: const TextStyle(fontSize: 10, color: vrMuted),
            ),
          ),
          IconButton(onPressed: onSettings, icon: const Icon(Icons.settings_outlined, size: 20)),
        ],
      ),
    );
  }
}

class _MacControlCard extends StatelessWidget {
  const _MacControlCard({required this.state});

  final AppState state;

  Future<void> _run(BuildContext context, int subtype, {Map<String, dynamic> args = const {}}) async {
    final result = await state.sendQuickCommand(subtype, args: args);
    if (!context.mounted) return;
    final isAppSwitch = subtype == 0x01 || subtype == 0x0B || subtype == 0x0C || subtype == 0x0D;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.message),
      duration: Duration(seconds: isAppSwitch ? 2 : 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = state.connected &&
        !state.controlBusy &&
        state.phase != Phase.listening &&
        state.phase != Phase.recognizing;
    final currentApp = state.frontApp.isEmpty ? '等待 Mac 状态' : state.frontApp;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: vrSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vrBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.laptop_mac_rounded, size: 18, color: vrPrimary),
              const SizedBox(width: 8),
              const Text('Mac 快捷控制', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                state.connected ? '已连接' : '未连接',
                style: TextStyle(fontSize: 10, color: state.connected ? vrSuccess : vrMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.frontApp.isEmpty ? '连接后显示 Mac 当前 App' : '当前 App：$currentApp',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (state.frontApp.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              state.frontEditable
                  ? '光标：${state.frontFocus.isEmpty ? '已就绪' : state.frontFocus}'
                  : '当前 App 没有可输入焦点',
              style: TextStyle(fontSize: 10, color: state.frontEditable ? vrMuted : vrWarning),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: '上一个 App',
                  shortcut: '⌘⇧Tab',
                  icon: Icons.keyboard_tab_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x0C),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '下一个 App',
                  shortcut: '⌘Tab',
                  icon: Icons.swap_horiz_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '下一个窗口',
                  shortcut: '⌘`',
                  icon: Icons.web_asset_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x0D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: '上一个输入框',
                  shortcut: '⇧Tab',
                  icon: Icons.keyboard_tab_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x03),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '下一个输入框',
                  shortcut: 'Tab',
                  icon: Icons.keyboard_tab_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x02),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '首个输入框',
                  shortcut: '聚焦',
                  icon: Icons.center_focus_strong_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x0E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: 'Shift+回车',
                  shortcut: '⇧↵',
                  icon: Icons.keyboard_return_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x0F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '回车发送',
                  shortcut: '↵',
                  icon: Icons.keyboard_return_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x04),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '删除',
                  shortcut: '⌫',
                  icon: Icons.backspace_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x05, args: const {'count': 1}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: '全选',
                  shortcut: '⌘A',
                  icon: Icons.select_all_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x09),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '撤销',
                  shortcut: '⌘Z',
                  icon: Icons.undo_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x0A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  label: '取消会话',
                  shortcut: 'Esc',
                  icon: Icons.close_rounded,
                  enabled: enabled,
                  onTap: () => _run(context, 0x07),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.shortcut,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String shortcut;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 68),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        side: const BorderSide(color: vrBorder),
        backgroundColor: vrBg,
        foregroundColor: vrInk,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: enabled ? vrPrimary : vrMuted),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1),
          const SizedBox(height: 2),
          Text(shortcut, style: const TextStyle(fontSize: 9, color: vrMuted), maxLines: 1),
        ],
      ),
    );
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.state,
    required this.enabled,
    required this.onDown,
    required this.onMove,
    required this.onUp,
    required this.onCancel,
  });

  final AppState state;
  final bool enabled;
  final void Function(PointerDownEvent) onDown;
  final void Function(PointerMoveEvent) onMove;
  final void Function(PointerUpEvent) onUp;
  final void Function(PointerCancelEvent) onCancel;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _listening => widget.state.phase == Phase.listening;

  @override
  void initState() {
    super.initState();
    if (_listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant _HoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_listening && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!_listening && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listening = _listening;
    final size = listening ? 120.0 : 112.0;
    return SizedBox(
      width: 184,
      height: 158,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (listening)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: List.generate(3, (index) {
                    final t = (_pulse.value + index / 3) % 1.0;
                    final ring = size + 54 * t;
                    return Container(
                      width: ring,
                      height: ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: vrRecording.withValues(alpha: (1 - t) * 0.32),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          if (listening)
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final wave = (1 - (_pulse.value * 2 - 1).abs()).clamp(0.0, 1.0);
                return Container(
                  width: size + 18 + wave * 10,
                  height: size + 18 + wave * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: vrRecording.withValues(alpha: 0.06 + wave * 0.05),
                  ),
                );
              },
            ),
          Listener(
            onPointerDown: widget.enabled ? widget.onDown : null,
            onPointerMove: widget.onMove,
            onPointerUp: widget.onUp,
            onPointerCancel: widget.onCancel,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: !widget.enabled
                      ? [vrMuted.withValues(alpha: 0.3), vrMuted.withValues(alpha: 0.2)]
                      : listening
                          ? [const Color(0xFFFB7185), const Color(0xFFE11D48)]
                          : [vrPrimaryLight, vrPrimary],
                ),
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: (listening ? vrRecording : vrPrimary).withValues(alpha: 0.3),
                          blurRadius: listening ? 30 : 20,
                          spreadRadius: listening ? 8 : 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: widget.enabled ? Colors.white : Colors.white70,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _code;
  @override
  void initState() {
    super.initState();
    _host = TextEditingController(text: widget.state.host);
    _port = TextEditingController(text: widget.state.port.toString());
    _code = TextEditingController(text: widget.state.code);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final recognitionStatus = !state.connected
        ? '未连接'
        : state.client.backend == 'B'
            ? '已启用'
            : state.client.model == '已加载'
                ? '使用中'
                : '模型未就绪';
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.laptop_mac_rounded),
                title: Text(state.macName.isEmpty ? '未连接' : state.macName),
                subtitle: Text(state.connected
                    ? '已连接 · ${state.transportLabel}'
                    : state.phase == Phase.connecting
                        ? '正在连接…'
                        : '未连接'),
                trailing: state.connected
                    ? const Text('在线', style: TextStyle(fontSize: 11, color: vrSuccess))
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            const Text('连接', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _host, decoration: const InputDecoration(labelText: 'Mac IP')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '端口'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '配对码', counterText: ''))),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      final ok = await state.connect(address: _host.text, newPort: int.tryParse(_port.text) ?? 8787, newCode: _code.text);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
              child: Text(state.busy ? '连接中…' : '保存并重连'),
            ),
            const SizedBox(height: 18),
            const Text('识别', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(state.client.backend == 'B' ? '输入法通道' : 'Mac 端识别'),
                subtitle: Text(state.client.backend == 'B'
                    ? '音频写入虚拟声卡，上屏结果需自行确认'
                    : '音频不出局域网，在 Mac 上识别'),
                trailing: Text(
                  recognitionStatus,
                  style: TextStyle(
                    fontSize: 11,
                    color: recognitionStatus == '模型未就绪' || recognitionStatus == '未连接' ? vrMuted : vrPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('历史记录'),
                subtitle: Text(state.history.isEmpty ? '还没有记录' : '${state.history.length} 条已保存'),
                trailing: const Icon(Icons.chevron_right_rounded, color: vrMuted),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => HistoryScreen(state: state)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                leading: const Icon(Icons.link_off_rounded, color: vrRecording),
                title: const Text('断开这台 Mac', style: TextStyle(color: vrRecording)),
                onTap: () async {
                  await state.disconnect();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 18),
            const Center(child: Text('语音遥控 1.0.0 · 自用版', style: TextStyle(fontSize: 10, color: vrMuted))),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.required,
    required this.granted,
    required this.description,
    required this.why,
    required this.onTap,
    this.pendingLabel,
  });

  final IconData icon;
  final String title;
  final bool required;
  final bool granted;
  final String description;
  final String why;
  final VoidCallback? onTap;
  final String? pendingLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: granted ? vrSurface : vrWarning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: granted ? vrBorder : vrWarning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: granted ? vrSuccess.withValues(alpha: 0.1) : vrWarning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: granted ? vrSuccess : vrWarning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (!required)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('可选', style: TextStyle(fontSize: 9, color: vrMuted)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 11, color: vrMuted)),
                const SizedBox(height: 2),
                Text(why, style: const TextStyle(fontSize: 10, color: vrMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            const Icon(Icons.check_circle_rounded, color: vrSuccess, size: 20)
          else if (onTap != null)
            TextButton(onPressed: onTap, child: const Text('去授权'))
          else if (pendingLabel != null)
            Text(pendingLabel!, style: const TextStyle(fontSize: 11, color: vrMuted)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.color = vrPrimary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _DeviceDot extends StatelessWidget {
  const _DeviceDot({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: vrBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: vrBorder),
          ),
          child: Icon(icon, color: vrInk),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: vrMuted)),
      ],
    );
  }
}
