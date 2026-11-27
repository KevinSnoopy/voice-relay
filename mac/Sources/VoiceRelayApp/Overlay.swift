import SwiftUI
import AppKit

final class LevelOverlayModel: ObservableObject {
    @Published var level: Int = 0
}

/// 140 × 44 floating level window. Non-activating, ignores mouse, follows the pointer.
final class LevelOverlayController {
    private let model = LevelOverlayModel()
    private var panel: NSPanel?
    private var timer: Timer?
    private var hideWork: DispatchWorkItem?

    func update(level: Int, visible: Bool) {
        DispatchQueue.main.async {
            self.model.level = level
            if visible {
                self.show()
            } else {
                self.scheduleHide()
            }
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            self.panel?.orderOut(nil)
            self.panel = nil
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        self.panel = panel
    }

    private func show() {
        hideWork?.cancel()
        hideWork = nil
        ensurePanel()
        position()
        panel?.orderFrontRegardless()
        startTracking()
    }

    private func scheduleHide() {
        guard panel != nil else { return }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
            self?.timer?.invalidate()
            self?.timer = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func startTracking() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.position()
        }
    }

    private func position() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        var origin = CGPoint(x: mouse.x + 20, y: mouse.y - 60)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            let frame = screen.visibleFrame
            origin.x = min(max(frame.minX + 8, origin.x), frame.maxX - 148)
            origin.y = min(max(frame.minY + 8, origin.y), frame.maxY - 52)
        }
        panel.setFrameOrigin(origin)
    }
}

final class SwitchHudController {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private let label = NSTextField(labelWithString: "")

    func show(_ text: String) {
        DispatchQueue.main.async {
            self.label.stringValue = text
            self.ensurePanel()
            self.position()
            self.panel?.orderFrontRegardless()
            self.scheduleHide()
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.hideWork?.cancel()
            self.panel?.orderOut(nil)
            self.panel = nil
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: SwitchHudView(text: textBinding))
        self.panel = panel
    }

    private var textBinding: Binding<String> {
        Binding(get: { self.label.stringValue }, set: { self.label.stringValue = $0 })
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: frame.midX - 140, y: frame.maxY - 72))
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}

private struct SwitchHudView: View {
    @Binding var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
    }
}

private struct OverlayView: View {
    @ObservedObject var model: LevelOverlayModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(red: 0.96, green: 0.26, blue: 0.36))
                .frame(width: 6, height: 6)
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 6, height: height(for: index))
            }
        }
        .frame(width: 140, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.72))
        )
        .animation(.easeOut(duration: 0.12), value: model.level)
    }

    private func height(for index: Int) -> CGFloat {
        let base: [CGFloat] = [8, 18, 26, 18, 8]
        return base[index] * (0.35 + CGFloat(model.level) / 100.0 * 0.65)
    }
}
