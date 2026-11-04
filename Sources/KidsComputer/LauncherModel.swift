#if os(macOS)
import AppKit
import Foundation
import Observation
import ServiceManagement
import KidsComputerCore

enum ParentGate: Equatable {
    case hidden
    case createPassword
    case enterPassword
    case settings
    case editing(Tile, isNew: Bool)
    case confirmQuit
    case confirmRestore
    case confirmDelete(Tile)
}

@Observable
final class LauncherModel {
    var config: LauncherConfig
    var monitor: UsageMonitor
    var installedPaths: [String: String]
    var gate: ParentGate
    var loadError: String?
    var parentError: String?
    var passwordStoreNote: String?
    var banner: String?
    var passwordBusy: Bool
    var panelsOpen: Int
    var settingsGraceUntil: Date?
    var allowQuit: Bool
    var revision: Int
    /// The child's "Make it mine" sheet. It only edits `lookDraft`.
    var lookPickerOpen: Bool
    var lookDraft: HomeLook?

    @ObservationIgnored var store: ConfigStore
    @ObservationIgnored var onLaunch: (Tile) -> Void = { _ in }
    @ObservationIgnored var onNotice: (String, String, Bool) -> Void = { _, _, _ in }
    @ObservationIgnored var onEnforcementChanged: () -> Void = {}
    @ObservationIgnored private var cornerTaps: [Date] = []
    @ObservationIgnored private var bannerToken = 0
    @ObservationIgnored private var lastUsageSave = Date.distantPast

    init(store: ConfigStore) {
        self.store = store
        config = .starter
        monitor = UsageMonitor()
        installedPaths = [:]
        gate = .hidden
        loadError = nil
        parentError = nil
        passwordStoreNote = nil
        banner = nil
        passwordBusy = false
        panelsOpen = 0
        settingsGraceUntil = nil
        allowQuit = false
        revision = 0
        lookPickerOpen = false
        lookDraft = nil
    }

    var isEnforcing: Bool {
        if panelsOpen > 0 { return false }
        if let until = settingsGraceUntil, until > Date() { return false }
        return config.kioskEnabled
    }

    var showsLockPause: Bool {
        !config.kioskEnabled || panelsOpen > 0 || (settingsGraceUntil ?? .distantPast) > Date()
    }

    var lockPauseMessage: String {
        if !config.kioskEnabled { return KidCopy.lockPaused }
        return KidCopy.settingsGrace
    }

    func load() {
        do {
            config = try store.loadConfig()
            loadError = nil
        } catch {
            config = .starter
            loadError = error.localizedDescription
            FileLog.append("Couldn't read tiles.json: \(error.localizedDescription)")
        }
        monitor = UsageMonitor(log: store.loadUsage())
        refreshInstallation()
        revision += 1
    }

    func refreshInstallation() {
        var paths: [String: String] = [:]
        for tile in config.tiles {
            if let path = AppLocation.resolve(
                bundleIdentifier: tile.bundleIdentifier,
                applicationPath: tile.applicationPath,
                lookupBundlePath: { NSWorkspace.shared.urlsForApplications(withBundleIdentifier: $0).first?.path },
                fileExists: { FileManager.default.fileExists(atPath: $0) }
            ) {
                paths[tile.id] = path
            }
        }
        if paths != installedPaths {
            installedPaths = paths
            revision += 1
        }
    }

    func face(for tile: Tile) -> TileFace {
        _ = revision
        return makeTileFace(
            tile: tile,
            isInstalled: installedPaths[tile.id] != nil,
            usedSeconds: usedSeconds(for: tile.id),
            warnBeforeMinutes: config.warnBeforeMinutes
        )
    }

    func visibleTiles() -> [Tile] {
        config.tiles.filter { face(for: $0) != .turnedOff }
    }

    func usedSeconds(for tileID: String) -> Int {
        monitor.log.seconds(for: tileID, on: DayKey.make(Date(), calendar: .current))
    }

    func title(for tileID: String) -> String {
        config.tiles.first { $0.id == tileID }?.title ?? "This activity"
    }

    func open(_ tile: Tile) {
        switch face(for: tile) {
        case .ready:
            onLaunch(tile)
        case .comingSoon:
            showBanner(KidCopy.comingSoon(title: tile.title))
        case .doneForToday:
            showBanner(KidCopy.doneForToday(title: tile.title))
        case .turnedOff:
            break
        }
    }

    func registerCornerTap() {
        if ParentGesture.registerTap(at: Date(), history: &cornerTaps) {
            presentParentGate()
        }
    }

    func presentParentGate() {
        guard gate == .hidden else { return }
        if lookPickerOpen {
            closeLookPicker(save: false)
        }
        parentError = nil
        gate = hasParentPassword ? .enterPassword : .createPassword
        revision += 1
    }

    func cancelParentGate() {
        guard gate != .hidden else { return }
        gate = .hidden
        parentError = nil
        passwordBusy = false
        revision += 1
    }

    var hasParentPassword: Bool {
        if let hash = config.parentPasswordHash, !hash.isEmpty { return true }
        if let keychain = KeychainPasswordStore.read(), !keychain.isEmpty { return true }
        return false
    }

    func submitNewPassword(_ password: String, confirmation: String) {
        guard password == confirmation else {
            parentError = "Those passwords didn't match."
            return
        }
        guard PasswordHasher.validateLength(password) else {
            parentError = "Use at least \(PasswordHasher.minimumLength) characters."
            return
        }
        passwordBusy = true
        parentError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let record = try PasswordHasher.makeRecord(password: password)
                DispatchQueue.main.async {
                    self?.commitPassword(record)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.passwordBusy = false
                    self?.parentError = "Couldn't save that password."
                }
            }
        }
    }

    func submitLogin(_ password: String) {
        passwordBusy = true
        parentError = nil
        let keychainRecord = KeychainPasswordStore.read()
        let fileRecord = config.parentPasswordHash
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let keychainOK = keychainRecord.map { PasswordHasher.verify(password: password, record: $0) } ?? false
            let fileOK = fileRecord.map { PasswordHasher.verify(password: password, record: $0) } ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                self.passwordBusy = false
                if keychainOK || fileOK {
                    self.parentError = nil
                    self.gate = .settings
                    self.revision += 1
                } else {
                    self.parentError = "That password didn't match."
                }
            }
        }
    }

    func commitPassword(_ record: String) {
        var keychainOK = true
        do {
            try KeychainPasswordStore.write(record)
        } catch {
            keychainOK = false
            try? KeychainPasswordStore.delete()
            FileLog.append("Keychain save failed: \(error)")
        }
        config.parentPasswordHash = record
        persistConfig(config)
        passwordBusy = false
        passwordStoreNote = keychainOK
            ? "Saved in the Keychain and in tiles.json as a salted hash."
            : "Keychain wasn't available. Saved a salted hash in tiles.json."
        parentError = nil
        gate = .settings
        revision += 1
    }

    func setGreeting(_ name: String) {
        var next = config
        next.greetingName = name.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard next.greetingName != config.greetingName else { return }
        persistConfig(next)
    }

    func setKioskEnabled(_ enabled: Bool) {
        var next = config
        next.kioskEnabled = enabled
        persistConfig(next)
        onEnforcementChanged()
    }

    func setWarnBeforeMinutes(_ minutes: Int) {
        var next = config
        next.warnBeforeMinutes = max(0, minutes)
        persistConfig(next)
    }

    func setExtraProtected(_ lines: [String]) {
        var next = config
        next.extraProtectedBundleIDs = lines
        persistConfig(next)
    }

    func moveTile(_ id: String, direction: TileList.Direction) {
        var next = config
        TileList.move(id, direction, in: &next.tiles)
        persistConfig(next)
    }

    func deleteTile(_ id: String) {
        var next = config
        next.tiles = TileList.removing(id, from: next.tiles)
        persistConfig(next)
        gate = .settings
    }

    func saveTile(_ tile: Tile, isNew: Bool) {
        let normalized = tile.normalized()
        var next = config
        if isNew {
            next.tiles.append(normalized)
        } else if let index = next.tiles.firstIndex(where: { $0.id == normalized.id }) {
            next.tiles[index] = normalized
        } else {
            next.tiles.append(normalized)
        }
        let issues = ConfigCheck.issues(in: next)
        if !issues.isEmpty {
            parentError = issues.joined(separator: " ")
            return
        }
        persistConfig(next)
        refreshInstallation()
        gate = .settings
    }

    func restoreStarterTiles() {
        try? store.backupConfig()
        var next = config
        next.tiles = LauncherConfig.starter.tiles
        persistConfig(next)
        refreshInstallation()
        gate = .settings
    }

    // MARK: - Home screen look

    /// What the home screen shows right now: the live preview while the
    /// child is picking, otherwise the saved look.
    var displayedLook: HomeLook {
        lookDraft ?? config.look
    }

    var childCanCustomizeLook: Bool {
        LookPermission.childCanCustomize(config: config, configHasError: loadError != nil)
    }

    func openLookPicker() {
        guard gate == .hidden, childCanCustomizeLook, !lookPickerOpen else { return }
        lookDraft = config.look
        lookPickerOpen = true
        revision += 1
    }

    func previewLook(_ look: HomeLook) {
        guard lookPickerOpen else { return }
        lookDraft = look
        revision += 1
    }

    func closeLookPicker(save: Bool) {
        guard lookPickerOpen else { return }
        let draft = lookDraft
        lookDraft = nil
        lookPickerOpen = false
        revision += 1
        guard save, let draft, childCanCustomizeLook,
              let next = LookPermission.applyingChildLook(draft, to: config),
              next != config else { return }
        persistConfig(next)
        if parentError != nil {
            parentError = nil
            showBanner(KidCopy.lookNotSaved)
        }
    }

    func setChildCanCustomizeLook(_ allowed: Bool) {
        var next = config
        next.childCanCustomizeLook = allowed
        persistConfig(next)
    }

    func resetLook() {
        persistConfig(LookPermission.resettingLook(config))
    }

    func beginPanel() {
        panelsOpen += 1
        revision += 1
        onEnforcementChanged()
    }

    func endPanel() {
        panelsOpen = max(0, panelsOpen - 1)
        revision += 1
        onEnforcementChanged()
    }

    func pauseForSystemSettings() {
        settingsGraceUntil = Date().addingTimeInterval(5 * 60)
        revision += 1
        onEnforcementChanged()
        SMAppService.openSystemSettingsLoginItems()
    }

    func importIcon(from source: URL, tileID: String) throws -> String {
        try store.prepare()
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        let destination = store.iconsDirectory.appendingPathComponent("\(tileID).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination.path
    }

    func showBanner(_ text: String) {
        bannerToken += 1
        banner = text
        revision += 1
        let token = bannerToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.bannerToken == token else { return }
            self.banner = nil
            self.revision += 1
        }
    }

    func noteFront(_ tileID: String?) {
        if tileID == monitor.frontTileID, monitor.lastSample != nil {
            return
        }
        let events = monitor.setFrontmost(
            tileID,
            at: Date(),
            limits: config.limitMinutesByTile(),
            warnBeforeMinutes: config.warnBeforeMinutes,
            calendar: .current
        )
        if monitor.log.days.isEmpty == false {
            revision += 1
        }
        apply(events)
    }

    func sampleUsage() {
        let before = monitor.log
        let events = monitor.sample(
            at: Date(),
            limits: config.limitMinutesByTile(),
            warnBeforeMinutes: config.warnBeforeMinutes,
            calendar: .current
        )
        if monitor.log != before {
            revision += 1
            saveUsageIfNeeded(force: false)
        }
        apply(events)
    }

    func noteClockGap() {
        monitor.noteClockGap()
        FileLog.append("Woke from sleep. The gap was not counted as play time.")
    }

    func saveUsageNow() {
        saveUsageIfNeeded(force: true)
    }

    private func apply(_ events: [UsageEvent]) {
        guard !events.isEmpty else { return }
        for event in events {
            switch event {
            case .warn(let id, let seconds):
                onNotice(KidCopy.warning(title: title(for: id), secondsRemaining: seconds), id, false)
            case .exhausted(let id):
                let text = KidCopy.timeUp(title: title(for: id))
                onNotice(text, id, true)
                showBanner(text)
            }
        }
        saveUsageIfNeeded(force: true)
        revision += 1
    }

    private func persistConfig(_ next: LauncherConfig) {
        if loadError != nil {
            try? store.backupConfig()
        }
        do {
            try store.saveConfig(next)
            config = next
            loadError = nil
            parentError = nil
            revision += 1
        } catch {
            parentError = "Couldn't save the activity list."
            FileLog.append("Save failed: \(error)")
        }
    }

    private func saveUsageIfNeeded(force: Bool) {
        if !force && Date().timeIntervalSince(lastUsageSave) < 15 { return }
        do {
            try store.saveUsage(monitor.log)
            lastUsageSave = Date()
        } catch {
            FileLog.append("Couldn't save usage: \(error)")
        }
    }
}
#endif
