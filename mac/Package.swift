// swift-tools-version:5.9
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path

// Select the vendored binaries matching the build architecture.
#if arch(arm64)
let hostArch = "arm64"
// No official WebRTC build is published for macOS arm64; use the LiveKit
// maintained XCFramework (same RTC* Objective-C API) instead.
let webrtcTarget: Target = .binaryTarget(name: "LiveKitWebRTC", path: "vendor/LiveKitWebRTC.xcframework")
let webrtcDependency: [Target.Dependency] = ["LiveKitWebRTC"]
#else
let hostArch = "x64"
let webrtcTarget: Target = .binaryTarget(name: "WebRTC", path: "vendor/WebRTC.xcframework")
let webrtcDependency: [Target.Dependency] = ["WebRTC"]
#endif
let sherpaRoot = "\(packageRoot)/vendor/sherpa-onnx-v2.0.3-osx-\(hostArch)-shared"
let opusRoot = hostArch == "arm64" ? "\(packageRoot)/vendor/opus-arm64" : "\(packageRoot)/vendor/opus"

let package = Package(
    name: "VoiceRelay",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "VoiceRelayCore", targets: ["VoiceRelayCore"]),
        .executable(name: "voicerelayd", targets: ["voicerelayd"]),
        .executable(name: "vrphone", targets: ["vrphone"]),
        .executable(name: "VoiceRelay", targets: ["VoiceRelayApp"]),
    ],
    targets: [
        .systemLibrary(name: "CSherpaOnnx", path: "Sources/CSherpaOnnx"),
        .systemLibrary(name: "COpus", path: "Sources/COpus"),
        .target(
            name: "VoiceRelayCore",
            dependencies: ["CSherpaOnnx", "COpus"],
            path: "Sources/VoiceRelayCore",
            linkerSettings: [
                .unsafeFlags([
                    "-L", "\(sherpaRoot)/lib",
                    "-lsherpa-onnx-c-api",
                    "-L", "\(opusRoot)/lib",
                    "-lopus",
                    "-Xlinker", "-rpath", "-Xlinker", "\(sherpaRoot)/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                ])
            ]
        ),
        .executableTarget(name: "voicerelayd", dependencies: ["VoiceRelayCore"], path: "Sources/voicerelayd"),
        .executableTarget(name: "vrphone", dependencies: ["VoiceRelayCore"], path: "Sources/vrphone"),
        .executableTarget(name: "VoiceRelayApp", dependencies: [.target(name: "VoiceRelayCore")] + webrtcDependency, path: "Sources/VoiceRelayApp"),
        webrtcTarget,
        .testTarget(name: "VoiceRelayCoreTests", dependencies: ["VoiceRelayCore"], path: "Tests/VoiceRelayCoreTests"),
    ]
)
