import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int protocolVersion = 1;
const int maxPayload = 8192;

enum MsgType {
  hello(0x1),
  helloAck(0x2),
  auth(0x3),
  authOk(0x4),
  streamStart(0x5),
  audio(0x6),
  streamStop(0x7),
  result(0x8),
  level(0x9),
  command(0xA),
  commandAck(0xB),
  state(0xC),
  error(0xD),
  ping(0xE),
  pong(0xF);

  const MsgType(this.code);
  final int code;

  static MsgType? fromCode(int code) {
    for (final value in MsgType.values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

class WireError implements Exception {
  WireError(this.message);
  final String message;

  @override
  String toString() => message;
}

class Frame {
  Frame({required this.type, this.payload = const <int>[], this.flags = 0, this.seq = 0});

  final MsgType type;
  final List<int> payload;
  final int flags;
  final int seq;

  Uint8List encode() {
    final length = payload.length;
    if (length > maxPayload) throw WireError('payload too large: $length');
    final bytes = Uint8List(4 + length);
    bytes[0] = (protocolVersion << 4) | type.code;
    bytes[1] = ((flags & 0x03) << 6) | (seq & 0x3F);
    bytes[2] = length & 0xFF;
    bytes[3] = (length >> 8) & 0xFF;
    bytes.setRange(4, 4 + length, payload);
    return bytes;
  }
}

class FrameDecoder {
  final List<int> _buffer = <int>[];

  List<Frame> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <Frame>[];
    while (_buffer.length >= 4) {
      final version = _buffer[0] >> 4;
      if (version != protocolVersion) throw WireError('bad version: $version');
      final type = MsgType.fromCode(_buffer[0] & 0x0F);
      if (type == null) throw WireError('unknown message type: ${_buffer[0] & 0x0F}');
      final length = _buffer[2] | (_buffer[3] << 8);
      if (length > maxPayload) throw WireError('payload too large: $length');
      if (_buffer.length < 4 + length) break;
      final payload = Uint8List.fromList(_buffer.sublist(4, 4 + length));
      final flags = (_buffer[1] >> 6) & 0x03;
      final seq = _buffer[1] & 0x3F;
      frames.add(Frame(type: type, payload: payload, flags: flags, seq: seq));
      _buffer.removeRange(0, 4 + length);
    }
    return frames;
  }

  void reset() => _buffer.clear();
}

Uint8List _hmac(List<int> key, List<int> message) =>
    Uint8List.fromList(Hmac(sha256, key).convert(message).bytes);

Uint8List hmacSha256(List<int> key, List<int> message) => _hmac(key, message);

/// RFC 5869 HKDF-SHA256; salt/info/ikm must match the Mac implementation exactly.
Uint8List hkdfSha256({
  required List<int> ikm,
  required List<int> salt,
  required List<int> info,
  int length = 32,
}) {
  final effectiveSalt = salt.isEmpty ? List<int>.filled(32, 0) : salt;
  final prk = _hmac(effectiveSalt, ikm);
  final okm = <int>[];
  var previous = <int>[];
  var counter = 1;
  while (okm.length < length) {
    previous = _hmac(prk, <int>[...previous, ...info, counter]);
    okm.addAll(previous);
    counter++;
  }
  return Uint8List.fromList(okm.sublist(0, length));
}

Map<String, dynamic> decodeJson(List<int> payload) =>
    jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;

Uint8List encodeJson(Map<String, dynamic> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

Uint8List uint16le(int value) =>
    Uint8List.fromList(<int>[value & 0xFF, (value >> 8) & 0xFF]);

Uint8List uint32le(int value) => Uint8List.fromList(<int>[
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);

int readUint16le(List<int> data, int offset) => data[offset] | (data[offset + 1] << 8);

int readUint32le(List<int> data, int offset) =>
    data[offset] |
    (data[offset + 1] << 8) |
    (data[offset + 2] << 16) |
    (data[offset + 3] << 24);
