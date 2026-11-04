#if os(macOS)
import AppKit
import Darwin
import SwiftUI
import KidsComputerCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model: LauncherModel
    let kiosk = KioskController()
    let enforcer: AppEnforcer
    var windows: [NSWindow] = []
    var notice: NoticePanel?
    var timer: Timer?
    var monitors: [Any] = []
    var instanceLockFD: Int32 = -1

    override init() {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let store = ConfigStore(directory: SupportLayout.directory(home: home))
        model = LauncherModel(store: store)
        enforcer = AppEnforcer(model: model)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard acquireInstanceLock() else {
            FileLog.append("Another launcher is already running. This copy will exit.")
            exit(0)
        }
        model.load()
        model.onLaunch = { [weak self] tile in
            self?.enforcer.launch(tile)
        }
        model.onNotice = { [weak self] text, tileID, timeUp in
            NSSound.beep()
            self?.showNotice(text)
            if timeUp {
                self?.enforcer.terminate(tileID: tileID)
            }
        }
        model.onEnforcementChanged = { [weak self] in
            self?.applyKiosk()
        }
        enforcer.onNeedsFront = { [weak self] in
            self?.bringToFront()
        }
        enforcer.onNeedsBack = { [weak self] in
            self?.sendBehind()
        }
        enforcer.start()
        rebuildWindows()
        applyKiosk()
        installKeyMonitors()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        enforcer.scan()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        bringToFront()
        FileLog.append("Launcher started. Kiosk \(model.isEnforcing ? "on" : "off").")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        applyKiosk()
    }

    func applicationDidHide(_ notification: Notification) {
        if model.isEnforcing {
            NSApplication.shared.unhide(nil)
            bringToFront()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.allowQuit ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.saveUsageNow()
        if instanceLockFD >= 0 {
            close(instanceLockFD)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { false }

    @objc private func screensChanged() {
        rebuildWindows()
    }

    private func tick() {
        if let until = model.settingsGraceUntil, until <= Date() {
            model.settingsGraceUntil = nil
            model.revision += 1
        }
        model.refreshInstallation()
        enforcer.scan()
        model.sampleUsage()
        applyKiosk()
    }

    private func applyKiosk() {
        kiosk.apply(enforcing: model.isEnforcing)
    }

    private func rebuildWindows() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        while windows.count < screens.count {
            windows.append(makeWindow())
        }
        while windows.count > screens.count {
            windows.popLast()?.orderOut(nil)
        }
        for (screen, window) in zip(screens, windows) {
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
        }
    }

    private func makeWindow() -> NSWindow {
        let window = KioskWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.isMovable = false
        window.canHide = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.title = LauncherRelease.displayName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = true
        window.backgroundColor = NSColor(srgbRed: 1, green: 0.95, blue: 0.86, alpha: 1)
        window.hasShadow = false
        window.tabbingMode = .disallowed
        window.delegate = self
        let hosting = NSHostingView(rootView: LauncherView(model: model))
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        return window
    }

    private func bringToFront() {
        let app = NSApplication.shared
        app.unhide(nil)
        // macOS 14+. Brings the launcher forward again when an activity quits.
        app.activate()
        for window in windows {
            window.level = .normal
            window.orderFrontRegardless()
        }
        windows.first?.makeKeyAndOrderFront(nil)
        applyKiosk()
    }

    private func sendBehind() {
        for window in windows {
            window.orderBack(nil)
        }
    }

    private func showNotice(_ text: String) {
        let panel = notice ?? NoticePanel()
        notice = panel
        panel.show(message: text)
    }

    private func installKeyMonitors() {
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.filterKey(event) ?? event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.maybeParentChord(event)
        }) {
            monitors.append(global)
        }
    }

    private func maybeParentChord(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = event.charactersIgnoringModifiers ?? ""
        guard ParentGesture.isParentChord(
            control: flags.contains(.control),
            option: flags.contains(.option),
            command: flags.contains(.command),
            character: chars
        ) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.bringToFront()
            self?.model.presentParentGate()
        }
    }

    private func filterKey(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
        let command = flags.contains(.command)
        let option = flags.contains(.option)
        let control = flags.contains(.control)
        if ParentGesture.isParentChord(control: control, option: option, command: command, character: chars) {
            model.presentParentGate()
            return nil
        }
        if event.keyCode == 53, model.gate != .hidden {
            model.cancelParentGate()
            return nil
        }
        if model.isEnforcing && command && option && event.keyCode == 53 {
            return nil
        }
        if model.isEnforcing && command && !option && !control && ["q", "h", "w", "m"].contains(chars) {
            return nil
        }
        if model.gate == .hidden,
           !command, !option, !control,
           chars.count == 1,
           let digit = Int(chars),
           (1...9).contains(digit) {
            let tiles = model.visibleTiles()
            if digit <= tiles.count {
                model.open(tiles[digit - 1])
                return nil
            }
        }
        return event
    }

    private func acquireInstanceLock() -> Bool {
        let directory = model.store.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("instance.lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        if fd < 0 { return true }
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        instanceLockFD = fd
        return true
    }
}

final class NoticePanel {
    private var panel: NSPanel?
    private var timer: Timer?

    func show(message: String) {
        let noticePanel = self.panel ?? makePanel()
        self.panel = noticePanel
        let hosting = NSHostingView(rootView: NoticeBubble(text: message))
        hosting.frame = NSRect(x: 0, y: 0, width: 680, height: 140)
        noticePanel.contentView = hosting
        noticePanel.setContentSize(NSSize(width: 680, height: 140))
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let size = noticePanel.frame.size
            noticePanel.setFrameOrigin(NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            ))
        }
        noticePanel.orderFrontRegardless()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: false) { [weak noticePanel] _ in
            noticePanel?.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        return panel
    }
}

struct NoticeBubble: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.28))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(8)
    }
}
#endif
