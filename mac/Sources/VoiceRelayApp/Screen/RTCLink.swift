import Foundation
import WebRTC

enum RTCLink {
    static func check() {
        _ = RTCPeerConnectionFactory()
    }
}
