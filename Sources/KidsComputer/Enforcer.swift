#if os(macOS)
import AppKit
import Darwin
import KidsComputerCore

final class AppEnforcer: NSObject {
    private unowned let model: LauncherModel
    var onNeedsFront: () -> Void = {}
    var onNeedsBack: () -> Void = {}
    private var attempts: [pid_t: Int] = [:]
    private var placedBehind = false

    init(model: LauncherModel) {
        self.model = model
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(launched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(terminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(woke(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func scan() {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for app in NSWorkspace.shared.runningApplications {
            consider(app, frontmost: front, fromScan: true)
        }
        syncFront(front)
        let living = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        attempts = attempts.filter { living.contains($0.key) }
    }

    func launch(_ tile: Tile) {
        guard let path = model.installedPaths[tile.id] else {
            model.showBanner(KidCopy.comingSoon(title: tile.title))
            return
        }
        closeOtherActivities(except: tile)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: configuration) { [weak self] opened, error in
            let pid = opened?.processIdentifier
            DispatchQueue.main.async {
                if let pid, self?.model.isEnforcing == true {
                    WindowFiller.fillSoon(pid: pid)
                }
                if let error {
                    self?.model.showBanner(KidCopy.failedToOpen(title: tile.title))
                    FileLog.append("Open failed for \(tile.title): \(error.localizedDescription)")
                } else {
                    FileLog.append("Opened \(tile.title)")
                }
            }
        }
    }

    func terminate(tileID: String) {
        guard let tile = model.config.tiles.first(where: { $0.id == tileID }) else { return }
        for app in NSWorkspace.shared.runningApplications where isMainApp(app, tile: tile) {
            app.hide()
            app.terminate()
            FileLog.append("Time is up. Asked \(tile.title) to quit.")
        }
        placedBehind = false
        onNeedsFront()
    }

    @objc private func launched(_ notification: Notification) {
        guard let app = notification.runningApplication else { return }
        consider(app, frontmost: app.processIdentifier, fromScan: false)
        syncFront(NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    @objc private func activated(_ notification: Notification) {
        guard let app = notification.runningApplication else { return }
        consider(app, frontmost: app.processIdentifier, fromScan: false)
        syncFront(app.processIdentifier)
    }

    @objc private func terminated(_ notification: Notification) {
        syncFront(NSWorkspace.shared.frontmostApplication?.processIdentifier)
    }

    @objc private func woke(_ notification: Notification) {
        model.noteClockGap()
    }

    private func consider(_ app: NSRunningApplication, frontmost: pid_t?, fromScan: Bool) {
        let decision = AppPolicy.decide(
            app: observed(app),
            approved: model.config.approvedTargets(resolvedPaths: model.installedPaths),
            extraProtected: model.config.extraProtectedBundleIDs,
            enforcing: model.isEnforcing
        )
        switch decision.action {
        case .allow:
            return
        case .hide:
            let cameForward = !fromScan || app.processIdentifier == frontmost
            guard cameForward else { return }
            app.hide()
            FileLog.append("Hid \(label(app)) (\(decision.reason))")
            placedBehind = false
            onNeedsFront()
        case .terminate:
            suppress(app, reason: decision.reason)
            placedBehind = false
            onNeedsFront()
        }
    }

    private func suppress(_ app: NSRunningApplication, reason: String) {
        let pid = app.processIdentifier
        let count = attempts[pid, default: 0] + 1
        attempts[pid] = count
        app.hide()
        if count == 1 {
            app.terminate()
            FileLog.append("Closing \(label(app)) (\(reason))")
        } else if count >= 3 {
            app.forceTerminate()
            FileLog.append("Force-quit \(label(app)) (\(reason))")
        }
    }

    private func syncFront(_ frontPID: pid_t?) {
        let frontApp = runningApplication(pid: frontPID)
        let matchedTileID: String?
        if let frontApp {
            matchedTileID = approvedTileID(for: frontApp)
        } else {
            matchedTileID = nil
        }
        model.noteFront(matchedTileID)
        if matchedTileID == nil {
            if placedBehind {
                placedBehind = false
                onNeedsFront()
            }
        } else if !placedBehind {
            placedBehind = true
            onNeedsBack()
        }
    }

    private func runningApplication(pid: pid_t?) -> NSRunningApplication? {
        guard let pid else { return nil }
        return NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
    }

    private func approvedTileID(for application: NSRunningApplication) -> String? {
        model.config.tiles.first { $0.enabled && isMainApp(application, tile: $0) }?.id
    }

    private func isMainApp(_ app: NSRunningApplication, tile: Tile) -> Bool {
        if let id = app.bundleIdentifier, let expected = tile.bundleIdentifier,
           id.caseInsensitiveCompare(expected) == .orderedSame {
            return true
        }
        guard let expected = model.installedPaths[tile.id] ?? tile.applicationPath,
              let bundlePath = app.bundleURL?.path else {
            return false
        }
        return normalize(bundlePath) == normalize(expected)
    }

    private func closeOtherActivities(except tile: Tile) {
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular else { continue }
            guard let other = approvedTileID(for: app), other != tile.id else { continue }
            app.terminate()
        }
    }

    private func observed(_ app: NSRunningApplication) -> ObservedApp {
        ObservedApp(
            bundleIdentifier: app.bundleIdentifier,
            bundlePath: app.bundleURL?.path,
            executablePath: app.executableURL?.path,
            activation: activation(of: app.activationPolicy),
            isLauncher: app.processIdentifier == ProcessInfo.processInfo.processIdentifier
        )
    }

    private func activation(of policy: NSApplication.ActivationPolicy) -> AppActivation {
        switch policy {
        case .regular: return .regular
        case .accessory: return .accessory
        case .prohibited: return .prohibited
        @unknown default: return .unknown
        }
    }

    private func label(_ app: NSRunningApplication) -> String {
        "\(app.localizedName ?? "an app") [\(app.bundleIdentifier ?? "no bundle id")]"
    }

    private func normalize(_ path: String) -> String {
        var value = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.count > 1 && value.hasSuffix("/") {
            value.removeLast()
        }
        return value.lowercased()
    }
}

private extension Notification {
    var runningApplication: NSRunningApplication? {
        userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }
}
#endif
