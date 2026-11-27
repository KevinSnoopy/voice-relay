import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// 16 kHz mono PCM16 capture; the Mac expects exactly this format for "pcm16".
class MicRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;

  bool get isRecording => _subscription != null;

  Future<bool> ensurePermission() => _recorder.hasPermission();

  Future<void> start(void Function(Uint8List chunk) onData) async {
    if (_subscription != null) return;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: false,
      noiseSuppress: false,
    ));
    _subscription = stream.listen(
      onData,
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    if (subscription == null) return;
    await subscription.cancel();
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
