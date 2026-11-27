import AppKit
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

/// Best-effort mapping from the AX text caret/focused element to a shareable window.
final class FocusTracker {
    struct FocusedWindow {
        let pid: pid_t
        let title: String
        let frame: CGRect
    }

    func focusedWindow(catalog: WindowCatalog) async -> SCWindow? {
        guard AXIsProcessTrusted() else { return nil }
        guard let info = readFocusedWindow() else { return nil }
        return await catalog.match(pid: info.pid, title: info.title, frame: info.frame)
    }

    private func readFocusedWindow() -> FocusedWindow? {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else { return nil }
        let focused = focusedRef as! AXUIElement

        var windowElement: AXUIElement?
        var directWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXWindowAttribute as CFString, &directWindowRef) == .success,
           let directWindowRef {
            windowElement = (directWindowRef as! AXUIElement)
        }

        if windowElement == nil {
            var current: AXUIElement = focused
            for _ in 0..<8 {
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String, role == "AXWindow" {
                    windowElement = current
                    break
                }
                var parentRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                      let parentRef else { break }
                current = parentRef as! AXUIElement
            }
        }

        guard let window = windowElement else { return nil }

        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid > 0 else { return nil }

        var titleRef: CFTypeRef?
        let title: String
        if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
           let value = titleRef as? String {
            title = value
        } else {
            title = ""
        }

        guard let frame = frame(of: window) else { return nil }
        return FocusedWindow(pid: pid, title: title, frame: frame)
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionValue = positionRef,
              let sizeValue = sizeRef,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
}
