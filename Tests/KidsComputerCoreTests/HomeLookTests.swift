import XCTest
@testable import KidsComputerCore

final class HomeLookTests: XCTestCase {
    func testThereAreEnoughBrightChoices() {
        XCTAssertGreaterThanOrEqual(LookBackground.solids.count, 8)
        XCTAssertLessThanOrEqual(LookBackground.solids.count, 12)
        XCTAssertGreaterThanOrEqual(LookBackground.gradients.count, 3)
        XCTAssertEqual(LookPattern.allCases, [.plain, .stars, .dots, .waves])
        XCTAssertEqual(LookTileColors.choices.count, TileAccent.allCases.count + 1)
        XCTAssertEqual(LookTileColors.choices.first, .activityColors)
    }

    func testEveryBackgroundKeepsHomeTextReadable() {
        for background in LookBackground.allCases {
            let ratio = Contrast.bestContrast(on: background.colors)
            XCTAssertGreaterThanOrEqual(ratio, Contrast.homeTextTarget, "\(background) text contrast is \(ratio)")
        }
    }

    func testToneFollowsTheBackground() {
        XCTAssertEqual(LookBackground.playroom.textTone, .dark)
        XCTAssertEqual(LookBackground.sunshine.textTone, .dark)
        XCTAssertEqual(LookBackground.midnight.textTone, .light)
        XCTAssertEqual(LookBackground.ocean.textTone, .light)
        XCTAssertEqual(LookBackground.space.textTone, .light)
        XCTAssertEqual(Contrast.tone(on: [.white]), .dark)
        XCTAssertEqual(Contrast.tone(on: [RGB(0, 0, 0)]), .light)
        XCTAssertEqual(Contrast.tone(on: []), .dark)
    }

    func testGradientToneChecksEveryStop() {
        // Pale yellow to near-black: whichever tone wins, it is judged by its worst stop.
        let colors = [RGB(1, 1, 0.8), RGB(0.05, 0.05, 0.05)]
        let tone = Contrast.tone(on: colors)
        let chosen = Contrast.worst(tone.rgb, on: colors)
        let other = Contrast.worst(tone == .dark ? .white : .ink, on: colors)
        XCTAssertGreaterThanOrEqual(chosen, other)
    }

    func testContrastMath() {
        XCTAssertEqual(RGB(0, 0, 0).contrast(with: .white), 21, accuracy: 0.01)
        XCTAssertEqual(RGB.white.contrast(with: .white), 1, accuracy: 0.0001)
        XCTAssertEqual(RGB(2, -1, 0.5), RGB(1, 0, 0.5))
    }

    func testEveryTileColorKeepsItsTitleReadable() {
        for accent in TileAccent.allCases {
            let ratio = accent.textTone.rgb.contrast(with: accent.rgb)
            XCTAssertGreaterThanOrEqual(ratio, Contrast.tileTextTarget, "\(accent) tile text contrast is \(ratio)")
        }
        XCTAssertTrue(TileAccent.yellow.usesDarkText)
        XCTAssertFalse(TileAccent.blue.usesDarkText)
    }

    func testTileColorChoice() {
        let tile = Tile(id: "chess", title: "Chess", bundleIdentifier: "com.apple.Chess", accent: .teal)
        XCTAssertEqual(LookTileColors.activityColors.accent(for: tile), .teal)
        XCTAssertEqual(LookTileColors.all(.pink).accent(for: tile), .pink)
        XCTAssertEqual(LookTileColors(rawValue: "pink"), .all(.pink))
        XCTAssertEqual(LookTileColors(rawValue: "activity"), .activityColors)
        XCTAssertEqual(LookTileColors(rawValue: "glitter"), .activityColors)
    }

    func testOldConfigWithoutALookGetsTheStandardLook() throws {
        let json = """
        {"tiles":[{"id":"sketch","title":"Sketch","bundleIdentifier":"com.example.sketch"}]}
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(LauncherConfig.self, from: json)
        XCTAssertEqual(config.look, .standard)
        XCTAssertTrue(config.look.isStandard)
        XCTAssertTrue(config.childCanCustomizeLook)
        XCTAssertTrue(LauncherConfig.starter.childCanCustomizeLook)
        XCTAssertEqual(LauncherConfig.starter.look, .standard)
    }

    func testUnknownLookValuesFallBackWithoutBreakingTheFile() throws {
        let json = """
        {"childCanCustomizeLook":"yes","look":{"background":"glitter","pattern":"zigzag","tileColors":7},
         "tiles":[{"id":"sketch","title":"Sketch","bundleIdentifier":"com.example.sketch"}]}
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(LauncherConfig.self, from: json)
        XCTAssertEqual(config.look, .standard)
        XCTAssertTrue(config.childCanCustomizeLook)
        XCTAssertEqual(config.tiles.count, 1)

        let partial = """
        {"look":{"background":"space"},"tiles":[]}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(LauncherConfig.self, from: partial)
        XCTAssertEqual(decoded.look, HomeLook(background: .space))
    }

    func testLookPersistsAcrossRelaunch() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("kc-look-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ConfigStore(directory: folder)
        var config = try store.loadConfig()
        config.parentPasswordHash = "pbkdf2-sha256$2$aa$bb"
        config.warnBeforeMinutes = 7
        try store.saveConfig(config)

        let look = HomeLook(background: .rainbow, pattern: .stars, tileColors: .all(.purple))
        let next = try XCTUnwrap(LookPermission.applyingChildLook(look, to: config))
        try store.saveConfig(next)

        let reopened = ConfigStore(directory: folder)
        let loaded = try reopened.loadConfig()
        XCTAssertEqual(loaded.look, look)
        XCTAssertEqual(loaded.parentPasswordHash, "pbkdf2-sha256$2$aa$bb")
        XCTAssertEqual(loaded.warnBeforeMinutes, 7)
        XCTAssertEqual(loaded.tiles, config.tiles)

        let text = try String(contentsOf: reopened.configURL, encoding: .utf8)
        XCTAssertTrue(text.contains("\"look\""))
        XCTAssertTrue(text.contains("\"rainbow\""))
        XCTAssertTrue(text.contains("\"purple\""))
    }

    func testChildLookChangesOnlyTheLook() throws {
        var config = LauncherConfig.starter
        config.greetingName = "Pilot"
        config.kioskEnabled = true
        config.extraProtectedBundleIDs = ["com.example.helper"]
        let look = HomeLook(background: .midnight, pattern: .waves, tileColors: .all(.green))
        let next = try XCTUnwrap(LookPermission.applyingChildLook(look, to: config))
        var expected = config
        expected.look = look
        XCTAssertEqual(next, expected)
    }

    func testParentCanTurnOffAndReset() {
        var config = LauncherConfig.starter
        config.look = HomeLook(background: .cherry, pattern: .dots, tileColors: .all(.red))
        XCTAssertTrue(LookPermission.childCanCustomize(config: config, configHasError: false))
        XCTAssertFalse(LookPermission.childCanCustomize(config: config, configHasError: true))

        config.childCanCustomizeLook = false
        XCTAssertFalse(LookPermission.childCanCustomize(config: config, configHasError: false))
        XCTAssertNil(LookPermission.applyingChildLook(.standard, to: config))

        let reset = LookPermission.resettingLook(config)
        XCTAssertEqual(reset.look, .standard)
        XCTAssertFalse(reset.childCanCustomizeLook)
        XCTAssertEqual(reset.tiles, config.tiles)
    }

    func testToggleRoundTrips() throws {
        var config = LauncherConfig.starter
        config.childCanCustomizeLook = false
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(LauncherConfig.self, from: data)
        XCTAssertFalse(decoded.childCanCustomizeLook)
        XCTAssertEqual(decoded, config)
    }

    func testKidCopyIsShortAndNameless() {
        for text in LookCopy.fixedStrings {
            XCTAssertFalse(text.isEmpty)
            XCTAssertLessThanOrEqual(text.count, 24)
        }
        for background in LookBackground.allCases {
            XCTAssertFalse(background.kidName.isEmpty)
        }
    }
}
