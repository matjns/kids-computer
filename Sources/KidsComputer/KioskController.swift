#if os(macOS)
import AppKit
import KidsComputerCore

final class KioskWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class KioskController {
    func apply(enforcing: Bool) {
        // NSApplication.shared is non-optional. NSApp's Swift type has been an
        // optional, an implicitly unwrapped optional, or a plain instance
        // depending on the SDK, and those forms do not compile interchangeably.
        let app = NSApplication.shared
        if enforcing {
            var options: NSApplication.PresentationOptions = []
            for restriction in KioskPolicy.restrictions {
                options.insert(option(for: restriction))
            }
            app.presentationOptions = options
        } else {
            app.presentationOptions = []
        }
    }

    private func option(for restriction: KioskRestriction) -> NSApplication.PresentationOptions {
        switch restriction {
        case .hideDock: return .hideDock
        case .hideMenuBar: return .hideMenuBar
        case .disableAppleMenu: return .disableAppleMenu
        case .disableProcessSwitching: return .disableProcessSwitching
        case .disableForceQuit: return .disableForceQuit
        case .disableSessionTermination: return .disableSessionTermination
        case .disableHideApplication: return .disableHideApplication
        }
    }
}
#endif
