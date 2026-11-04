import XCTest
@testable import KidsComputerCore

final class DockSetupTests: XCTestCase {
    func testMissingSettingMeansDockAlwaysShows() {
        XCTAssertTrue(DockSetup.needsAutohide(currentValue: nil))
    }

    func testAutohideAlreadyOnIsLeftAlone() {
        XCTAssertFalse(DockSetup.needsAutohide(currentValue: true))
        XCTAssertFalse(DockSetup.needsAutohide(currentValue: NSNumber(value: 1)))
        XCTAssertFalse(DockSetup.needsAutohide(currentValue: "YES"))
    }

    func testAutohideOffIsChanged() {
        XCTAssertTrue(DockSetup.needsAutohide(currentValue: false))
        XCTAssertTrue(DockSetup.needsAutohide(currentValue: NSNumber(value: 0)))
        XCTAssertTrue(DockSetup.needsAutohide(currentValue: "no"))
    }

    func testUndoCommandTurnsAutohideOff() {
        XCTAssertTrue(DockSetup.undoCommand.contains("autohide -bool false"))
        XCTAssertTrue(DockSetup.undoCommand.contains("killall Dock"))
    }

    func testFillRectFlipsToTopLeftOrigin() {
        // A 1440x900 main display with a 25 point menu bar and a hidden Dock.
        let visible = WindowRect(x: 0, y: 0, width: 1440, height: 875)
        let rect = WindowFill.accessibilityRect(visible: visible, primaryScreenHeight: 900)
        XCTAssertEqual(rect, WindowRect(x: 0, y: 25, width: 1440, height: 875))
    }

    func testFillRectLeavesRoomForAVisibleDock() {
        // Dock showing at the bottom takes 70 points.
        let visible = WindowRect(x: 0, y: 70, width: 1440, height: 805)
        let rect = WindowFill.accessibilityRect(visible: visible, primaryScreenHeight: 900)
        XCTAssertEqual(rect.y, 25)
        XCTAssertEqual(rect.height, 805)
    }

    func testRetriesAreShortAndOrdered() {
        XCTAssertFalse(WindowFill.retryDelays.isEmpty)
        XCTAssertEqual(WindowFill.retryDelays, WindowFill.retryDelays.sorted())
        XCTAssertLessThanOrEqual(WindowFill.retryDelays.last ?? 0, 5)
    }
}
