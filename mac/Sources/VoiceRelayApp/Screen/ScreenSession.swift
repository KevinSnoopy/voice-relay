import AppKit
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit
#if canImport(WebRTC)
import WebRTC
#elseif canImport(LiveKitWebRTC)
import LiveKitWebRTC
#endif
import VoiceRelayCore

/// Per-phone screen sharing session: one WebRTC video track + one SCStream.
/// All control methods are expected to be called on the main thread; the
/// ScreenCaptureKit output callback runs on `sampleQueue`.
final class ScreenSession: NSObject, RTCPeerConnectionDelegate, SCStreamDelegate {
    private let factory: RTCPeerConnectionFactory
    private let source: RTCVideoSource
    private let capturer: RTCVideoCapturer
    private let track: RTCVideoTrack
    private let catalog = WindowCatalog()
    private let focusTracker = FocusTracker()
    private let sampleQueue = DispatchQueue(label: "com.voicerelay.screen.samples", qos: .userInitiated)

    private var peer: RTCPeerConnection?
    private var stream: SCStream?
    private var output: ScreenCaptureOutput?
    private var currentWindow: SCWindow?
    private var follow = true
    private var width = 1600
    private var height = 1000
    private var fps = 30
    private var pollTimer: Timer?
    private var closed = false

    var send: (([String: Any]) -> Void)?
    var onActiveChange: ((Bool) -> Void)?

    override init() {
        // This prebuilt WebRTC.framework crashes inside VideoToolbox's H.264
        // encoder pool on the 2014 Intel GPU. Prefer VP8 (software) for the
        // screen track; the phone side supports VP8 decode.
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        encoderFactory.preferredCodec = RTCVideoCodecInfo(name: "VP8")
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        self.factory = factory
        self.source = factory.videoSource()
        self.capturer = RTCVideoCapturer(delegate: source)
        self.track = factory.videoTrack(with: source, trackId: "screen-video")
        super.init()
    }

    var currentWindowID: CGWindowID? { currentWindow?.windowID }
    var isSharing: Bool { stream != nil }

    // MARK: - WebRTC setup

    func prepare(width: Int, height: Int, fps: Int, follow: Bool) {
        self.width = max(320, min(width, 1920))
        self.height = max(200, min(height, 1200))
        self.fps = max(5, min(fps, 30))
        self.follow = follow
        closed = false

        if peer != nil {
            sendState("connecting")
            return
        }

        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = []
        config.bundlePolicy = .maxBundle

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                // Same strings as kRTCMediaConstraintsOfferToReceiveAudio /
                // kRTCMediaConstraintsValueFalse in the WebRTC headers.
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false",
            ],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        guard let peer = factory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            sendError("offer_failed", "创建 PeerConnection 失败")
            return
        }
        self.peer = peer
        _ = peer.setBweMinBitrateBps(NSNumber(value: 2_000_000), currentBitrateBps: NSNumber(value: 4_000_000), maxBitrateBps: NSNumber(value: 6_000_000))
        peer.add(track, streamIds: ["screen"])
        source.adaptOutputFormat(toWidth: Int32(width), height: Int32(height), fps: Int32(fps))

        peer.offer(for: constraints) { [weak self] sdp, error in
            guard let self else { return }
            if let error {
                self.sendError("offer_failed", "生成 SDP 失败：\(error.localizedDescription)")
                return
            }
            guard let sdp else {
                self.sendError("offer_failed", "SDP 为空")
                return
            }
            peer.setLocalDescription(sdp) { [weak self] error in
                guard let self else { return }
                if let error {
                    self.sendError("offer_failed", "设置本地 SDP 失败：\(error.localizedDescription)")
                    return
                }
                self.send?(["op": "offer", "sdp": sdp.sdp])
                self.sendState("connecting")
                self.startFocusPolling()
                Task { await self.selectDefaultIfNeeded() }
            }
        }
    }

    func handleAnswer(_ sdp: String) {
        guard let peer else { return }
        let description = RTCSessionDescription(type: .answer, sdp: sdp)
        peer.setRemoteDescription(description) { [weak self] error in
            if let error {
                self?.sendError("answer_failed", "设置远端 SDP 失败：\(error.localizedDescription)")
            }
        }
    }

    func handleICE(candidate: String, sdpMid: String?, sdpMLineIndex: Int32?) {
        guard let peer else { return }
        let ice = RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex ?? 0, sdpMid: sdpMid)
        peer.add(ice)
    }

    // MARK: - Window selection / capture

    func listWindows() async -> [CatalogWindow] {
        (try? await catalog.list(focusedWindowID: (await focusTracker.focusedWindow(catalog: catalog))?.windowID)) ?? []
    }

    func selectWindow(id: CGWindowID, follow: Bool?) async {
        if let follow { self.follow = follow }
        guard let window = await catalog.window(id: id) else {
            sendError("window_missing", "窗口已关闭或不可共享")
            return
        }
        do {
            try await startCapture(window: window)
        } catch {
            sendError("capture_failed", "屏幕捕获失败：\(error.localizedDescription)")
        }
    }

    func setFollow(_ enabled: Bool) {
        follow = enabled
        sendState(stream == nil ? "idle" : "live")
        if enabled {
            Task { await selectDefaultIfNeeded(force: false) }
        }
    }

    func stop() {
        closed = true
        pollTimer?.invalidate()
        pollTimer = nil
        if let stream {
            Task { try? await stream.stopCapture() }
        }
        stream = nil
        output = nil
        currentWindow = nil
        peer?.close()
        peer = nil
        onActiveChange?(false)
        sendState("stopped")
    }

    /// Called after a phone control command switches app/window/focus.
    /// Deliberately forces a re-resolve even when the user had manually locked
    /// a window, so the preview always reflects the control result.
    func syncToFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, !self.closed else { return }
            Task { await self.selectDefaultIfNeeded(force: true) }
        }
    }

    func selectDefaultIfNeeded(force: Bool = false) async {
        guard !closed else { return }
        if !force, currentWindow != nil { return }
        let focused = await focusTracker.focusedWindow(catalog: catalog)
        let window: SCWindow?
        if let focused {
            window = focused
        } else {
            window = await catalog.frontmost(focusedWindowID: nil)
        }
        guard let window else {
            sendState("no_window")
            return
        }
        if window.windowID == currentWindow?.windowID { return }
        await selectWindow(id: window.windowID, follow: nil)
    }

    private func startCapture(window: SCWindow) async throws {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        output = nil

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        // WebRTC's H.264 encoder expects a bi-planar YUV pixel buffer. Feeding
        // BGRA made VideoToolbox's encoder pool creation crash inside
        // CVPixelBufferPoolGetPixelBufferAttributes on this Intel Mac.
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        config.showsCursor = true
        config.capturesAudio = false
        config.queueDepth = 3
        config.scalesToFit = true

        let output = ScreenCaptureOutput(source: source, capturer: capturer)
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()

        self.output = output
        self.stream = stream
        self.currentWindow = window
        onActiveChange?(true)
        sendState("live")
        sendWindowState()
    }

    private func startFocusPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.follow, !self.closed, self.currentWindow != nil else { return }
            Task { [weak self] in
                guard let self else { return }
                guard let window = await self.focusTracker.focusedWindow(catalog: self.catalog),
                      window.windowID != self.currentWindow?.windowID else { return }
                await self.selectWindow(id: window.windowID, follow: nil)
            }
        }
    }

    // MARK: - State

    private func sendState(_ state: String) {
        var payload: [String: Any] = [
            "op": "state",
            "state": state,
            "follow": follow,
            "fps": fps,
            "width": width,
            "height": height,
        ]
        if let window = currentWindow {
            payload["windowId"] = Int(window.windowID)
            payload["title"] = window.title ?? ""
            payload["app"] = window.owningApplication?.applicationName ?? ""
        }
        send?(payload)
    }

    private func sendWindowState() {
        guard let window = currentWindow else { return }
        send?([
            "op": "window",
            "windowId": Int(window.windowID),
            "title": window.title ?? "",
            "app": window.owningApplication?.applicationName ?? "",
            "follow": follow,
        ])
    }

    private func sendError(_ code: String, _ message: String) {
        send?(["op": "error", "code": code, "message": message])
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stream = nil
            self.output = nil
            self.onActiveChange?(false)
            self.sendError("stream_stopped", error.localizedDescription)
            self.sendState("stopped")
        }
    }

    // MARK: - RTCPeerConnectionDelegate

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DispatchQueue.main.async { [weak self] in
            self?.send?([
                "op": "ice",
                "candidate": candidate.sdp,
                "sdpMid": candidate.sdpMid ?? "",
                "sdpMLineIndex": candidate.sdpMLineIndex,
            ])
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch newState {
            case .connected:
                self.sendState(self.stream == nil ? "connected" : "live")
                Task { await self.selectDefaultIfNeeded() }
            case .failed, .closed:
                self.sendState("disconnected")
            default:
                break
            }
        }
    }
}

/// SCStreamOutput is called on a private queue; only touch the WebRTC source here.
private final class ScreenCaptureOutput: NSObject, SCStreamOutput {
    private let source: RTCVideoSource
    private let capturer: RTCVideoCapturer

    init(source: RTCVideoSource, capturer: RTCVideoCapturer) {
        self.source = source
        self.capturer = capturer
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timeStampNs = Int64(CMTimeGetSeconds(timestamp) * 1_000_000_000)
        let buffer = RTCCVPixelBuffer(pixelBuffer: pixelBuffer)
        let frame = RTCVideoFrame(buffer: buffer, rotation: ._0, timeStampNs: timeStampNs)
        source.capturer(capturer, didCapture: frame)
    }
}
