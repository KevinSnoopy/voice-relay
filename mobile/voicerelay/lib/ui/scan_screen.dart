import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../state/app_state.dart';
import 'theme.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.state.requestCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handle(BarcodeCapture capture) async {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      try {
        final normalized = base64Url.normalize(raw);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final map = jsonDecode(decoded) as Map<String, dynamic>;
        final ip = map['ip'] as String?;
        final port = (map['port'] as num?)?.toInt() ?? 8787;
        final code = map['tok'] as String?;
        final exp = (map['exp'] as num?)?.toInt();
        if (ip == null || code == null) continue;
        if (exp != null && exp < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
          setState(() => _error = '二维码已过期，请在 Mac 上重新打开');
          return;
        }
        _handled = true;
        final ok = await widget.state.connect(address: ip, newPort: port, newCode: code);
        if (!mounted) return;
        if (ok) {
          Navigator.of(context).pop();
        } else {
          _handled = false;
          setState(() => _error = widget.state.error ?? '连接失败');
        }
      } catch (_) {
        // Not a VoiceRelay QR; keep scanning.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handle, controller: _controller),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.state.cameraGranted ? null : () => widget.state.requestCamera(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.state.cameraGranted ? '相机已开启' : '相机未授权 · 点击开启',
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 248,
                  height: 248,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const Spacer(),
                const Text('对准 Mac 屏幕上的二维码', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Mac 端：菜单栏图标 › 配对 › 显示二维码', style: TextStyle(color: Colors.white70, fontSize: 11)),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: vrWarning.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                    child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('改用 IP 连接', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
