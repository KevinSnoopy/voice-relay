import Foundation

public struct HelloMessage: Codable, Equatable {
    public var v: Int
    public var client: String
    public var mid: String
    public var name: String
    public var caps: [String]

    public init(v: Int = 1, client: String, mid: String, name: String, caps: [String] = ["pcm16", "opus", "cmd"]) {
        self.v = v
        self.client = client
        self.mid = mid
        self.name = name
        self.caps = caps
    }
}

public struct HelloAckMessage: Codable, Equatable {
    public var v: Int
    public var name: String
    public var mid: String
    public var backend: String
    public var perms: [String: Bool]
    public var challenge: String
    public var model: String
}

public struct AuthOKMessage: Codable, Equatable {
    public var session: String
}

public struct StreamStartMessage: Codable, Equatable {
    public var sr: Int
    public var ch: Int
    /// "pcm16" or "opus"
    public var codec: String

    public init(sr: Int = 16000, ch: Int = 1, codec: String = "pcm16") {
        self.sr = sr
        self.ch = ch
        self.codec = codec
    }
}

public struct StreamStopMessage: Codable, Equatable {
    public var n: Int

    public init(n: Int) {
        self.n = n
    }
}

public struct ResultMessage: Codable, Equatable {
    public var ok: Bool
    public var text: String
    public var ms: Int
    public var len: Int
    public var reason: String?
    public var path: String?
    public var asrMs: Int?
    public var injectMs: Int?
}

public struct LevelMessage: Codable, Equatable {
    public var level: Int
}

public struct CommandAckMessage: Codable, Equatable {
    public var sub: Int
    public var ok: Bool
    public var code: String?
    public var detail: String?
}

public struct StateMessage: Codable, Equatable {
    public var app: String
    public var bundleId: String
    public var backend: String
    public var model: String
    public var connected: Bool
    public var port: Int
    public var focus: String?
    public var editable: Bool?
}

public struct ErrorMessage: Codable, Equatable {
    public var code: Int
    public var message: String
}

public enum ErrorCode {
    public static let authFailed = 0x10
    public static let protocolMismatch = 0x11
    public static let asrNotReady = 0x20
    public static let audioOverflow = 0x21
    public static let noFocus = 0x30
    public static let secureInput = 0x31
    public static let unsupportedTarget = 0x32
    public static let bluetoothUnavailable = 0x40
    public static let backendUnavailable = 0x50
}

public enum CommandSubtype: UInt8, CaseIterable {
    case switchApp = 0x01
    case focusNext = 0x02
    case focusPrevious = 0x03
    case returnKey = 0x04
    case backspace = 0x05
    case switchBackend = 0x06
    case cancel = 0x07
    case copyLast = 0x08
    // Extensions beyond docs/02 §5, used by the control panel.
    case selectAll = 0x09
    case undo = 0x0A
    case nextApp = 0x0B
    case previousApp = 0x0C
    case nextWindow = 0x0D
    case activateFocus = 0x0E
    case shiftReturn = 0x0F

    public var updatesFrontApp: Bool {
        switch self {
        case .switchApp, .nextApp, .previousApp, .nextWindow: return true
        default: return false
        }
    }

    public var showsFeedback: Bool {
        switch self {
        case .switchApp, .nextApp, .previousApp, .nextWindow, .activateFocus, .focusNext, .focusPrevious, .returnKey, .shiftReturn: return true
        default: return false
        }
    }

    /// Commands that can move the foreground app/window or the text focus.
    /// Screen sharing listens to this to keep the shared window in sync.
    public var changesFocus: Bool {
        switch self {
        case .switchApp, .nextApp, .previousApp, .nextWindow, .activateFocus, .focusNext, .focusPrevious:
            return true
        default:
            return false
        }
    }
}

public extension Notification.Name {
    static let voiceRelayFocusDidChange = Notification.Name("com.voicerelay.focusDidChange")
}
