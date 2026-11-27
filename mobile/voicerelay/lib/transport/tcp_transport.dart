import 'dart:async';
import 'dart:io';

import 'transport.dart';

class TcpTransport implements RelayTransport {
  TcpTransport({required this.host, required this.port});

  final String host;
  final int port;
  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  final StreamController<List<int>> _incoming = StreamController<List<int>>.broadcast();

  @override
  Future<void> connect() async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 6));
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;
    _subscription = socket.listen(
      _incoming.add,
      onError: (Object error) => _incoming.addError(error),
      onDone: () {
        if (!_incoming.isClosed) _incoming.close();
      },
      cancelOnError: true,
    );
  }

  @override
  Stream<List<int>> get incoming => _incoming.stream;

  @override
  void send(List<int> bytes) {
    _socket?.add(bytes);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    if (!_incoming.isClosed) await _incoming.close();
  }
}
