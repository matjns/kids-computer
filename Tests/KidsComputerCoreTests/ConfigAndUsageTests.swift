import XCTest
@testable import KidsComputerCore

final class ConfigAndUsageTests: XCTestCase {
    func testStarterLineupOrderAndBundleIDs() {
        let tiles = LauncherConfig.starter.tiles
        XCTAssertEqual(tiles.map(\.id), [
            "race-time", "typing-tutor", "chess", "math-quiz", "reading", "drawing",
        ])
        XCTAssertEqual(tiles.map(\.title), [
            "Race Time", "Typing Tutor", "Chess", "Math Quiz", "Reading", "Drawing Helper",
        ])
        XCTAssertEqual(tiles.map(\.bundleIdentifier), [
            "com.racetime.fsae",
            "com.kidscomputer.typingtutor",
            "com.apple.Chess",
            "com.kidscomputer.mathquiz",
            "com.kidscomputer.reading",
            "com.kidscomputer.drawing",
        ])
        XCTAssertEqual(tiles[0].applicationPath, "/Applications/RaceTime.app")
        XCTAssertEqual(tiles[2].applicationPath, "/System/Applications/Chess.app")
        XCTAssertNil(tiles[1].applicationPath)
        XCTAssertNil(tiles[3].applicationPath)
        XCTAssertNil(tiles[4].applicationPath)
        XCTAssertNil(tiles[5].applicationPath)
        XCTAssertEqual(LauncherConfig.starter.greetingName, "")
        XCTAssertTrue(LauncherConfig.starter.kioskEnabled)
        XCTAssertEqual(LauncherRelease.bundleID, "com.kidscomputer.launcher")
        XCTAssertEqual(LauncherRelease.displayName, "Kids Computer")
        XCTAssertEqual(LauncherRelease.executableName, "KidsComputer")
        XCTAssertEqual(LauncherRelease.supportFolderName, "Kids Computer")
        XCTAssertEqual(LaunchAgentManifest.label, LauncherRelease.bundleID)
    }

    func testExampleConfigMatchesTheStarterLineup() throws {
        let url = repoRoot().appendingPathComponent("examples/tiles.json")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(LauncherConfig.self, from: data)
        XCTAssertEqual(decoded.greetingName, "")
        XCTAssertEqual(decoded.tiles.map(\.id), LauncherConfig.starter.tiles.map(\.id))
        XCTAssertEqual(decoded.tiles.map(\.bundleIdentifier), LauncherConfig.starter.tiles.map(\.bundleIdentifier))
        XCTAssertEqual(decoded.tiles.map(\.title), LauncherConfig.starter.tiles.map(\.title))
        XCTAssertNil(decoded.parentPasswordHash)
    }

    func testSparseTileJSONGetsDefaults() throws {
        let json = """
        {"tiles":[{"id":"sketch","title":"Sketch","bundleIdentifier":"com.example.sketch"}]}
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(LauncherConfig.self, from: json)
        XCTAssertEqual(config.greetingName, "")
        XCTAssertTrue(config.kioskEnabled)
        XCTAssertEqual(config.warnBeforeMinutes, 5)
        XCTAssertEqual(config.tiles[0].accent, .blue)
        XCTAssertTrue(config.tiles[0].enabled)
        XCTAssertEqual(config.tiles[0].symbolName, "sparkles")
        XCTAssertNil(config.tiles[0].dailyLimitMinutes)
    }

    func testZeroMinuteLimitMeansUnlimited() throws {
        let json = """
        {"tiles":[{"id":"chess","title":"Chess","bundleIdentifier":"com.apple.Chess","dailyLimitMinutes":0}]}
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(LauncherConfig.self, from: json)
        XCTAssertNil(config.tiles[0].dailyLimitMinutes)
    }

    func testConfigRoundTripPreservesOrder() throws {
        let store = try makeStore()
        var config = LauncherConfig.starter
        config.greetingName = "Sam"
        config.tiles[3].dailyLimitMinutes = 20
        config.parentPasswordHash = "pbkdf2-sha256$1$c2FsdA==$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa="
        try store.saveConfig(config)
        let loaded = try store.loadConfig()
        XCTAssertEqual(loaded, config)
        let text = try String(contentsOf: store.configURL, encoding: .utf8)
        XCTAssertFalse(text.contains("Sam's secret"))
        XCTAssertTrue(text.contains("pbkdf2-sha256$"))
        let race = text.range(of: "\"id\" : \"race-time\"")
        let drawing = text.range(of: "\"id\" : \"drawing\"")
        XCTAssertNotNil(race)
        XCTAssertNotNil(drawing)
        XCTAssertLessThan(race!.lowerBound, drawing!.lowerBound)
    }

    func testMissingConfigIsSeededWithoutOverwritingACorruptFile() throws {
        let store = try makeStore()
        let seeded = try store.loadConfig()
        XCTAssertEqual(seeded.tiles.map(\.id), LauncherConfig.starter.tiles.map(\.id))

        try "not json".data(using: .utf8)!.write(to: store.configURL)
        XCTAssertThrowsError(try store.loadConfig())
        let stillThere = try String(contentsOf: store.configURL, encoding: .utf8)
        XCTAssertEqual(stillThere, "not json")
    }

    func testRestoreTilesKeepsGreetingAndPassword() {
        var config = LauncherConfig.starter
        config.greetingName = "Sam"
        config.parentPasswordHash = "hash"
        config.tiles = [Tile(id: "only", title: "Only", bundleIdentifier: "com.example.only")]
        let restored = config.restoringStarterTiles()
        XCTAssertEqual(restored.greetingName, "Sam")
        XCTAssertEqual(restored.parentPasswordHash, "hash")
        XCTAssertEqual(restored.tiles.map(\.id), LauncherConfig.starter.tiles.map(\.id))
    }

    func testEditingTiles() {
        var tiles = LauncherConfig.starter.tiles
        TileList.move("chess", .up, in: &tiles)
        XCTAssertEqual(tiles.map(\.id), ["race-time", "chess", "typing-tutor", "math-quiz", "reading", "drawing"])
        TileList.move("race-time", .up, in: &tiles)
        XCTAssertEqual(tiles[0].id, "race-time")
        tiles = TileList.removing("chess", from: tiles)
        XCTAssertFalse(tiles.contains { $0.id == "chess" })
        XCTAssertEqual(TileList.uniqueID(basedOn: "Math Quiz", existing: tiles), "math-quiz-2")
        XCTAssertEqual(TileList.uniqueID(basedOn: "Science Lab", existing: tiles), "science-lab")
        XCTAssertEqual(TileList.slug("Drawing Helper"), "drawing-helper")
    }

    func testValidator() {
        var config = LauncherConfig.starter
        config.tiles.append(config.tiles[0])
        config.tiles.append(Tile(id: "blank", title: "Blank"))
        let issues = ConfigCheck.issues(in: config)
        XCTAssertTrue(issues.contains { $0.contains("race-time") })
        XCTAssertTrue(issues.contains { $0.contains("Blank") })
    }

    func testUsageCrossesMidnightAndPrunes() {
        var log = UsageLog()
        let calendar = utcCalendar()
        let start = iso("2026-11-02T23:50:00Z")
        let end = iso("2026-11-03T00:10:00Z")
        log.addInterval(tileID: "chess", from: start, to: end, calendar: calendar)
        XCTAssertEqual(log.seconds(for: "chess", on: "2026-11-02"), 600)
        XCTAssertEqual(log.seconds(for: "chess", on: "2026-11-03"), 600)
        for day in 1...40 {
            log.add(seconds: day, to: "race-time", on: String(format: "2026-01-%02d", day))
        }
        log.prune(keepingNewest: 30)
        XCTAssertEqual(log.days.count, 30)
        XCTAssertNil(log.days.first { $0.day == "2026-01-01" })
        XCTAssertNotNil(log.days.first { $0.day == "2026-01-40" })
    }

    func testCorruptUsageIsRenamedAndReplacedWithEmpty() throws {
        let store = try makeStore()
        try store.prepare()
        try Data("[]".utf8).write(to: store.usageURL)
        let loaded = store.loadUsage()
        XCTAssertEqual(loaded, UsageLog())
        XCTAssertTrue(store.fileManager.fileExists(atPath: store.directory.appendingPathComponent("usage.json.bak").path))
    }

    func testUsageMonitorWarnsOnceThenLocks() {
        var monitor = UsageMonitor()
        let calendar = utcCalendar()
        let start = iso("2026-11-02T15:00:00Z")
        let limits = ["chess": Optional(10)]
        let opened = monitor.setFrontmost("chess", at: start, limits: limits, warnBeforeMinutes: 1, calendar: calendar)
        XCTAssertEqual(opened, [])
        monitor.log.add(seconds: 540, to: "chess", on: "2026-11-02")
        let warned = monitor.sample(at: start.addingTimeInterval(20), limits: limits, warnBeforeMinutes: 1, calendar: calendar)
        XCTAssertEqual(warned, [.warn(tileID: "chess", secondsRemaining: 40)])
        let again = monitor.sample(at: start.addingTimeInterval(40), limits: limits, warnBeforeMinutes: 1, calendar: calendar)
        XCTAssertEqual(again, [])
        XCTAssertEqual(monitor.log.seconds(for: "chess", on: "2026-11-02"), 580)
        let done = monitor.sample(at: start.addingTimeInterval(60), limits: limits, warnBeforeMinutes: 1, calendar: calendar)
        XCTAssertEqual(done, [.exhausted(tileID: "chess")])
        XCTAssertNil(monitor.frontTileID)
        let after = monitor.sample(at: start.addingTimeInterval(80), limits: limits, warnBeforeMinutes: 1, calendar: calendar)
        XCTAssertEqual(after, [])
        XCTAssertEqual(monitor.log.seconds(for: "chess", on: "2026-11-02"), 600)
    }

    func testSleepGapIsNotCountedAsPlayTime() {
        var monitor = UsageMonitor()
        let calendar = utcCalendar()
        let start = iso("2026-11-02T15:00:00Z")
        let limits: [String: Int?] = ["chess": 30]
        _ = monitor.setFrontmost("chess", at: start, limits: limits, warnBeforeMinutes: 5, calendar: calendar)
        let capped = monitor.sample(at: start.addingTimeInterval(2 * 60 * 60), limits: limits, warnBeforeMinutes: 5, calendar: calendar)
        XCTAssertEqual(capped, [])
        XCTAssertEqual(monitor.log.seconds(for: "chess", on: "2026-11-02"), UsageMonitor.maxCountedGapSeconds)
        let next = monitor.sample(at: start.addingTimeInterval(2 * 60 * 60 + 2), limits: limits, warnBeforeMinutes: 5, calendar: calendar)
        XCTAssertEqual(next, [])
        XCTAssertEqual(monitor.log.seconds(for: "chess", on: "2026-11-02"), UsageMonitor.maxCountedGapSeconds + 2)

        var woke = UsageMonitor()
        _ = woke.setFrontmost("chess", at: start, limits: limits, warnBeforeMinutes: 5, calendar: calendar)
        woke.noteClockGap()
        _ = woke.sample(at: start.addingTimeInterval(2 * 60 * 60), limits: limits, warnBeforeMinutes: 5, calendar: calendar)
        XCTAssertEqual(woke.log.seconds(for: "chess", on: "2026-11-02"), 0)
    }

    func testAlreadyExhaustedAppDoesNotStayInFront() {
        var monitor = UsageMonitor()
        let calendar = utcCalendar()
        let start = iso("2026-11-02T15:00:00Z")
        monitor.log.add(seconds: 600, to: "reading", on: "2026-11-02")
        let events = monitor.setFrontmost("reading", at: start, limits: ["reading": 10], warnBeforeMinutes: 5, calendar: calendar)
        XCTAssertEqual(events, [.exhausted(tileID: "reading")])
        XCTAssertNil(monitor.frontTileID)
    }

    func testTileFaces() {
        let drawing = LauncherConfig.starter.tiles.first { $0.id == "drawing" }!
        XCTAssertEqual(
            makeTileFace(tile: drawing, isInstalled: false, usedSeconds: 0, warnBeforeMinutes: 5),
            .comingSoon
        )
        var chess = LauncherConfig.starter.tiles.first { $0.id == "chess" }!
        XCTAssertEqual(
            makeTileFace(tile: chess, isInstalled: true, usedSeconds: 0, warnBeforeMinutes: 5),
            .ready(minutesRemaining: nil)
        )
        chess.dailyLimitMinutes = 15
        XCTAssertEqual(
            makeTileFace(tile: chess, isInstalled: true, usedSeconds: 60, warnBeforeMinutes: 5),
            .ready(minutesRemaining: 14)
        )
        XCTAssertEqual(
            makeTileFace(tile: chess, isInstalled: true, usedSeconds: 15 * 60, warnBeforeMinutes: 5),
            .doneForToday
        )
        XCTAssertEqual(
            makeTileFace(tile: chess, isInstalled: false, usedSeconds: 15 * 60, warnBeforeMinutes: 5),
            .comingSoon
        )
        chess.enabled = false
        XCTAssertEqual(
            makeTileFace(tile: chess, isInstalled: true, usedSeconds: 0, warnBeforeMinutes: 5),
            .turnedOff
        )
    }

    func testPhases() {
        XCTAssertEqual(UsagePhase.make(limitMinutes: nil, usedSeconds: 100, warnBeforeMinutes: 5), .unlimited)
        XCTAssertEqual(UsagePhase.make(limitMinutes: 0, usedSeconds: 100, warnBeforeMinutes: 5), .unlimited)
        XCTAssertEqual(UsagePhase.make(limitMinutes: 10, usedSeconds: 60, warnBeforeMinutes: 5), .ok)
        XCTAssertEqual(UsagePhase.make(limitMinutes: 10, usedSeconds: 8 * 60, warnBeforeMinutes: 5), .warning(secondsRemaining: 120))
        XCTAssertEqual(UsagePhase.make(limitMinutes: 10, usedSeconds: 600, warnBeforeMinutes: 5), .exhausted)
    }

    private func makeStore() throws -> ConfigStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return ConfigStore(directory: directory)
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

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
