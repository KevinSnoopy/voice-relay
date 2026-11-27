import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'transport.dart';

final Guid vrServiceUuid = Guid('7A1F0001-6C3A-4B7E-9E2A-9B5C1D2E3F40');
final Guid vrRxUuid = Guid('7A1F0002-6C3A-4B7E-9E2A-9B5C1D2E3F40');
final Guid vrTxUuid = Guid('7A1F0003-6C3A-4B7E-9E2A-9B5C1D2E3F40');

/// GATT central. Writes phone frames to RX, receives Mac notifications from TX.
class BleTransport implements RelayTransport {
  BleTransport({required this.device});

  final BluetoothDevice device;
  final StreamController<List<int>> _incoming = StreamController<List<int>>.broadcast();
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Future<void> _writeChain = Future<void>.value();

  @override
  Future<void> connect() async {
    await device.connect(timeout: const Duration(seconds: 10));
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (item) => item.uuid == vrServiceUuid,
      orElse: () => throw StateError('Mac 没有 VoiceRelay BLE 服务'),
    );
    _rx = service.characteristics.firstWhere((item) => item.uuid == vrRxUuid);
    _tx = service.characteristics.firstWhere((item) => item.uuid == vrTxUuid);
    await _tx!.setNotifyValue(true);
    _notifySubscription = _tx!.onValueReceived.listen(
      _incoming.add,
      onError: (Object error) => _incoming.addError(error),
    );
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected && !_incoming.isClosed) {
        _incoming.close();
      }
    });
  }

  @override
  Stream<List<int>> get incoming => _incoming.stream;

  @override
  void send(List<int> bytes) {
    final rx = _rx;
    if (rx == null) return;
    _writeChain = _writeChain.then((_) async {
      const chunk = 180;
      for (var offset = 0; offset < bytes.length; offset += chunk) {
        final end = math.min(offset + chunk, bytes.length);
        await rx.write(bytes.sublist(offset, end), withoutResponse: false);
      }
    }).catchError((Object _) {});
  }

  @override
  Future<void> close() async {
    await _notifySubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notifySubscription = null;
    _connectionSubscription = null;
    try {
      await device.disconnect();
    } catch (_) {}
    if (!_incoming.isClosed) await _incoming.close();
  }
}
