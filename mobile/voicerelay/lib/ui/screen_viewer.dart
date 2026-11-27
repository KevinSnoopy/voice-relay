import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../screen/screen_client.dart';

class ScreenViewerPage extends StatefulWidget {
  const ScreenViewerPage({
    super.key,
    required this.host,
    required this.port,
    required this.code,
    required this.macName,
  });

  final String host;
  final int port;
  final String code;
  final String macName;

  @override
  State<ScreenViewerPage> createState() => _ScreenViewerPageState();
}

class _ScreenViewerPageState extends State<ScreenViewerPage> {
  late final ScreenClient _client;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _starting = true;
  String? _error;
  bool _showChrome = true;
  bool _landscape = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _client = ScreenClient(host: widget.host, port: widget.port + 1, code: widget.code);
    _client.addListener(_onClient);
    _bootstrap();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showChrome = false);
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _renderer.initialize();
      await _client.connect();
      await _client.start();
      _client.requestWindows();
      if (mounted) setState(() => _starting = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = error.toString();
        });
      }
    }
  }

  void _onClient() {
    if (!mounted) return;
    final stream = _client.remoteStream;
    if (stream != null && _renderer.srcObject != stream) {
      _renderer.srcObject = stream;
    }
    if (_client.error != null && _error == null) {
      _error = _client.error;
    }
    setState(() {});
  }

  Future<void> _enterLandscape() async {
    if (_landscape) return;
    _landscape = true;
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _restorePortrait() async {
    if (!_landscape) return;
    _landscape = false;
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  void _toggleChrome() {
    setState(() => _showChrome = !_showChrome);
    _hideTimer?.cancel();
    if (_showChrome) {
      _hideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showChrome = false);
      });
    }
  }

  Future<void> _openWindows() async {
    _client.requestWindows();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: _client,
          builder: (context, _) {
            final windows = _client.windows;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '切换窗口',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '手动选择后会暂停“跟随输入光标”，可在顶部重新打开。',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    if (windows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: windows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1F2937)),
                          itemBuilder: (context, index) {
                            final window = windows[index];
                            final thumb = _client.thumbnails[window.id];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _Thumb(data: thumb, selected: window.current),
                              title: Text(
                                window.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              subtitle: Text(
                                '${window.app} · ${window.width}×${window.height}${window.current ? ' · 正在共享' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                              ),
                              onTap: () {
                                _client.switchWindow(window.id);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _stopAndPop() async {
    await _client.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _client.removeListener(_onClient);
    _client.dispose();
    _renderer.dispose();
    unawaited(_restorePortrait());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _client.state;
    final title = state?.title?.isNotEmpty == true
        ? state!.title!
        : (state?.app?.isNotEmpty == true ? state!.app! : widget.macName);
    final follow = state?.follow ?? true;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _stopAndPop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleChrome,
          onDoubleTap: _enterLandscape,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: _renderer.srcObject == null
                        ? const ColoredBox(color: Colors.black)
                        : RTCVideoView(
                            _renderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                            mirror: false,
                          ),
                  ),
                ),
              ),
              if (_starting || _error != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xCC111827),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_starting) const CircularProgressIndicator(strokeWidth: 2),
                        if (_starting) const SizedBox(height: 14),
                        Text(
                          _error ?? '正在建立屏幕连接…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('返回'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              AnimatedOpacity(
                opacity: _showChrome ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !_showChrome,
                  child: SafeArea(
                    child: Column(
                      children: [
                        _TopBar(
                          title: title,
                          follow: follow,
                          onBack: _stopAndPop,
                          onFollow: () => _client.setFollow(!follow),
                          onLandscape: _enterLandscape,
                        ),
                        const Spacer(),
                        _BottomBar(
                          state: state,
                          onSwitch: _openWindows,
                          onStop: _stopAndPop,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.follow,
    required this.onBack,
    required this.onFollow,
    required this.onLandscape,
  });

  final String title;
  final bool follow;
  final VoidCallback onBack;
  final VoidCallback onFollow;
  final VoidCallback onLandscape;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC111827),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const Text('只看不控 · 屏幕共享', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onFollow,
            icon: Icon(follow ? Icons.my_location_rounded : Icons.lock_outline_rounded, size: 16, color: follow ? const Color(0xFF34D399) : const Color(0xFF9CA3AF)),
            label: Text(follow ? '跟随光标' : '已手动锁定', style: TextStyle(fontSize: 10, color: follow ? const Color(0xFF34D399) : const Color(0xFF9CA3AF))),
          ),
          IconButton(onPressed: onLandscape, icon: const Icon(Icons.screen_rotation_rounded, color: Colors.white, size: 19)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.onSwitch, required this.onStop});

  final ScreenState? state;
  final VoidCallback onSwitch;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xCC111827), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(
            '${state?.fps ?? 30} fps · 1600×1000 · 局域网',
            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.window_rounded, size: 16),
            label: const Text('切换窗口'),
          ),
          TextButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop_circle_outlined, size: 16, color: Color(0xFFF87171)),
            label: const Text('停止', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.data, required this.selected});

  final Uint8List? data;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: selected ? const Color(0xFF34D399) : const Color(0xFF374151)),
      ),
      clipBehavior: Clip.antiAlias,
      child: data == null
          ? const Icon(Icons.window_rounded, color: Color(0xFF6B7280), size: 20)
          : Image.memory(data!, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}
