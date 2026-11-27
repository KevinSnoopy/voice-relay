import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../screen/screen_client.dart';
import 'theme.dart';

/// Inline screen preview on the main page. It owns one ScreenClient/WebRTC
/// renderer and keeps itself alive while the surrounding HomeScreen rebuilds.
class ScreenPreviewCard extends StatefulWidget {
  const ScreenPreviewCard({
    super.key,
    required this.host,
    required this.port,
    required this.code,
    required this.macName,
    required this.enabled,
  });

  final String host;
  final int port;
  final String code;
  final String macName;
  final bool enabled;

  @override
  State<ScreenPreviewCard> createState() => _ScreenPreviewCardState();
}

class _ScreenPreviewCardState extends State<ScreenPreviewCard>
    with AutomaticKeepAliveClientMixin<ScreenPreviewCard> {
  ScreenClient? _client;
  RTCVideoRenderer? _renderer;
  final TransformationController _zoom = TransformationController();
  bool _busy = false;
  bool _active = false;
  String? _error;

  bool get _canStart => widget.enabled && widget.host.isNotEmpty;

  @override
  bool get wantKeepAlive => _active;

  @override
  void didUpdateWidget(covariant ScreenPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_active &&
        (oldWidget.host != widget.host ||
            oldWidget.port != widget.port ||
            oldWidget.code != widget.code)) {
      unawaited(_stop());
    }
  }

  void _onClient() {
    if (!mounted) return;
    final stream = _client?.remoteStream;
    final renderer = _renderer;
    if (stream != null && renderer != null && renderer.srcObject != stream) {
      renderer.srcObject = stream;
    }
    if (_client?.error != null && _client!.error != _error) {
      _error = _client!.error;
    }
    setState(() {});
  }

  Future<void> _start() async {
    if (_busy || _active) return;
    if (!_canStart) {
      setState(() => _error = '请先通过局域网连接 Mac');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      final client = ScreenClient(
        host: widget.host,
        port: widget.port + 1,
        code: widget.code,
      );
      client.addListener(_onClient);
      if (!mounted) {
        await renderer.dispose();
        client.dispose();
        return;
      }
      setState(() {
        _renderer = renderer;
        _client = client;
      });
      await client.connect();
      await client.start();
      client.requestWindows();
      if (!mounted) return;
      setState(() {
        _active = true;
        _busy = false;
      });
    } catch (error) {
      await _disposeSession();
      if (mounted) {
        setState(() {
          _busy = false;
          _active = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _stop() async {
    await _disposeSession();
    if (mounted) {
      setState(() {
        _active = false;
        _busy = false;
        _error = null;
      });
    }
  }

  Future<void> _disposeSession() async {
    final client = _client;
    _client = null;
    client?.removeListener(_onClient);
    if (client != null) {
      try {
        await client.stop();
      } catch (_) {}
      client.dispose();
    }
    final renderer = _renderer;
    _renderer = null;
    await renderer?.dispose();
    _zoom.value = Matrix4.identity();
  }

  Future<void> _showWindows() async {
    final client = _client;
    if (client == null) return;
    client.requestWindows();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      showDragHandle: true,
      builder: (context) {
        return AnimatedBuilder(
          animation: client,
          builder: (context, _) {
            final windows = client.windows;
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
                      '手动选择后会暂停“跟随输入光标”，可在预览卡片里重新打开。',
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
                            final thumb = client.thumbnails[window.id];
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
                                client.switchWindow(window.id);
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

  @override
  void dispose() {
    unawaited(_disposeSession());
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final client = _client;
    final renderer = _renderer;
    final stream = client?.remoteStream;
    final state = client?.state;
    final follow = state?.follow ?? true;
    final title = state?.title?.isNotEmpty == true
        ? state!.title!
        : (state?.app?.isNotEmpty == true ? state!.app! : widget.macName);

    if (!_active) {
      return _CompactIdleCard(
        busy: _busy,
        error: _error,
        canStart: _canStart,
        onStart: _start,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _active ? const Color(0xFF1F6FEB) : vrBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (stream != null && renderer != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () {
                      final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.2;
                      _zoom.value = zoomed
                          ? Matrix4.identity()
                          : (Matrix4.identity()..setEntry(0, 0, 3.0)..setEntry(1, 1, 3.0));
                    },
                    child: InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1.0,
                      maxScale: 5.0,
                      boundaryMargin: const EdgeInsets.all(40),
                      clipBehavior: Clip.hardEdge,
                      child: RTCVideoView(
                        renderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                        mirror: false,
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Text('等待画面…', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                if (_active)
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _Badge(text: title, icon: Icons.screen_share_outlined),
                  ),
                if (_active)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _Badge(
                      text: follow ? '跟随光标' : '已锁定',
                      icon: follow ? Icons.my_location_rounded : Icons.lock_outline_rounded,
                      color: follow ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    ),
                  ),
                if (_active && _error != null)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xCC7F1D1D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_active)
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: const Color(0xFF111827),
              child: Row(
                children: [
                  const Text(
                    '只看不控 · 双指放大',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '跟随输入光标',
                    onPressed: client == null ? null : () => client.setFollow(!follow),
                    icon: Icon(
                      follow ? Icons.my_location_rounded : Icons.lock_outline_rounded,
                      size: 18,
                      color: follow ? const Color(0xFF34D399) : const Color(0xFF9CA3AF),
                    ),
                  ),
                  IconButton(
                    tooltip: '切换窗口',
                    onPressed: client == null ? null : _showWindows,
                    icon: const Icon(Icons.window_rounded, size: 18, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: '停止共享',
                    onPressed: _busy ? null : _stop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 18, color: Color(0xFFF87171)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompactIdleCard extends StatelessWidget {
  const _CompactIdleCard({
    required this.busy,
    required this.error,
    required this.canStart,
    required this.onStart,
  });

  final bool busy;
  final String? error;
  final bool canStart;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null && error!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: vrSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: vrBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: vrPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monitor_rounded, color: vrPrimary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '屏幕共享',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: vrInk),
                ),
                const SizedBox(height: 2),
                Text(
                  busy
                      ? '正在连接…'
                      : hasError
                          ? error!
                          : (canStart ? '只看不控 · 点击开启' : '先通过局域网连接 Mac'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: hasError ? vrRecording : vrMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton.tonal(
              onPressed: canStart ? onStart : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(58, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(hasError ? '重试' : '开启', style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.icon, this.color = Colors.white});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xCC111827),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500),
            ),
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
