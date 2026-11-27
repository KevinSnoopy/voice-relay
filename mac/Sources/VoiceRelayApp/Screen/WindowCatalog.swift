import AppKit
import CoreGraphics
import ScreenCaptureKit

struct CatalogWindow {
    let window: SCWindow

    var id: CGWindowID { window.windowID }
    var pid: pid_t { window.owningApplication?.processID ?? 0 }
    var appName: String { window.owningApplication?.applicationName ?? "未知 App" }
    var title: String {
        let value = window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? appName : value
    }
    var frame: CGRect { window.frame }
}

/// Enumerates shareable windows and matches AX focus information to SCWindow.
/// Must be used from the main actor because SCWindow/AX objects are not Sendable.
final class WindowCatalog {
    private var cachedWindows: [SCWindow] = []

    func refresh() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        cachedWindows = content.windows
        return cachedWindows
    }

    func list(focusedWindowID: CGWindowID?) async throws -> [CatalogWindow] {
        let windows = try await refresh()
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let order = windowOrder()
        let selfPID = getpid()

        var items: [CatalogWindow] = windows.compactMap { window in
            guard window.windowLayer == 0 else { return nil }
            guard window.frame.width >= 160, window.frame.height >= 100 else { return nil }
            guard let owner = window.owningApplication else { return nil }
            guard owner.processID != selfPID else { return nil }
            guard !owner.bundleIdentifier.hasPrefix("com.apple.dock") else { return nil }
            return CatalogWindow(window: window)
        }

        items.sort { lhs, rhs in
            let lhsFront = lhs.pid == frontPID
            let rhsFront = rhs.pid == frontPID
            if lhsFront != rhsFront { return lhsFront }
            let lhsFocused = lhs.id == focusedWindowID
            let rhsFocused = rhs.id == focusedWindowID
            if lhsFocused != rhsFocused { return lhsFocused }
            let lo = order[lhs.id] ?? Int.max
            let ro = order[rhs.id] ?? Int.max
            if lo != ro { return lo < ro }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        return items
    }

    func window(id: CGWindowID) async -> SCWindow? {
        if let cached = cachedWindows.first(where: { $0.windowID == id }) { return cached }
        _ = try? await refresh()
        return cachedWindows.first(where: { $0.windowID == id })
    }

    func frontmost(focusedWindowID: CGWindowID?) async -> SCWindow? {
        let items = (try? await list(focusedWindowID: focusedWindowID)) ?? []
        return items.first?.window
    }

    /// Match an AX window (PID + title + frame) to a shareable SCWindow.
    func match(pid: pid_t, title: String, frame: CGRect) async -> SCWindow? {
        if let cached = bestMatch(in: cachedWindows, pid: pid, title: title, frame: frame) {
            return cached
        }
        _ = try? await refresh()
        return bestMatch(in: cachedWindows, pid: pid, title: title, frame: frame)
    }

    private func bestMatch(in windows: [SCWindow], pid: pid_t, title: String, frame: CGRect) -> SCWindow? {
        var candidates = windows.filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 }
        guard !candidates.isEmpty else { return nil }

        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty {
            let titled = candidates.filter { window in
                let value = window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return value == normalized || (!value.isEmpty && (value.contains(normalized) || normalized.contains(value)))
            }
            if !titled.isEmpty { candidates = titled }
        }

        if candidates.count == 1 { return candidates[0] }

        // AX and SCWindow frames are both global screen coordinates in points.
        // The tolerance is deliberately loose: shadow/titlebar differences vary by app.
        let target = CGPoint(x: frame.midX, y: frame.midY)
        let ranked = candidates.map { window -> (SCWindow, CGFloat) in
            let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
            let dx = center.x - target.x
            let dy = center.y - target.y
            let centerDistance = sqrt(dx * dx + dy * dy)
            let sizeDelta = abs(window.frame.width - frame.width) + abs(window.frame.height - frame.height)
            let inside = window.frame.insetBy(dx: -16, dy: -16).contains(target) ? 0 : 10_000
            return (window, centerDistance + sizeDelta * 0.1 + CGFloat(inside))
        }
        return ranked.min(by: { $0.1 < $1.1 })?.0
    }

    private func windowOrder() -> [CGWindowID: Int] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var order: [CGWindowID: Int] = [:]
        for (index, item) in list.enumerated() {
            if let number = item[kCGWindowNumber as String] as? NSNumber {
                order[number.uint32Value] = index
            }
        }
        return order
    }
}
