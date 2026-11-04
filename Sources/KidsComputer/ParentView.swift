#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import KidsComputerCore

struct ParentSheet: View {
    @Bindable var model: LauncherModel

    var body: some View {
        switch model.gate {
        case .hidden:
            EmptyView()
        case .createPassword:
            PasswordCard(
                title: "Parent password",
                message: "Choose a password for changing activities, time limits, and the desktop lock. Pick something a child won't guess. It is saved as a salted hash, never as the password itself.",
                confirm: true,
                busy: model.passwordBusy,
                error: model.parentError,
                button: "Save password"
            ) { password, confirmation in
                model.submitNewPassword(password, confirmation: confirmation ?? "")
            } cancel: {
                model.cancelParentGate()
            }
        case .enterPassword:
            PasswordCard(
                title: "Parents",
                message: "Enter the parent password.",
                confirm: false,
                busy: model.passwordBusy,
                error: model.parentError,
                button: "Unlock"
            ) { password, _ in
                model.submitLogin(password)
            } cancel: {
                model.cancelParentGate()
            }
        case .settings:
            SettingsCard(model: model)
        case .editing(let tile, let isNew):
            TileEditor(tile: tile, isNew: isNew, model: model)
                .id(tile.id + (isNew ? "-new" : "-edit"))
        case .confirmQuit:
            ConfirmCard(
                title: "Quit the launcher?",
                message: "The desktop will be reachable until the next login, or until the reopen watchdog starts the launcher again.",
                confirmTitle: "Quit",
                destructive: true
            ) {
                model.allowQuit = true
                NSApplication.shared.terminate(nil)
            } cancel: {
                model.gate = .settings
            }
        case .confirmRestore:
            ConfirmCard(
                title: "Restore the starter activities?",
                message: "This replaces the activity list with Race Time, Typing Tutor, Chess, Math Quiz, Reading, and Drawing Helper. A backup is saved as tiles.json.bak. The greeting and parent password stay.",
                confirmTitle: "Restore",
                destructive: false
            ) {
                model.restoreStarterTiles()
            } cancel: {
                model.gate = .settings
            }
        case .confirmDelete(let tile):
            ConfirmCard(
                title: "Remove \(tile.title)?",
                message: "You can add it again later.",
                confirmTitle: "Remove",
                destructive: true
            ) {
                model.deleteTile(tile.id)
            } cancel: {
                model.gate = .settings
            }
        }
    }
}

private struct PasswordCard: View {
    var title: String
    var message: String
    var confirm: Bool
    var busy: Bool
    var error: String?
    var button: String
    var submit: (String, String?) -> Void
    var cancel: () -> Void

    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
            if confirm {
                SecureField("Type it again", text: $confirmation)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            }
            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.system(size: 15, weight: .semibold))
            }
            HStack {
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(busy ? "Saving…" : button) {
                    submit(password, confirm ? confirmation : nil)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(busy || password.isEmpty)
            }
        }
        .padding(28)
        .frame(maxWidth: 480)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
    }
}

private struct ConfirmCard: View {
    var title: String
    var message: String
    var confirmTitle: String
    var destructive: Bool
    var confirm: () -> Void
    var cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(message)
                .font(.system(size: 16))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Cancel", action: cancel)
                Spacer()
                Button(confirmTitle, role: destructive ? .destructive : nil, action: confirm)
            }
        }
        .padding(28)
        .frame(maxWidth: 520)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SettingsCard: View {
    @Bindable var model: LauncherModel
    @State private var greeting: String = ""
    @State private var protectedText: String = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var loginNote: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LauncherRelease.displayName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Version \(LauncherRelease.version)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Done") { model.cancelParentGate() }
                        .keyboardShortcut(.defaultAction)
                }

                if let note = model.passwordStoreNote {
                    Text(note).font(.system(size: 14)).foregroundStyle(.secondary)
                }
                if let error = model.parentError {
                    Text(error).foregroundStyle(.red)
                }

                group("Greeting") {
                    Text("Leave this blank and the home screen won't use a name.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $greeting)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: greeting) { _, newValue in
                            model.setGreeting(newValue)
                        }
                }

                group("Home screen look") {
                    Toggle("Let the child customize the look", isOn: Binding(
                        get: { model.config.childCanCustomizeLook },
                        set: { model.setChildCanCustomizeLook($0) }
                    ))
                    Text("Shows a Make it mine button on the home screen for picking a background color, a pattern, and tile colors. It can't change activities, time limits, the lock, files, or quitting.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(lookSummary)
                            .font(.system(size: 14))
                        Spacer()
                        Button("Reset look") { model.resetLook() }
                            .disabled(model.config.look.isStandard)
                    }
                }

                group("Desktop lock") {
                    Toggle("Keep the desktop locked", isOn: Binding(
                        get: { model.config.kioskEnabled },
                        set: { model.setKioskEnabled($0) }
                    ))
                    Text("While this is on, the Dock and menu bar stay hidden and apps that aren't in the list get closed. Turn it off while you install something, then turn it back on.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Stepper(value: Binding(
                        get: { model.config.warnBeforeMinutes },
                        set: { model.setWarnBeforeMinutes($0) }
                    ), in: 1...30) {
                        Text("Warn \(model.config.warnBeforeMinutes) minutes before time is up")
                    }
                }

                group("Activities") {
                    ForEach(Array(model.config.tiles.enumerated()), id: \.element.id) { index, tile in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(tile.accent.color)
                                .frame(width: 18, height: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tile.title).font(.system(size: 16, weight: .semibold))
                                Text(activityDetail(tile))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Up") { model.moveTile(tile.id, direction: .up) }
                                .disabled(index == 0)
                            Button("Down") { model.moveTile(tile.id, direction: .down) }
                                .disabled(index == model.config.tiles.count - 1)
                            Button("Edit") { model.gate = .editing(tile, isNew: false) }
                            Button("Remove") { model.gate = .confirmDelete(tile) }
                        }
                    }
                    Button("Add an activity") {
                        let tile = Tile(
                            id: TileList.uniqueID(basedOn: "New activity", existing: model.config.tiles),
                            title: "",
                            accent: .blue
                        )
                        model.gate = .editing(tile, isNew: true)
                    }
                    Button("Restore the starter activities") {
                        model.gate = .confirmRestore
                    }
                }

                group("Today") {
                    let tiles = model.config.tiles
                    if tiles.isEmpty {
                        Text("No activities yet.")
                    } else {
                        ForEach(tiles) { tile in
                            HStack {
                                Text(tile.title)
                                Spacer()
                                Text(DurationText.minutes(model.usedSeconds(for: tile.id)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                group("Open at login") {
                    Text(loginNote.isEmpty ? LoginItemController.describe(LoginItemController.status) : loginNote)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Open at login") { setLoginItem(enabled: true) }
                        Button("Stop opening at login") { setLoginItem(enabled: false) }
                        Button("Allow it in Settings") { model.pauseForSystemSettings() }
                    }
                    Text(LaunchAgentInstaller.isInstalled
                         ? "The reopen watchdog is installed for this account."
                         : "The reopen watchdog is off.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .id(model.revision)
                    HStack {
                        Button("Reopen if it crashes") { installAgent() }
                        Button("Remove the watchdog") { removeAgent() }
                    }
                    Text("Do this while logged in as the child. It only affects this account.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                group("Change the parent password") {
                    SecureField("New password", text: $newPassword)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Type it again", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                    Button(model.passwordBusy ? "Saving…" : "Change password") {
                        model.submitNewPassword(newPassword, confirmation: confirmPassword)
                        newPassword = ""
                        confirmPassword = ""
                    }
                    .disabled(model.passwordBusy || newPassword.isEmpty)
                }

                group("Apps the lock should ignore") {
                    Text("One bundle id per line. End a line with .* to ignore a whole family, such as com.example.tools.*")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextEditor(text: $protectedText)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(minHeight: 90)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
                    Button("Save ignored apps") {
                        let lines = protectedText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                        model.setExtraProtected(lines)
                    }
                }

                group("Activity file") {
                    Text(model.store.configURL.path)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                    Text("You can edit that file while the launcher is quit. The log is launcher.log in the same folder.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Quit the launcher") { model.gate = .confirmQuit }
                }

                Text("To open this screen again, press \(ParentGesture.chordDescription), or tap the star in the corner five times.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .frame(maxWidth: 860, maxHeight: 760)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
        .onAppear {
            greeting = model.config.greetingName
            protectedText = model.config.extraProtectedBundleIDs.joined(separator: "\n")
            loginNote = LoginItemController.describe(LoginItemController.status)
        }
    }

    private var lookSummary: String {
        let look = model.config.look
        if look.isStandard { return "Now: the standard look." }
        let tiles: String
        switch look.tileColors {
        case .activityColors: tiles = "each activity's own color"
        case .all(let accent): tiles = "\(accent.kidName.lowercased()) tiles"
        }
        return "Now: \(look.background.kidName) background, \(look.pattern.kidName.lowercased()) pattern, \(tiles)."
    }

    private func activityDetail(_ tile: Tile) -> String {
        let limit = tile.dailyLimitMinutes.map { "\($0) min a day" } ?? "No daily limit"
        let state: String
        if !tile.enabled {
            state = "Hidden"
        } else if model.installedPaths[tile.id] == nil {
            state = KidCopy.comingSoonBadge
        } else {
            state = "Installed"
        }
        return "\(state) · \(limit)"
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                try LoginItemController.register()
            } else {
                try LoginItemController.unregister()
            }
            loginNote = LoginItemController.describe(LoginItemController.status)
            model.parentError = nil
        } catch {
            loginNote = error.localizedDescription
            FileLog.append("Login item change failed: \(error)")
        }
    }

    private func installAgent() {
        do {
            try LaunchAgentInstaller.install()
            model.parentError = nil
            model.revision += 1
        } catch {
            model.parentError = "Couldn't install the watchdog. \(error)"
        }
    }

    private func removeAgent() {
        do {
            try LaunchAgentInstaller.uninstall()
            model.parentError = nil
            model.revision += 1
        } catch {
            model.parentError = "Couldn't remove the watchdog. \(error)"
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TileEditor: View {
    var isNew: Bool
    var model: LauncherModel
    @State private var draft: Tile
    @State private var limitOn: Bool
    @State private var limitMinutes: Int

    init(tile: Tile, isNew: Bool, model: LauncherModel) {
        self.isNew = isNew
        self.model = model
        _draft = State(initialValue: tile)
        let minutes = tile.dailyLimitMinutes ?? 30
        _limitOn = State(initialValue: tile.dailyLimitMinutes != nil)
        _limitMinutes = State(initialValue: max(5, minutes))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isNew ? "New activity" : "Edit activity")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                labeled("Name") {
                    TextField("Name", text: $draft.title)
                        .textFieldStyle(.roundedBorder)
                }
                labeled("Short description") {
                    TextField("Shown under the name", text: $draft.subtitle)
                        .textFieldStyle(.roundedBorder)
                }
                labeled("Bundle id") {
                    TextField("com.example.App", text: bundleBinding)
                        .textFieldStyle(.roundedBorder)
                }
                labeled("Application path") {
                    HStack {
                        TextField("/Applications/Example.app", text: pathBinding)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") { pickApplication() }
                    }
                }
                Toggle("Daily time limit", isOn: $limitOn)
                if limitOn {
                    Stepper(value: $limitMinutes, in: 5...240, step: 5) {
                        Text("\(limitMinutes) minutes a day")
                    }
                }
                Toggle("Show this activity", isOn: $draft.enabled)
                labeled("Color") {
                    Picker("Color", selection: $draft.accent) {
                        ForEach(TileAccent.allCases, id: \.self) { accent in
                            Text(accent.rawValue.capitalized).tag(accent)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                labeled("Fallback symbol") {
                    TextField("sparkles", text: $draft.symbolName)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Button("Choose a picture…") { pickIcon() }
                    if draft.customIconPath != nil {
                        Button("Use the app icon") { draft.customIconPath = nil }
                    }
                }
                if let error = model.parentError {
                    Text(error).foregroundStyle(.red)
                }
                HStack {
                    Button("Cancel") { model.gate = .settings }
                    Spacer()
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(28)
        }
        .frame(maxWidth: 720, maxHeight: 760)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var bundleBinding: Binding<String> {
        Binding(
            get: { draft.bundleIdentifier ?? "" },
            set: { draft.bundleIdentifier = $0 }
        )
    }

    private var pathBinding: Binding<String> {
        Binding(
            get: { draft.applicationPath ?? "" },
            set: { draft.applicationPath = $0 }
        )
    }

    private func save() {
        var tile = draft
        tile.dailyLimitMinutes = limitOn ? limitMinutes : nil
        model.saveTile(tile, isNew: isNew)
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        panel.message = "Choose an application"
        model.beginPanel()
        let response = panel.runModal()
        model.endPanel()
        if response == .OK, let url = panel.url {
            draft.applicationPath = url.path
            if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
                draft.title = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func pickIcon() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic]
        panel.prompt = "Choose"
        model.beginPanel()
        let response = panel.runModal()
        model.endPanel()
        guard response == .OK, let url = panel.url else { return }
        do {
            draft.customIconPath = try model.importIcon(from: url, tileID: draft.id)
        } catch {
            model.parentError = "Couldn't copy that picture."
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13, weight: .semibold))
            content()
        }
    }
}
#endif
