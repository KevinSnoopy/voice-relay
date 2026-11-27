import XCTest
@testable import VoiceRelayCore

final class ProtocolTests: XCTestCase {
    func testFragmentedFrame() throws {
        let frame = Frame(type: .audio, payload: Data(repeating: 0xAB, count: 300), seq: 7)
        let encoded = frame.encoded()
        var decoder = FrameDecoder()
        XCTAssertTrue(try decoder.append(encoded.prefix(2)).isEmpty)
        XCTAssertTrue(try decoder.append(encoded[2..<100]).isEmpty)
        let frames = try decoder.append(encoded[100...])
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].payload.count, 300)
        XCTAssertEqual(frames[0].seq, 7)
        XCTAssertEqual(frames[0].type, .audio)
    }

    func testMultipleFramesInOneChunk() throws {
        let a = Frame(type: .hello, payload: Data([1]), seq: 1)
        let b = Frame(type: .auth, payload: Data([2]), seq: 2)
        var decoder = FrameDecoder()
        let frames = try decoder.append(a.encoded() + b.encoded())
        XCTAssertEqual(frames.map(\.type), [.hello, .auth])
    }

    func testRejectsBadVersion() {
        var data = Frame(type: .ping, payload: Data()).encoded()
        data[0] = 0x20
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(data))
    }

    func testRejectsOversizedPayload() {
        var header = Data([0x1E, 0x00, 0x00, 0x00])
        let length = UInt16(Frame.maxPayload + 1)
        header[2] = UInt8(length & 0xFF)
        header[3] = UInt8(length >> 8)
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(header)) { error in
            XCTAssertEqual(error as? WireError, .payloadTooLarge(Frame.maxPayload + 1))
        }
    }

    func testSequenceMasksToSixBits() {
        let frame = Frame(type: .ping, payload: Data(), flags: 0xFF, seq: 0xFF)
        XCTAssertEqual(frame.seq, 0x3F)
        XCTAssertEqual(frame.flags, 0x03)
        var decoder = FrameDecoder()
        let decoded = try? decoder.append(frame.encoded()).first
        XCTAssertEqual(decoded?.seq, 0x3F)
    }

    func testHKDFIsDeterministic() {
        let a = RelayCrypto.hkdfSHA256(ikm: Data("123456".utf8), salt: Data("mac".utf8), info: Data("VoiceRelay-Pairing-v1".utf8))
        let b = RelayCrypto.hkdfSHA256(ikm: Data("123456".utf8), salt: Data("mac".utf8), info: Data("VoiceRelay-Pairing-v1".utf8))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 32)
        let c = RelayCrypto.hkdfSHA256(ikm: Data("123457".utf8), salt: Data("mac".utf8), info: Data("VoiceRelay-Pairing-v1".utf8))
        XCTAssertNotEqual(a, c)
    }

    func testPairingVerification() {
        let store = PairingStore(fixedCode: "123456", persist: false)
        let challenge = Data(repeating: 9, count: 32)
        let key = store.derivedKey(from: "123456")
        let mac = RelayCrypto.hmacSHA256(key: key, message: challenge)
        XCTAssertTrue(store.verify(deviceMid: "device-1", challenge: challenge, mac: mac))
        XCTAssertFalse(store.verify(deviceMid: "device-2", challenge: challenge, mac: Data(repeating: 0, count: 32)))
    }

    func testPCM16RoundTrip() {
        let samples: [Float] = [0, 0.5, -0.5, 0.999, -0.999]
        let decoded = PCM16.decode(PCM16.encode(samples))
        XCTAssertEqual(decoded.count, samples.count)
        for (a, b) in zip(samples, decoded) {
            XCTAssertEqual(a, b, accuracy: 0.001)
        }
    }

    func testControlPanelSubtypes() {
        XCTAssertEqual(CommandSubtype.selectAll.rawValue, 0x09)
        XCTAssertEqual(CommandSubtype.undo.rawValue, 0x0A)
        XCTAssertEqual(CommandSubtype.switchApp.rawValue, 0x01)
        XCTAssertEqual(CommandSubtype.nextApp.rawValue, 0x0B)
        XCTAssertEqual(CommandSubtype.previousApp.rawValue, 0x0C)
        XCTAssertEqual(CommandSubtype.nextWindow.rawValue, 0x0D)
        XCTAssertEqual(CommandSubtype.activateFocus.rawValue, 0x0E)
        XCTAssertEqual(CommandSubtype.shiftReturn.rawValue, 0x0F)
        XCTAssertTrue(CommandSubtype.nextApp.showsFeedback)
        XCTAssertTrue(CommandSubtype.activateFocus.showsFeedback)
    }

    func testBLESpecUUIDsAreDistinct() {
        XCTAssertNotEqual(BLESpec.service, BLESpec.rx)
        XCTAssertNotEqual(BLESpec.rx, BLESpec.tx)
        XCTAssertNotEqual(BLESpec.service, BLESpec.tx)
    }

    func testVirtualSinkEnumerationDoesNotCrash() {
        _ = VirtualMicSink.availableDevices()
        XCTAssertTrue(VirtualMicSink.preferredNames.contains("BlackHole 2ch"))
    }

    func testResultJSONRoundTrip() throws {
        let result = ResultMessage(ok: true, text: "你好", ms: 420, len: 2, reason: nil, path: "ax", asrMs: 300, injectMs: 20)
        let data = try JSONMessage.encode(result)
        let decoded = try JSONMessage.decode(ResultMessage.self, from: data)
        XCTAssertEqual(decoded, result)
    }

    func testIMEResultIsNotConfirmedDelivery() throws {
        let result = ResultMessage(
            ok: false,
            text: "",
            ms: 10,
            len: 0,
            reason: DeliveredText.imeUnconfirmedReason,
            path: "ime",
            asrMs: 0,
            injectMs: 0
        )
        let decoded = try JSONMessage.decode(ResultMessage.self, from: JSONMessage.encode(result))
        XCTAssertFalse(decoded.ok)
        XCTAssertEqual(decoded.reason, "ime_unconfirmed")
        XCTAssertEqual(decoded.path, "ime")
    }

    func testDeliveredTextStatusLabels() {
        let confirmed = DeliveredText(
            text: "你好", ok: true, path: "ax", reason: nil,
            appName: "备忘录", bundleId: "com.apple.TextEdit",
            totalMs: 100, asrMs: 80, injectMs: 20, charCount: 2
        )
        XCTAssertTrue(confirmed.isConfirmedDelivery)
        XCTAssertEqual(confirmed.statusLabel, "已上屏")

        let failed = DeliveredText(
            text: "你好", ok: false, path: "none", reason: "direct_injection_failed",
            appName: "备忘录", bundleId: "com.apple.TextEdit",
            totalMs: 100, asrMs: 80, injectMs: 20, charCount: 2
        )
        XCTAssertFalse(failed.isConfirmedDelivery)
        XCTAssertEqual(failed.statusLabel, "未送达")

        let ime = DeliveredText(
            text: "", ok: false, path: "ime", reason: DeliveredText.imeUnconfirmedReason,
            appName: "备忘录", bundleId: "com.apple.TextEdit",
            totalMs: 10, asrMs: 0, injectMs: 0, charCount: 0
        )
        XCTAssertFalse(ime.isConfirmedDelivery)
        XCTAssertEqual(ime.statusLabel, "已发送到输入法 · 未确认")
        XCTAssertEqual(ime.displayText, "已发送到输入法，等待上屏结果")
    }
}
