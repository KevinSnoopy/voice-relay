import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    convenience init(state: AppState) {
        let view = OnboardingView(onClose: { [weak state] in
            UserDefaults.standard.set(true, forKey: "VoiceRelayOnboarded")
            state?.onboardingWindow?.close()
            state?.onboardingWindow = nil
        })
        .environmentObject(state)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "欢迎使用 VoiceRelay"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 560, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }
}
