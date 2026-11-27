import Foundation

#if canImport(WebRTC)
import WebRTC
#elseif canImport(LiveKitWebRTC)
import LiveKitWebRTC

// LiveKit's prebuilt WebRTC XCFramework is the only WebRTC build published for
// macOS arm64. Its headers are the stock WebRTC ones compiled with
// RTC_OBJC_TYPE_PREFIX= `LK`, so every type is exported as `LKRTCPeerConnection`
// and friends. Map the official names back so the screen-sharing code has a
// single API surface on both architectures.
typealias RTCPeerConnection = LKRTCPeerConnection
typealias RTCPeerConnectionDelegate = LKRTCPeerConnectionDelegate
typealias RTCPeerConnectionFactory = LKRTCPeerConnectionFactory
typealias RTCPeerConnectionState = LKRTCPeerConnectionState
typealias RTCConfiguration = LKRTCConfiguration
typealias RTCDataChannel = LKRTCDataChannel
typealias RTCIceCandidate = LKRTCIceCandidate
typealias RTCIceConnectionState = LKRTCIceConnectionState
typealias RTCIceGatheringState = LKRTCIceGatheringState
typealias RTCMediaConstraints = LKRTCMediaConstraints
typealias RTCMediaStream = LKRTCMediaStream
typealias RTCSessionDescription = LKRTCSessionDescription
typealias RTCSignalingState = LKRTCSignalingState
typealias RTCCVPixelBuffer = LKRTCCVPixelBuffer
typealias RTCDefaultVideoDecoderFactory = LKRTCDefaultVideoDecoderFactory
typealias RTCDefaultVideoEncoderFactory = LKRTCDefaultVideoEncoderFactory
typealias RTCVideoCapturer = LKRTCVideoCapturer
typealias RTCVideoCodecInfo = LKRTCVideoCodecInfo
typealias RTCVideoFrame = LKRTCVideoFrame
typealias RTCVideoSource = LKRTCVideoSource
typealias RTCVideoTrack = LKRTCVideoTrack
#endif

// Google's prebuilt WebRTC returns a non-optional `RTCPeerConnection`, while
// LiveKit's arm64 build returns an optional. Normalize the return type here so
// callers can use one `guard let` on both architectures.
extension RTCPeerConnectionFactory {
    func makePeerConnection(
        with configuration: RTCConfiguration,
        constraints: RTCMediaConstraints,
        delegate: RTCPeerConnectionDelegate?
    ) -> RTCPeerConnection? {
        peerConnection(with: configuration, constraints: constraints, delegate: delegate)
    }
}
