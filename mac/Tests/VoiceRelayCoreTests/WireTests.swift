import XCTest
@testable import VoiceRelayCore

final class WireTests: XCTestCase {
    func testFrameRoundTrip() throws {
        let frame = Frame(type: .audio, payload: Data([1, 2, 3]), seq: 42)
        var decoder = FrameDecoder()
        let frames = try decoder.append(frame.encoded())
        XCTAssertEqual(frames, [frame])
    }
}
