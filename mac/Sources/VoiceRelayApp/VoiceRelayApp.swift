import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct VoiceRelayApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environmentObject(state)
        } label: {
            Image(systemName: menuIcon)
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)

        Window("VoiceRelay 设置", id: "settings") {
            SettingsView().environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Window("欢迎使用 VoiceRelay", id: "onboarding") {
            OnboardingView().environmentObject(state)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var menuIcon: String {
        if state.modelLoading { return "hourglass" }
        if state.snapshot.model == "未加载" { return "exclamationmark.circle" }
        if state.permissions["accessibility"] != .granted { return "exclamationmark.circle" }
        if state.snapshot.connected { return "dot.radiowaves.left.and.right" }
        return "circle"
    }
}
