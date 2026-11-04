import Foundation

public enum AppActivation: String, Equatable {
    case regular
    case accessory
    case prohibited
    case unknown
}

public struct ObservedApp: Equatable {
    public var bundleIdentifier: String?
    public var bundlePath: String?
    public var executablePath: String?
    public var activation: AppActivation
    public var isLauncher: Bool

    public init(
        bundleIdentifier: String? = nil,
        bundlePath: String? = nil,
        executablePath: String? = nil,
        activation: AppActivation,
        isLauncher: Bool = false
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.executablePath = executablePath
        self.activation = activation
        self.isLauncher = isLauncher
    }
}

public struct ApprovedTarget: Equatable {
    public var bundleIdentifier: String?
    public var applicationPath: String?

    public init(bundleIdentifier: String? = nil, applicationPath: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationPath = applicationPath
    }
}

public struct PolicyDecision: Equatable {
    public enum Action: String, Equatable {
        case allow
        case hide
        case terminate
    }

    public var action: Action
    public var reason: String

    public init(action: Action, reason: String) {
        self.action = action
        self.reason = reason
    }
}

public enum ProtectionList {
    public struct Parsed: Equatable {
        public var exact: Set<String>
        public var prefixes: [String]
    }

    public static func parse(_ lines: [String]) -> Parsed {
        var exact: Set<String> = []
        var prefixes: [String] = []
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if line.isEmpty { continue }
            if line.hasSuffix(".*") {
                prefixes.append(String(line.dropLast()))
            } else if line.hasSuffix("*") {
                prefixes.append(String(line.dropLast()))
            } else {
                exact.insert(line)
            }
        }
        return Parsed(exact: exact, prefixes: prefixes)
    }
}

public enum AppPolicy {
    /// Regular system UI that must stay alive. Finder, Safari, System Settings,
    /// and other everyday apps are intentionally absent: the launcher closes them.
    public static let builtinExact: Set<String> = [
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.loginwindow",
        "com.apple.securityagent",
        "com.apple.coreservices.uiagent",
        "com.apple.usernotificationcenter",
        "com.apple.windowmanager",
        "com.apple.wallpaper.agent",
        "com.apple.screentimeagent",
        "com.apple.screentimewidgetapplication",
        "com.apple.osduihelper",
        "com.apple.spotlight",
        "com.apple.siri",
        "com.apple.sirincservice",
        "com.apple.voiceover",
        "com.apple.universalaccesscontrol",
        "com.apple.universalaccessauthwarn",
        "com.apple.textinputmenuagent",
        "com.apple.textinputswitcher",
        "com.apple.characterpaletteim",
        "com.apple.pressandhold",
        "com.apple.airplayuiagent",
        "com.apple.sharing.sharesheetui",
        "com.apple.viewbridgeauxiliary",
        "com.apple.talagent",
        "com.apple.authenticationservices.authenticationservicesagent",
        "com.apple.localauthentication.uiagent",
        "com.apple.installer",
        "com.apple.problemreporter",
        "com.apple.reportcrash",
        "com.apple.familycontrolsagent",
        "com.apple.askpermissionui",
        "com.apple.powerchime",
    ]

    public static let builtinPrefixes: [String] = [
        "com.apple.inputmethod.",
        "com.apple.webkit.",
        "com.apple.siri.",
        "com.apple.screentime",
        "com.apple.family",
        "com.apple.familycontrols",
        "com.apple.managedsettings",
        "com.apple.localauthentication",
        "com.apple.security.",
        "com.apple.authenticationservices.",
        "com.apple.coreservices.",
        "com.apple.accessibility.",
        "com.apple.voiceover",
        "com.apple.wallpaper.",
        "com.apple.windowmanager",
        "com.apple.installassistant",
        "com.apple.softwareupdate",
        "com.apple.mobiledevice",
        "com.apple.bluetooth",
        "com.apple.wifi.",
        "com.apple.airplay",
        "com.apple.sharing.",
        "com.apple.viewbridge",
        "com.apple.corecdp",
        "com.apple.appleid",
        "com.apple.icloud",
        "com.apple.askpermission",
        "com.apple.notificationcenter",
        "com.apple.usernotification",
        "com.apple.textinput",
        "com.apple.universalaccess",
    ]

    public static func decide(
        app: ObservedApp,
        approved: [ApprovedTarget],
        extraProtected: [String] = [],
        enforcing: Bool,
        launcherBundleID: String = LauncherRelease.bundleID
    ) -> PolicyDecision {
        if !enforcing {
            return PolicyDecision(action: .allow, reason: "enforcement-off")
        }
        if app.isLauncher {
            return PolicyDecision(action: .allow, reason: "launcher")
        }
        if let bundleID = cleaned(app.bundleIdentifier),
           bundleID.caseInsensitiveCompare(launcherBundleID) == .orderedSame {
            return PolicyDecision(action: .allow, reason: "launcher-bundle-id")
        }
        if let bundleID = cleaned(app.bundleIdentifier), matchesApprovedBundle(bundleID, approved: approved) {
            return PolicyDecision(action: .allow, reason: "approved-bundle-id")
        }
        if pathMatchesApproved(app, approved: approved) {
            return PolicyDecision(action: .allow, reason: "inside-approved-bundle")
        }
        if let bundleID = cleaned(app.bundleIdentifier), matchesProtected(bundleID, extras: extraProtected) {
            return PolicyDecision(action: .allow, reason: "protected-system")
        }
        if let bundleID = cleaned(app.bundleIdentifier), bundleID.caseInsensitiveCompare("com.apple.finder") == .orderedSame {
            // macOS relaunches Finder as soon as it is quit. Hiding it avoids a kill loop.
            return PolicyDecision(action: .hide, reason: "relaunching-system-app")
        }
        switch app.activation {
        case .accessory, .prohibited:
            return PolicyDecision(action: .allow, reason: "background-agent")
        case .regular, .unknown:
            return PolicyDecision(action: .terminate, reason: "unapproved-app")
        }
    }

    public static func matchesApprovedBundle(_ bundleID: String, approved: [ApprovedTarget]) -> Bool {
        let child = bundleID.lowercased()
        guard !child.isEmpty else { return false }
        for target in approved {
            guard let parent = cleaned(target.bundleIdentifier)?.lowercased(), !parent.isEmpty else { continue }
            if child == parent || child.hasPrefix(parent + ".") {
                return true
            }
        }
        return false
    }

    public static func pathIsInsideAppBundle(_ candidate: String, bundlePath: String) -> Bool {
        let child = normalize(candidate)
        let parent = normalize(bundlePath)
        guard !child.isEmpty, !parent.isEmpty else { return false }
        return child == parent || child.hasPrefix(parent + "/")
    }

    static func pathMatchesApproved(_ app: ObservedApp, approved: [ApprovedTarget]) -> Bool {
        let candidates = [app.bundlePath, app.executablePath].compactMap { $0 }
        for target in approved {
            guard let bundlePath = cleaned(target.applicationPath) else { continue }
            for candidate in candidates where pathIsInsideAppBundle(candidate, bundlePath: bundlePath) {
                return true
            }
        }
        return false
    }

    static func matchesProtected(_ bundleID: String, extras: [String]) -> Bool {
        let id = bundleID.lowercased()
        if builtinExact.contains(id) { return true }
        if builtinPrefixes.contains(where: { id.hasPrefix($0) }) { return true }
        let parsed = ProtectionList.parse(extras)
        if parsed.exact.contains(id) { return true }
        if parsed.prefixes.contains(where: { id.hasPrefix($0) }) { return true }
        return false
    }

    static func cleaned(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func normalize(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.count > 1 && value.hasSuffix("/") {
            value.removeLast()
        }
        return value.lowercased()
    }
}

public enum AppLocation {
    public static func resolve(
        bundleIdentifier: String?,
        applicationPath: String?,
        lookupBundlePath: (String) -> String?,
        fileExists: (String) -> Bool
    ) -> String? {
        if let bundleID = blankToNil(bundleIdentifier),
           let found = lookupBundlePath(bundleID),
           fileExists(found) {
            return found
        }
        if let path = blankToNil(applicationPath), fileExists(path) {
            return path
        }
        return nil
    }

    private static func blankToNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

public enum TileIconChoice: Equatable {
    case customFile(String)
    case application(String)
    case symbol(String)
}

public func chooseTileIcon(tile: Tile, installedPath: String?, customIconExists: Bool) -> TileIconChoice {
    if customIconExists, let path = tile.customIconPath, !path.isEmpty {
        return .customFile(path)
    }
    if let installedPath, !installedPath.isEmpty {
        return .application(installedPath)
    }
    return .symbol(tile.symbolName)
}

public enum KioskRestriction: String, CaseIterable, Equatable {
    case hideDock
    case hideMenuBar
    case disableAppleMenu
    case disableProcessSwitching
    case disableForceQuit
    case disableSessionTermination
    case disableHideApplication
}

public enum KioskPolicy {
    /// The borderless window already covers every display. Do not add the
    /// fullscreen presentation option here: AppKit raises an exception if it
    /// is combined with hiding the Dock and the menu bar. This set matches
    /// Apple's kiosk sample (hide Dock and menu bar, then block switching,
    /// Force Quit, logout, and Hide).
    public static let restrictions = KioskRestriction.allCases
}

public enum ParentGesture {
    public static let requiredCornerTaps = 5
    public static let cornerTapWindow: TimeInterval = 4
    public static let chordDescription = "Control-Option-Command-P"

    public static func isParentChord(control: Bool, option: Bool, command: Bool, character: String) -> Bool {
        control && option && command && character.lowercased() == "p"
    }

    public static func registerTap(at date: Date, history: inout [Date]) -> Bool {
        history.append(date)
        let cutoff = date.addingTimeInterval(-cornerTapWindow)
        history.removeAll { $0 < cutoff }
        if history.count >= requiredCornerTaps {
            history.removeAll()
            return true
        }
        return false
    }
}

public enum LaunchAgentManifest {
    public static let label = "com.kidscomputer.launcher"

    public static func xml(executablePath: String) -> String {
        let escaped = executablePath
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let lines = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
            "<plist version=\"1.0\">",
            "<dict>",
            "    <key>Label</key>",
            "    <string>\(LaunchAgentManifest.label)</string>",
            "    <key>ProgramArguments</key>",
            "    <array>",
            "        <string>\(escaped)</string>",
            "    </array>",
            "    <key>RunAtLoad</key>",
            "    <true/>",
            "    <key>LimitLoadToSessionType</key>",
            "    <string>Aqua</string>",
            "    <key>ProcessType</key>",
            "    <string>Interactive</string>",
            "    <key>ThrottleInterval</key>",
            "    <integer>10</integer>",
            "    <key>KeepAlive</key>",
            "    <dict>",
            "        <key>SuccessfulExit</key>",
            "        <false/>",
            "    </dict>",
            "</dict>",
            "</plist>",
        ]
        return lines.joined(separator: "\n") + "\n"
    }
}
