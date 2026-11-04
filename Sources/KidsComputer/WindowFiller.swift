#if os(macOS)
import AppKit
import ApplicationServices
import KidsComputerCore

/// Keeps the Dock out of the way for the child's account. See DockSetup for
/// why the launcher's own "hide the Dock" option stops working while an
/// activity is in front.
enum DockAutohide {
    private static var checked = false

    /// Turns on "Automatically hide and show the Dock" for this account if it
    /// is off. Runs once per launch, only while the desktop lock is on.
    static func ensureOn() {
        guard !checked else { return }
        checked = true
        let domain = DockSetup.dockDomain as CFString
        let key = DockSetup.autohideKey as CFString
        let current = CFPreferencesCopyAppValue(key, domain)
        guard DockSetup.needsAutohide(currentValue: current) else { return }
        CFPreferencesSetAppValue(key, kCFBooleanTrue, domain)
        guard CFPreferencesAppSynchronize(domain) else {
            FileLog.append("Couldn't save the Dock auto-hide setting.")
            return
        }
        // The Dock reads this setting when it starts. macOS restarts it at once.
        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["Dock"]
        do {
            try restart.run()
            FileLog.append("Turned on Dock auto-hide for this account.")
        } catch {
            FileLog.append("Saved Dock auto-hide, but couldn't restart the Dock: \(error.localizedDescription)")
        }
    }
}

/// Makes an activity's window fill the screen when it opens. macOS only lets
/// one app move another app's windows after a person allows it under
/// Privacy & Security → Accessibility. Without that, this does nothing.
enum WindowFiller {
    static var isAllowed: Bool { AXIsProcessTrusted() }

    /// Shows the macOS prompt that leads to the Accessibility list.
    static func askForPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func fillSoon(pid: pid_t) {
        guard isAllowed else { return }
        for delay in WindowFill.retryDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                fillNow(pid: pid)
            }
        }
    }

    private static func fillNow(pid: pid_t) {
        guard let primary = NSScreen.screens.first,
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let target = WindowFill.accessibilityRect(
            visible: WindowRect(
                x: Double(visible.origin.x),
                y: Double(visible.origin.y),
                width: Double(visible.size.width),
                height: Double(visible.size.height)
            ),
            primaryScreenHeight: Double(primary.frame.size.height)
        )
        let application = AXUIElementCreateApplication(pid)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }
        for window in windows {
            if isFullScreen(window) || !isStandardWindow(window) { continue }
            var origin = CGPoint(x: target.x, y: target.y)
            var size = CGSize(width: target.width, height: target.height)
            if let value = AXValueCreate(.cgPoint, &origin) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
            }
            if let value = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
            }
        }
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private static func isStandardWindow(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &value) == .success,
              let subrole = value as? String else { return true }
        return subrole == (kAXStandardWindowSubrole as String)
    }
}
#endif
