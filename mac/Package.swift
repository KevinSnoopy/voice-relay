// swift-tools-version:5.9
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let sherpaRoot = "\(packageRoot)/vendor/sherpa-onnx-v2.0.3-osx-x64-shared"
let opusRoot = "\(packageRoot)/vendor/opus"

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
        .executableTarget(name: "VoiceRelayApp", dependencies: ["VoiceRelayCore", "WebRTC"], path: "Sources/VoiceRelayApp"),
        .binaryTarget(name: "WebRTC", path: "vendor/WebRTC.xcframework"),
        .testTarget(name: "VoiceRelayCoreTests", dependencies: ["VoiceRelayCore"], path: "Tests/VoiceRelayCoreTests"),
    ]
)
