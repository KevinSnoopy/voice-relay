import Foundation
#if canImport(WebRTC)
import WebRTC
#elseif canImport(LiveKitWebRTC)
import LiveKitWebRTC
#endif

enum RTCLink {
    static func check() {
        _ = RTCPeerConnectionFactory()
    }
}
