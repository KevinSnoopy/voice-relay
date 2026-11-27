import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../transport/ble_transport.dart';

class BleScanner {
  Future<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 4)}) async {
    final results = <String, ScanResult>{};
    final subscription = FlutterBluePlus.onScanResults.listen((batch) {
      for (final result in batch) {
        results[result.device.remoteId.str] = result;
      }
    });
    try {
      await FlutterBluePlus.startScan(withServices: [vrServiceUuid], timeout: timeout);
      await Future<void>.delayed(timeout + const Duration(milliseconds: 300));
    } finally {
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
    }
    return results.values.toList();
  }
}
