import Foundation

public enum MessageType: UInt8, Sendable, CaseIterable {
    case hello = 0x1
    case helloAck = 0x2
    case auth = 0x3
    case authOK = 0x4
    case streamStart = 0x5
    case audio = 0x6
    case streamStop = 0x7
    case result = 0x8
    case level = 0x9
    case command = 0xA
    case commandAck = 0xB
    case state = 0xC
    case error = 0xD
    case ping = 0xE
    case pong = 0xF
}

public enum WireError: Error, CustomStringConvertible, Equatable {
    case badVersion(UInt8)
    case payloadTooLarge(Int)
    case truncatedHeader
    case unknownType(UInt8)

    public var description: String {
        switch self {
        case .badVersion(let v): return "unsupported protocol version \(v)"
        case .payloadTooLarge(let n): return "payload too large: \(n)"
        case .truncatedHeader: return "truncated frame header"
        case .unknownType(let t): return "unknown message type 0x\(String(t, radix: 16))"
        }
    }
}

public struct Frame: Equatable, Sendable {
    public static let version: UInt8 = 1
    public static let maxPayload = 8192

    public var type: MessageType
    public var flags: UInt8
    public var seq: UInt8
    public var payload: Data

    public init(type: MessageType, payload: Data = Data(), flags: UInt8 = 0, seq: UInt8 = 0) {
        self.type = type
        self.payload = payload
        self.flags = flags & 0x03
        self.seq = seq & 0x3F
    }

    public func encoded() -> Data {
        var out = Data(capacity: payload.count + 4)
        out.append((Frame.version << 4) | (type.rawValue & 0x0F))
        out.append(((flags & 0x03) << 6) | (seq & 0x3F))
        let length = UInt16(payload.count)
        out.append(UInt8(length & 0xFF))
        out.append(UInt8((length >> 8) & 0xFF))
        out.append(payload)
        return out
    }
}

/// Incremental frame parser. Split TCP/BLE chunks may contain partial frames or several frames.
public struct FrameDecoder {
    private var buffer = Data()

    public init() {}

    public var bufferedByteCount: Int { buffer.count }

    public mutating func append(_ data: Data) throws -> [Frame] {
        buffer.append(data)
        var frames: [Frame] = []
        while buffer.count >= 4 {
            let start = buffer.startIndex
            let b0 = buffer[start]
            let b1 = buffer[start + 1]
            let version = b0 >> 4
            guard version == Frame.version else { throw WireError.badVersion(version) }
            let typeRaw = b0 & 0x0F
            guard let type = MessageType(rawValue: typeRaw) else { throw WireError.unknownType(typeRaw) }
            let length = Int(buffer[start + 2]) | (Int(buffer[start + 3]) << 8)
            guard length <= Frame.maxPayload else { throw WireError.payloadTooLarge(length) }
            let total = 4 + length
            guard buffer.count >= total else { break }
            let payload = buffer.subdata(in: (start + 4)..<(start + total))
            let flags = (b1 >> 6) & 0x03
            let seq = b1 & 0x3F
            frames.append(Frame(type: type, payload: payload, flags: flags, seq: seq))
            buffer.removeFirst(total)
        }
        return frames
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
}

public enum JSONMessage {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}
