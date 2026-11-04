import Foundation

/// Why the Dock shows up over the launcher while an activity is open:
/// the kiosk presentation options (hide the Dock, hide the menu bar, and the
/// rest) belong to the launcher, and macOS only honors an app's presentation
/// options while that app is the active app. As soon as Chess or another
/// activity comes to the front, macOS goes back to the account's normal Dock
/// setting. If that setting is "always show", the Dock appears.
///
/// The fix that macOS allows is to change the account's own Dock setting to
/// "automatically hide and show", which applies to every app. The launcher
/// does that for the child's account while the desktop lock is on.
public enum DockSetup {
    public static let dockDomain = "com.apple.dock"
    public static let autohideKey = "autohide"

    /// Terminal command that puts the Dock back to always showing.
    public static let undoCommand = "defaults write com.apple.dock autohide -bool false; killall Dock"

    /// True when the stored Dock preference is not already "auto-hide on".
    /// A missing value means macOS's default, which is "always show".
    public static func needsAutohide(currentValue: Any?) -> Bool {
        switch currentValue {
        case let value as Bool:
            return !value
        case let value as NSNumber:
            return !value.boolValue
        case let value as String:
            return !["1", "true", "yes"].contains(value.lowercased())
        default:
            return true
        }
    }
}

/// A window rectangle in plain numbers so it can be tested off the Mac.
public struct WindowRect: Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum WindowFill {
    /// AppKit measures screens from the bottom-left corner of the main
    /// display. The Accessibility API measures windows from the top-left
    /// corner. This turns a screen's usable area (AppKit) into the window
    /// position and size to hand to the Accessibility API.
    public static func accessibilityRect(visible: WindowRect, primaryScreenHeight: Double) -> WindowRect {
        WindowRect(
            x: visible.x,
            y: primaryScreenHeight - (visible.y + visible.height),
            width: visible.width,
            height: visible.height
        )
    }

    /// How long after opening an activity to try sizing its window. Apps put
    /// their first window up at different speeds, so try a few times.
    public static let retryDelays: [Double] = [0.6, 1.5, 3.0]
}
