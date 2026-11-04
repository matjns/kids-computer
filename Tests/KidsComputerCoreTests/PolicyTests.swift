import XCTest
@testable import KidsComputerCore

final class PolicyTests: XCTestCase {
    private var approved: [ApprovedTarget] {
        [
            ApprovedTarget(bundleIdentifier: "com.racetime.fsae", applicationPath: "/Applications/RaceTime.app"),
            ApprovedTarget(bundleIdentifier: "com.apple.Chess", applicationPath: "/System/Applications/Chess.app"),
        ]
    }

    func testApprovedAppsAndTheirHelpersStay() {
        XCTAssertEqual(decide(bundleID: "com.racetime.fsae", path: "/Applications/RaceTime.app"), .allow)
        XCTAssertEqual(
            decide(
                bundleID: "com.racetime.fsae.helper.GPU",
                path: "/Applications/RaceTime.app/Contents/Frameworks/RaceTime Helper (GPU).app",
                activation: .regular
            ),
            .allow
        )
        XCTAssertEqual(
            decide(
                bundleID: nil,
                path: "/Applications/RaceTime.app/Contents/Frameworks/RaceTime Helper.app",
                activation: .regular
            ),
            .allow
        )
        XCTAssertEqual(decide(bundleID: "com.apple.Chess", path: "/System/Applications/Chess.app"), .allow)
    }

    func testLookalikeBundleIDsAndPathsAreNotApproved() {
        XCTAssertEqual(decide(bundleID: "com.racetime.fsaehelper", path: "/Applications/Fake.app"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.example.game", path: "/Applications/RaceTime.app.evil"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.apple.ChessCoach", path: "/Applications/ChessCoach.app"), .terminate)
    }

    func testEverydayAppsAreClosedAndSystemUIStays() {
        let finder = AppPolicy.decide(
            app: ObservedApp(
                bundleIdentifier: "com.apple.finder",
                bundlePath: "/System/Library/CoreServices/Finder.app",
                activation: .regular
            ),
            approved: approved,
            enforcing: true
        )
        XCTAssertEqual(finder.action, .hide)
        XCTAssertEqual(finder.reason, "relaunching-system-app")
        XCTAssertEqual(decide(bundleID: "com.apple.Safari", path: "/Applications/Safari.app"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.apple.SystemSettings", path: "/System/Applications/System Settings.app"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.apple.systempreferences", path: "/System/Applications/System Preferences.app"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app"), .terminate)
        XCTAssertEqual(decide(bundleID: "com.apple.dock", path: "/System/Library/CoreServices/Dock.app"), .allow)
        XCTAssertEqual(decide(bundleID: "com.apple.SecurityAgent", path: nil, activation: .regular), .allow)
        XCTAssertEqual(decide(bundleID: "com.apple.WebKit.WebContent", path: nil, activation: .prohibited), .allow)
        XCTAssertEqual(decide(bundleID: "com.apple.inputmethod.Kotoeri.RomajiTyping", path: nil, activation: .accessory), .allow)
    }

    func testBackgroundAgentsAreLeftAloneEvenIfUnknown() {
        XCTAssertEqual(
            decide(bundleID: "com.example.helper", path: "/Library/Application Support/Helper.app", activation: .accessory),
            .allow
        )
        XCTAssertEqual(
            decide(bundleID: "com.example.secret", path: "/Applications/Secret.app", activation: .unknown),
            .terminate
        )
    }

    func testLauncherAndPausedEnforcement() {
        let launcher = ObservedApp(
            bundleIdentifier: LauncherRelease.bundleID,
            bundlePath: "/Applications/Kids Computer.app",
            activation: .regular,
            isLauncher: true
        )
        XCTAssertEqual(AppPolicy.decide(app: launcher, approved: [], enforcing: true).action, .allow)
        let safari = ObservedApp(bundleIdentifier: "com.apple.Safari", activation: .regular)
        XCTAssertEqual(AppPolicy.decide(app: safari, approved: approved, enforcing: false).reason, "enforcement-off")
    }

    func testParentCanAddAnExtraProtectedApp() {
        let decision = AppPolicy.decide(
            app: ObservedApp(bundleIdentifier: "com.example.KeepMe", activation: .regular),
            approved: approved,
            extraProtected: ["com.example.KeepMe", "com.example.tools.*"],
            enforcing: true
        )
        XCTAssertEqual(decision.action, .allow)
        let helper = AppPolicy.decide(
            app: ObservedApp(bundleIdentifier: "com.example.tools.agent", activation: .regular),
            approved: [],
            extraProtected: ["com.example.tools.*"],
            enforcing: true
        )
        XCTAssertEqual(helper.action, .allow)
    }

    func testDisabledTilesAreNotApprovedByTheConfigHelper() {
        var config = LauncherConfig.starter
        config.tiles[2].enabled = false
        let targets = config.approvedTargets()
        XCTAssertFalse(targets.contains { $0.bundleIdentifier == "com.apple.Chess" })
        XCTAssertTrue(targets.contains { $0.bundleIdentifier == "com.racetime.fsae" })
    }

    func testAppLocationPrefersBundleIDThenPath() {
        let resolved = AppLocation.resolve(
            bundleIdentifier: "com.apple.Chess",
            applicationPath: "/System/Applications/Chess.app",
            lookupBundlePath: { $0 == "com.apple.Chess" ? "/System/Applications/Chess.app" : nil },
            fileExists: { $0 == "/System/Applications/Chess.app" }
        )
        XCTAssertEqual(resolved, "/System/Applications/Chess.app")

        let comingSoon = AppLocation.resolve(
            bundleIdentifier: "com.kidscomputer.drawing",
            applicationPath: nil,
            lookupBundlePath: { _ in nil },
            fileExists: { _ in false }
        )
        XCTAssertNil(comingSoon)

        let pathFallback = AppLocation.resolve(
            bundleIdentifier: "com.wrong.id",
            applicationPath: "/Applications/RaceTime.app",
            lookupBundlePath: { _ in nil },
            fileExists: { $0 == "/Applications/RaceTime.app" }
        )
        XCTAssertEqual(pathFallback, "/Applications/RaceTime.app")
    }

    func testIconChoice() {
        let tile = Tile(
            id: "race-time",
            title: "Race Time",
            bundleIdentifier: "com.racetime.fsae",
            customIconPath: "/tmp/icon.png",
            symbolName: "flag.checkered"
        )
        XCTAssertEqual(chooseTileIcon(tile: tile, installedPath: "/Applications/RaceTime.app", customIconExists: true), .customFile("/tmp/icon.png"))
        XCTAssertEqual(chooseTileIcon(tile: tile, installedPath: "/Applications/RaceTime.app", customIconExists: false), .application("/Applications/RaceTime.app"))
        XCTAssertEqual(chooseTileIcon(tile: tile, installedPath: nil, customIconExists: false), .symbol("flag.checkered"))
    }

    func testKioskRestrictionsCoverTheDesktopLock() {
        let restrictions = Set(KioskPolicy.restrictions)
        XCTAssertTrue(restrictions.contains(.hideDock))
        XCTAssertTrue(restrictions.contains(.hideMenuBar))
        XCTAssertTrue(restrictions.contains(.disableProcessSwitching))
        XCTAssertTrue(restrictions.contains(.disableForceQuit))
        XCTAssertTrue(restrictions.contains(.disableHideApplication))
        XCTAssertTrue(restrictions.contains(.disableSessionTermination))
    }

    func testParentGesture() {
        XCTAssertTrue(ParentGesture.isParentChord(control: true, option: true, command: true, character: "p"))
        XCTAssertTrue(ParentGesture.isParentChord(control: true, option: true, command: true, character: "P"))
        XCTAssertFalse(ParentGesture.isParentChord(control: true, option: true, command: false, character: "p"))
        var history: [Date] = []
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in 0..<4 {
            XCTAssertFalse(ParentGesture.registerTap(at: start.addingTimeInterval(TimeInterval(offset)), history: &history))
        }
        XCTAssertTrue(ParentGesture.registerTap(at: start.addingTimeInterval(4), history: &history))
        XCTAssertTrue(history.isEmpty)
        var slow: [Date] = []
        XCTAssertFalse(ParentGesture.registerTap(at: start, history: &slow))
        XCTAssertFalse(ParentGesture.registerTap(at: start.addingTimeInterval(10), history: &slow))
        XCTAssertEqual(slow.count, 1)
    }

    func testLaunchAgentTemplateMatchesThePackagingFile() throws {
        let url = repoRoot().appendingPathComponent("Packaging/LaunchAgent.plist.template")
        let file = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(LaunchAgentManifest.xml(executablePath: "__EXECUTABLE_PATH__"), file)
        let escaped = LaunchAgentManifest.xml(executablePath: "/Apps/A&B.app/Contents/MacOS/KidsComputer")
        XCTAssertTrue(escaped.contains("/Apps/A&amp;B.app/Contents/MacOS/KidsComputer"))
        XCTAssertTrue(escaped.contains("<key>SuccessfulExit</key>"))
        XCTAssertTrue(escaped.contains("<false/>"))
        XCTAssertTrue(escaped.contains("<key>RunAtLoad</key>"))
    }

    func testInfoPlistIdentity() throws {
        let url = repoRoot().appendingPathComponent("Packaging/Info.plist")
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("<string>\(LauncherRelease.bundleID)</string>"))
        XCTAssertTrue(text.contains("<string>\(LauncherRelease.version)</string>"))
        XCTAssertTrue(text.contains("<string>\(LauncherRelease.executableName)</string>"))
        XCTAssertTrue(text.contains("<string>14.0</string>"))
        XCTAssertTrue(text.contains(LauncherRelease.displayName))
    }

    func testCopyDoesNotAssumeAChildsName() {
        let calendar = utcCalendar()
        let morning = iso("2026-11-02T08:30:00Z")
        XCTAssertEqual(Greeting.line(name: "", at: morning, calendar: calendar), "Good morning")
        XCTAssertEqual(Greeting.line(name: "  ", at: morning, calendar: calendar), "Good morning")
        XCTAssertEqual(Greeting.line(name: "Sam", at: morning, calendar: calendar), "Good morning, Sam")
        let afternoon = iso("2026-11-02T15:00:00Z")
        XCTAssertEqual(Greeting.line(name: "", at: afternoon, calendar: calendar), "Good afternoon")
        let evening = iso("2026-11-02T19:00:00Z")
        XCTAssertEqual(Greeting.line(name: "Sam", at: evening, calendar: calendar), "Good evening, Sam")
        let night = iso("2026-11-02T22:15:00Z")
        XCTAssertEqual(Greeting.line(name: "", at: night, calendar: calendar), "Hello")
        for value in KidCopy.fixedStrings {
            XCTAssertFalse(value.isEmpty)
        }
        XCTAssertEqual(KidCopy.comingSoon(title: "Drawing Helper"), "Drawing Helper is coming soon.")
        XCTAssertEqual(KidCopy.warning(title: "Chess", secondsRemaining: 90), "Chess has about 2 minutes left today.")
        XCTAssertEqual(KidCopy.timeUp(title: "Chess"), "Chess is all done for today. It comes back tomorrow.")
        XCTAssertEqual(DurationText.minutes(30), "Less than a minute")
        XCTAssertEqual(DurationText.minutes(60), "1 minute")
        XCTAssertEqual(DurationText.minutes(120), "2 minutes")
    }

    private func decide(
        bundleID: String?,
        path: String?,
        activation: AppActivation = .regular
    ) -> PolicyDecision.Action {
        let app = ObservedApp(
            bundleIdentifier: bundleID,
            bundlePath: path,
            executablePath: path.map { $0 + "/Contents/MacOS/App" },
            activation: activation
        )
        return AppPolicy.decide(app: app, approved: approved, enforcing: true).action
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func iso(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}
