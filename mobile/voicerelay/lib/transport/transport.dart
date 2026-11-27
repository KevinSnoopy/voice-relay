/// A byte pipe: TCP or BLE. Framing/authentication live above this layer.
abstract class RelayTransport {
  Future<void> connect();
  Stream<List<int>> get incoming;
  void send(List<int> bytes);
  Future<void> close();
}
