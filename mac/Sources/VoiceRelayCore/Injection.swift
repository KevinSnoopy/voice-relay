import Foundation
import CoreFoundation
import AppKit
import ApplicationServices
import Carbon
import IOKit.hid
import CoreBluetooth
import CoreGraphics

public enum InjectPath: String {
    case ax
    case unicode
    case paste
    case clipboard
    case none
}

public struct InjectOutcome {
    public var ok: Bool
    public var path: InjectPath
    public var reason: String?
    public var frontBundleId: String?

    public init(ok: Bool, path: InjectPath, reason: String? = nil, frontBundleId: String? = nil) {
        self.ok = ok
        self.path = path
        self.reason = reason
        self.frontBundleId = frontBundleId
    }
}

public protocol TextInjecting: AnyObject {
    func inject(_ text: String) -> InjectOutcome
}

public final class TextInjector: TextInjecting {
    private let allowPasteFallback: Bool

    public init(allowPasteFallback: Bool = false) {
        self.allowPasteFallback = allowPasteFallback
    }

    public func inject(_ text: String) -> InjectOutcome {
        guard !text.isEmpty else { return InjectOutcome(ok: false, path: .clipboard, reason: "empty_text") }
        let front = NSWorkspace.shared.frontmostApplication
        let bundleId = front?.bundleIdentifier

        if IsSecureEventInputEnabled() {
            return InjectOutcome(ok: false, path: .none, reason: "secure_input", frontBundleId: bundleId)
        }
        guard AXIsProcessTrusted(), let front else {
            return InjectOutcome(ok: false, path: .none, reason: "no_accessibility", frontBundleId: bundleId)
        }

        let pid = front.processIdentifier
        guard let element = AXFocus.injectionTarget(pid: pid) else {
            return InjectOutcome(ok: false, path: .none, reason: "no_focus", frontBundleId: bundleId)
        }
        let webEditable = AXFocus.isWebEditable(element)
        if webEditable, injectViaUnicode(text, pid: pid, element: element) {
            return InjectOutcome(ok: true, path: .unicode, frontBundleId: bundleId)
        }
        if !webEditable, injectViaAX(text, element: element) {
            return InjectOutcome(ok: true, path: .ax, frontBundleId: bundleId)
        }
        if !webEditable, injectViaUnicode(text, pid: pid, element: element) {
            return InjectOutcome(ok: true, path: .unicode, frontBundleId: bundleId)
        }
        if (webEditable || allowPasteFallback), injectViaPaste(text, pid: pid, element: element) {
            return InjectOutcome(ok: true, path: .paste, frontBundleId: bundleId)
        }
        return InjectOutcome(ok: false, path: .none, reason: "direct_injection_failed", frontBundleId: bundleId)
    }

    // MARK: - AX

    private func injectViaAX(_ text: String, element: AXUIElement) -> Bool {
        guard let original = AXFocus.stringValue(element) else { return false }
        guard let range = AXFocus.selectedRange(element) else { return false }

        let ns = original as NSString
        let safeLocation = min(max(0, range.location), ns.length)
        let safeLength = min(max(0, range.length), ns.length - safeLocation)
        let expected = ns.replacingCharacters(in: NSRange(location: safeLocation, length: safeLength), with: text)

        let inserted = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, expected as CFTypeRef) == .success
        guard inserted else { return false }
        AXFocus.setSelectedRange(element, location: safeLocation + (text as NSString).length)
        Thread.sleep(forTimeInterval: 0.12)
        guard let readback = AXFocus.stringValue(element), readback == expected else {
            _ = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, original as CFTypeRef)
            AXFocus.setSelectedRange(element, location: range.location)
            return false
        }
        return true
    }

    // MARK: - Unicode

    private func injectViaUnicode(_ text: String, pid: pid_t, element: AXUIElement) -> Bool {
        if let focused = AXFocus.focusedElement(pid: pid), CFEqual(focused, element) {
        } else {
            guard AXFocus.setFocused(element) else { return false }
        }
        guard let before = AXFocus.stringValue(element) else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let end = min(index + 20, characters.count)
            let chunk = String(characters[index..<end])
            var utf16 = Array(chunk.utf16)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return false
            }
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down.postToPid(pid)
            up.postToPid(pid)
            index = end
            usleep(6000)
        }
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            if let focused = AXFocus.focusedElement(pid: pid),
               let after = AXFocus.stringValue(focused), after != before && after.contains(text) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    // MARK: - Paste

    private func injectViaPaste(_ text: String, pid: pid_t, element: AXUIElement) -> Bool {
        if let focused = AXFocus.focusedElement(pid: pid), CFEqual(focused, element) {
        } else {
            guard AXFocus.setFocused(element) else { return false }
        }
        guard let before = AXFocus.stringValue(element) else { return false }
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { snapshot[type] = data }
            }
            return snapshot
        } ?? []

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return false }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            restorePasteboard(savedItems)
            return false
        }
        commandDown.postToPid(pid)
        usleep(30_000)
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        usleep(30_000)
        up.postToPid(pid)
        usleep(30_000)
        commandUp.postToPid(pid)

        let deadline = Date().addingTimeInterval(2.0)
        var delivered = false
        while Date() < deadline {
            if let focused = AXFocus.focusedElement(pid: pid),
               let after = AXFocus.stringValue(focused), after != before && after.contains(text) {
                delivered = true
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        restorePasteboard(savedItems)
        return delivered
    }

    private func restorePasteboard(_ savedItems: [[NSPasteboard.PasteboardType: Data]]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard !savedItems.isEmpty else { return }
        let items: [NSPasteboardItem] = savedItems.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }

    @discardableResult
    public func copyToClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

public enum AXFocus {
    public static func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    public static func stringValue(_ element: AXUIElement) -> String? {
        copyAttribute(element, kAXValueAttribute) as? String
    }

    public static func role(_ element: AXUIElement) -> String? {
        copyAttribute(element, kAXRoleAttribute) as? String
    }

    public static func isTextual(_ element: AXUIElement) -> Bool {
        guard let role = role(element) else { return false }
        return role == kAXTextFieldRole || role == kAXTextAreaRole || role == "AXComboBox" || role == "AXSearchField"
    }

    public static func canFocus(_ element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, kAXFocusedAttribute as CFString, &settable) == .success && settable.boolValue
    }

    public static func isEditable(_ element: AXUIElement) -> Bool {
        guard let role = role(element) else { return false }
        if role == kAXTextFieldRole || role == kAXTextAreaRole || role == "AXComboBox" {
            if let settable = copyAttribute(element, kAXValueAttribute) as? String, !settable.isEmpty {
                // value exists; editable check below still applies
            }
            var settable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success {
                return settable.boolValue
            }
            return true
        }
        return false
    }

    public static func focusedElement(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        return copyAttribute(app, kAXFocusedUIElementAttribute) as! AXUIElement?
    }

    public static func focusedString(pid: pid_t) -> String? {
        guard let element = focusedElement(pid: pid) else { return nil }
        return stringValue(element)
    }

    public static func isWebEditable(_ element: AXUIElement) -> Bool {
        copyAttribute(element, "AXDOMClassList") != nil
    }

    public static func injectionTarget(pid: pid_t) -> AXUIElement? {
        if let focused = focusedElement(pid: pid), isEditable(focused) {
            return focused
        }
        return firstEditableElement(pid: pid)
    }

    public static func setFocused(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    }

    public static func raiseWindow(for element: AXUIElement) {
        guard let windowValue = copyAttribute(element, kAXWindowAttribute) else { return }
        let window = windowValue as! AXUIElement
        var pid: pid_t = 0
        _ = AXUIElementGetPid(element, &pid)
        let app = AXUIElementCreateApplication(pid)
        let focusedWindow = copyAttribute(app, kAXFocusedWindowAttribute)
        let sameWindow = focusedWindow.map { CFEqual($0, window) } ?? false
        if !sameWindow {
            _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            usleep(50_000)
        }
    }

    public static func selectedRange(_ element: AXUIElement) -> NSRange? {
        guard let value = copyAttribute(element, kAXSelectedTextRangeAttribute) else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    public static func setSelectedRange(_ element: AXUIElement, location: Int) {
        var range = CFRange(location: location, length: 0)
        guard let value = AXValueCreate(.cfRange, &range) else { return }
        AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
    }

    public static func descriptor(_ element: AXUIElement) -> String? {
        let role = role(element) ?? ""
        let roleName: String
        switch role {
        case kAXTextFieldRole:
            roleName = "文本输入框"
        case kAXTextAreaRole:
            roleName = "文本区"
        case "AXComboBox":
            roleName = "下拉输入框"
        default:
            roleName = role.isEmpty ? "焦点" : role
        }
        for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXPlaceholderValueAttribute] {
            if let value = copyAttribute(element, attribute) as? String, !value.isEmpty {
                return "\(roleName) · \(value)"
            }
        }
        return roleName
    }

    public static func firstEditableElement(pid: pid_t) -> AXUIElement? {
        let elements = allEditableElements(pid: pid)
        return elements.first(where: { role($0) == kAXTextAreaRole }) ?? elements.first
    }

    public static func allEditableElements(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var results: [AXUIElement] = []
        let visited = NSHashTable<AnyObject>(options: [.strongMemory])

        func walk(_ element: AXUIElement, depth: Int) {
            guard depth < 64 else { return }
            let object = element as AnyObject
            guard !visited.contains(object) else { return }
            visited.add(object)
            if isEditable(element) || (isTextual(element) && canFocus(element)) { results.append(element) }
            guard let children = copyAttribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
            for child in children { walk(child, depth: depth + 1) }
        }

        if let windows = copyAttribute(app, kAXWindowsAttribute) as? [AXUIElement] {
            for window in windows { walk(window, depth: 0) }
        }
        if results.isEmpty, let focused = focusedElement(pid: pid), isEditable(focused) || (isTextual(focused) && canFocus(focused)) {
            results.append(focused)
        }
        return results
    }
}

public struct FocusTarget {
    public var appName: String
    public var bundleId: String
    public var detail: String
    public var editable: Bool

    public init(appName: String, bundleId: String, detail: String, editable: Bool) {
        self.appName = appName
        self.bundleId = bundleId
        self.detail = detail
        self.editable = editable
    }
}

public struct CommandResult {
    public var ok: Bool
    public var code: String
    public var detail: String?

    public init(ok: Bool, code: String, detail: String? = nil) {
        self.ok = ok
        self.code = code
        self.detail = detail
    }
}

public final class AppController {
    private let injector: TextInjector
    private let settings: AppSettings

    public init(injector: TextInjector = TextInjector(), settings: AppSettings = .load()) {
        self.injector = injector
        self.settings = settings
    }

    public func frontApp() -> (name: String, bundleId: String, pid: pid_t)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return (app.localizedName ?? app.bundleIdentifier ?? "未知", app.bundleIdentifier ?? "", app.processIdentifier)
    }

    public func focusTarget() -> FocusTarget {
        guard let front = frontApp() else {
            return FocusTarget(appName: "未知", bundleId: "", detail: "", editable: false)
        }
        guard let element = AXFocus.focusedElement(pid: front.pid) else {
            return FocusTarget(appName: front.name, bundleId: front.bundleId, detail: "", editable: false)
        }
        return FocusTarget(
            appName: front.name,
            bundleId: front.bundleId,
            detail: AXFocus.descriptor(element) ?? "",
            editable: AXFocus.isEditable(element)
        )
    }

    public func switchApp(bundleId: String) -> CommandResult {
        let target: NSRunningApplication
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            target = running
        } else {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                return CommandResult(ok: false, code: "not_found", detail: bundleId)
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            let semaphore = DispatchSemaphore(value: 0)
            var launched: NSRunningApplication?
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, _ in
                launched = app
                app?.activate(options: [.activateIgnoringOtherApps])
                semaphore.signal()
            }
            guard semaphore.wait(timeout: .now() + 2) == .success, let app = launched else {
                return CommandResult(ok: false, code: "launch_timeout", detail: bundleId)
            }
            target = app
        }
        let name = target.localizedName ?? bundleId
        guard let visible = bringAppToFront(target) else {
            return CommandResult(ok: false, code: "foreground_failed", detail: "无法将 \(name) 置顶")
        }
        focusFirstInput(pid: visible.pid)
        return CommandResult(ok: true, code: "ok", detail: "已切换到 \(visible.name)")
    }

    public func switchToAdjacentApp(backwards: Bool) -> CommandResult {
        guard let before = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        guard let target = adjacentRunningApp(to: before, backwards: backwards) else {
            return CommandResult(ok: false, code: "no_other_app", detail: before.name)
        }
        let name = target.localizedName ?? target.bundleIdentifier ?? "未知 App"
        guard let visible = bringAppToFront(target) else {
            return CommandResult(ok: false, code: "foreground_failed", detail: "无法将 \(name) 置顶")
        }
        focusFirstInput(pid: visible.pid)
        return CommandResult(ok: true, code: "ok", detail: "已切换到 \(visible.name)")
    }

    private func adjacentRunningApp(to current: (name: String, bundleId: String, pid: pid_t), backwards: Bool) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated && $0.bundleIdentifier != nil }
            .sorted { ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast) }
        guard apps.count > 1 else { return nil }
        let index = apps.firstIndex { $0.processIdentifier == current.pid } ?? (backwards ? 0 : -1)
        let offset = backwards ? -1 : 1
        return apps[(index + offset + apps.count) % apps.count]
    }

    public func switchToNextWindow() -> CommandResult {
        guard AXIsProcessTrusted() else {
            return CommandResult(ok: false, code: "no_accessibility", detail: "需要辅助功能权限")
        }
        guard frontApp() != nil else { return CommandResult(ok: false, code: "no_app") }
        guard postSystemShortcut(keyCode: 50, flags: [.maskCommand]) else {
            return CommandResult(ok: false, code: "event_failed")
        }
        Thread.sleep(forTimeInterval: 0.3)
        guard let target = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        guard let running = NSRunningApplication(processIdentifier: target.pid) else {
            return CommandResult(ok: false, code: "app_not_running", detail: target.name)
        }
        guard let visible = bringAppToFront(running) else {
            return CommandResult(ok: false, code: "foreground_failed", detail: "无法将 \(target.name) 置顶")
        }
        focusFirstInput(pid: visible.pid)
        return CommandResult(ok: true, code: "window_switch_sent", detail: "已发送窗口切换 · \(visible.name)")
    }

    private func bringAppToFront(_ app: NSRunningApplication) -> (name: String, bundleId: String, pid: pid_t)? {
        app.unhide()
        _ = app.activate(options: [.activateIgnoringOtherApps])
        if let visible = waitForFrontApp(bundleId: app.bundleIdentifier ?? "", pid: app.processIdentifier, timeout: 1.0) {
            return visible
        }
        guard let bundleId = app.bundleIdentifier, !bundleId.isEmpty else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", bundleId]
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        do {
            try process.run()
            if semaphore.wait(timeout: .now() + 2) == .success, process.terminationStatus == 0 {
                return waitForFrontApp(bundleId: bundleId, pid: app.processIdentifier, timeout: 1.5)
            }
            if process.isRunning { process.terminate() }
        } catch {
            return nil
        }
        return nil
    }

    /// After an app/window switch, prefer the first editable field when the
    /// target app has no textual focus. This makes multi-input pages usable
    /// without an extra tap; focusNext can still cycle through the fields.
    private func focusFirstInput(pid: pid_t) {
        let deadline = Date().addingTimeInterval(3.5)
        var stableSince = Date()
        var tabSent = false
        while Date() < deadline {
            guard let front = frontApp(), front.pid == pid else {
                stableSince = Date()
                Thread.sleep(forTimeInterval: 0.05)
                continue
            }
            if Date().timeIntervalSince(stableSince) >= 0.25 {
                if let focused = AXFocus.focusedElement(pid: pid), AXFocus.isEditable(focused) {
                    _ = AXFocus.setFocused(focused)
                    return
                }
                if let first = AXFocus.firstEditableElement(pid: pid) {
                    AXFocus.raiseWindow(for: first)
                    if AXFocus.setFocused(first) { return }
                }
                if settings.focusTabFallback, !tabSent {
                    tabSent = true
                    _ = postKey(48, pid: pid)
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    private func waitForFrontApp(bundleId: String, pid: pid_t? = nil, timeout: TimeInterval = 1.5) -> (name: String, bundleId: String, pid: pid_t)? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let front = frontApp(), (front.bundleId == bundleId || (pid != nil && front.pid == pid!)) {
                return front
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard let front = frontApp() else { return nil }
        return front.bundleId == bundleId || (pid != nil && front.pid == pid!) ? front : nil
    }

    public func activateInputCursor() -> CommandResult {
        guard AXIsProcessTrusted() else {
            return CommandResult(ok: false, code: "no_accessibility", detail: "需要辅助功能权限")
        }
        guard let front = frontApp(), let running = NSRunningApplication(processIdentifier: front.pid) else {
            return CommandResult(ok: false, code: "no_app")
        }
        _ = bringAppToFront(running)
        Thread.sleep(forTimeInterval: 0.2)
        guard let visible = frontApp() else { return CommandResult(ok: false, code: "no_app") }

        if let focused = AXFocus.focusedElement(pid: visible.pid), AXFocus.isTextual(focused), AXFocus.setFocused(focused) {
            let descriptor = AXFocus.descriptor(focused) ?? "文本输入区"
            return CommandResult(ok: true, code: "ok", detail: "\(visible.name) · 光标已激活 · \(descriptor)")
        }

        let elements = AXFocus.allEditableElements(pid: visible.pid)
        if elements.isEmpty, let focused = AXFocus.focusedElement(pid: visible.pid), AXFocus.canFocus(focused), AXFocus.setFocused(focused) {
            return CommandResult(ok: true, code: "ok", detail: "\(visible.name) · 焦点已激活")
        }
        if elements.isEmpty, settings.focusTabFallback, postKey(48, pid: visible.pid) {
            return CommandResult(ok: true, code: "tab_sent", detail: "\(visible.name) · 已发送 Tab 尝试激活输入焦点")
        }
        guard !elements.isEmpty else {
            return CommandResult(ok: false, code: "no_field", detail: "\(visible.name) 未暴露输入焦点，请先点一下输入框")
        }
        let focused = AXFocus.focusedElement(pid: visible.pid)
        let target = focused.flatMap { element in
            elements.first(where: { CFEqual($0, element) })
        } ?? elements[0]
        AXFocus.raiseWindow(for: target)
        guard AXFocus.setFocused(target) else {
            return CommandResult(ok: false, code: "focus_failed", detail: visible.name)
        }
        let descriptor = AXFocus.descriptor(target) ?? "输入框"
        return CommandResult(ok: true, code: "ok", detail: "\(visible.name) · 光标已激活 · \(descriptor)")
    }

    public func focusNext(backwards: Bool = false) -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        let elements = AXFocus.allEditableElements(pid: front.pid)
        guard !elements.isEmpty else {
            if settings.focusTabFallback {
                return pressTab(backwards: backwards)
            }
            return CommandResult(ok: false, code: "no_field")
        }
        let focused = AXFocus.focusedElement(pid: front.pid)
        let currentIndex = focused.flatMap { current in elements.firstIndex(where: { CFEqual($0, current) }) }
        let nextIndex: Int
        if let currentIndex {
            nextIndex = (currentIndex + (backwards ? -1 : 1) + elements.count) % elements.count
        } else {
            nextIndex = backwards ? elements.count - 1 : 0
        }
        let target = elements[nextIndex]
        AXFocus.raiseWindow(for: target)
        let ok = AXFocus.setFocused(target)
        if !ok, settings.focusTabFallback {
            return pressTab(backwards: backwards)
        }
        return CommandResult(ok: ok, code: ok ? "ok" : "focus_failed", detail: ok ? "已切换输入框 · \(front.name) \(nextIndex + 1)/\(elements.count)" : front.name)
    }

    public func pressReturn() -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        let ok = postKey(36, pid: front.pid)
        return CommandResult(ok: ok, code: ok ? "ok" : "event_failed", detail: ok ? "\(front.name) · 已发送回车" : nil)
    }

    public func shiftReturn() -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        let ok = postKey(36, pid: front.pid, flags: .maskShift)
        return CommandResult(ok: ok, code: ok ? "ok" : "event_failed", detail: ok ? "\(front.name) · 已发送 Shift+回车" : nil)
    }

    public func backspace(count: Int) -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        for _ in 0..<max(0, min(count, 100)) {
            guard postKey(51, pid: front.pid) else {
                return CommandResult(ok: false, code: "event_failed")
            }
            usleep(8000)
        }
        return CommandResult(ok: true, code: "ok")
    }

    public func selectAll() -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        let ok = postKey(0, pid: front.pid, flags: .maskCommand)
        return CommandResult(ok: ok, code: ok ? "ok" : "event_failed")
    }

    public func undo() -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        let ok = postKey(6, pid: front.pid, flags: .maskCommand)
        return CommandResult(ok: ok, code: ok ? "ok" : "event_failed")
    }

    public func copy(_ text: String) -> CommandResult {
        let ok = injector.copyToClipboard(text)
        return CommandResult(ok: ok, code: ok ? "ok" : "clipboard_failed")
    }

    private func pressTab(backwards: Bool) -> CommandResult {
        guard let front = frontApp() else { return CommandResult(ok: false, code: "no_app") }
        let ok = postKey(48, pid: front.pid, flags: backwards ? .maskShift : [])
        return CommandResult(ok: ok, code: ok ? "tab" : "event_failed")
    }

    @discardableResult
    private func postSystemShortcut(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return false }
        commandDown.flags = .maskCommand
        commandUp.flags = .maskCommand
        keyDown.flags = flags
        keyUp.flags = flags
        commandDown.post(tap: .cghidEventTap)
        usleep(50_000)
        keyDown.post(tap: .cghidEventTap)
        usleep(50_000)
        keyUp.post(tap: .cghidEventTap)
        usleep(50_000)
        commandUp.post(tap: .cghidEventTap)
        return true
    }

    @discardableResult
    private func postKey(_ keyCode: CGKeyCode, pid: pid_t, flags: CGEventFlags = []) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        func post(_ code: CGKeyCode, keyDown: Bool, eventFlags: CGEventFlags) -> Bool {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: keyDown) else { return false }
            event.flags = eventFlags
            event.postToPid(pid)
            usleep(20_000)
            return true
        }

        let modifiers: [(CGKeyCode, CGEventFlags)] = [
            (59, .maskControl),
            (58, .maskAlternate),
            (56, .maskShift),
            (55, .maskCommand),
        ]
        let pressed = modifiers.filter { flags.contains($0.1) }
        for (code, _) in pressed {
            guard post(code, keyDown: true, eventFlags: []) else { return false }
        }
        guard post(keyCode, keyDown: true, eventFlags: flags),
              post(keyCode, keyDown: false, eventFlags: flags) else { return false }
        for (code, _) in pressed.reversed() {
            guard post(code, keyDown: false, eventFlags: []) else { return false }
        }
        return true
    }
}

public enum Permissions {
    public enum Status: String {
        case granted
        case denied
        case unknown
    }

    public static var accessibility: Status {
        AXIsProcessTrusted() ? .granted : .denied
    }

    public static var inputMonitoring: Status {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch access {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .unknown
        }
    }

    public static var screenRecording: Status {
        CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    public static var bluetooth: Status {
        switch CBManager.authorization {
        case .allowedAlways: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    public static var summary: [String: Bool] {
        [
            "accessibility": accessibility == .granted,
            "input_monitoring": inputMonitoring == .granted,
            "bluetooth": bluetooth == .granted,
            "screen_recording": screenRecording == .granted,
        ]
    }

    public static func openSettings(_ anchor: String) {
        let map = [
            "accessibility": "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "input_monitoring": "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "bluetooth": "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
            "screen_recording": "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        guard let string = map[anchor], let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    public static func requestScreenRecordingPrompt() {
        _ = CGRequestScreenCaptureAccess()
    }

    public static func requestAccessibilityPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
