#if os(macOS)
import Darwin
import Foundation
import Security
import ServiceManagement
import KidsComputerCore

enum KeychainError: Error, CustomStringConvertible {
    case status(OSStatus)

    var description: String {
        "Keychain error \(statusCode)"
    }

    private var statusCode: OSStatus {
        switch self {
        case .status(let code): return code
        }
    }
}

enum KeychainPasswordStore {
    static let service = LauncherRelease.bundleID
    static let account = "parent-password"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let existing = SecItemCopyMatching(query as CFDictionary, nil)
        if existing == errSecSuccess {
            let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError.status(status) }
            return
        }
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }
}

enum LoginItemController {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func register() throws {
        try SMAppService.mainApp.register()
    }

    static func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    static func describe(_ value: SMAppService.Status) -> String {
        switch value {
        case .enabled:
            return "This account will open the launcher at login."
        case .requiresApproval:
            return "macOS wants approval in System Settings → General → Login Items."
        case .notFound:
            return "macOS can't find the app bundle. Copy it to /Applications, then try again."
        case .notRegistered:
            return "The launcher is not a login item yet."
        @unknown default:
            return "Login item status is unknown."
        }
    }
}

enum LaunchAgentInstaller {
    static var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(LaunchAgentManifest.label).plist")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func install() throws {
        guard let executable = Bundle.main.executableURL?.path else {
            throw InstallError.missingExecutable
        }
        let folder = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let xml = LaunchAgentManifest.xml(executablePath: executable)
        try xml.write(to: plistURL, atomically: true, encoding: .utf8)
        let uid = String(getuid())
        _ = runLaunchctl(["bootout", "gui/\(uid)", plistURL.path])
        let status = runLaunchctl(["bootstrap", "gui/\(uid)", plistURL.path])
        guard status == 0 else { throw InstallError.launchctl(status) }
        FileLog.append("Installed LaunchAgent at \(plistURL.path)")
    }

    static func uninstall() throws {
        let uid = String(getuid())
        _ = runLaunchctl(["bootout", "gui/\(uid)", plistURL.path])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        FileLog.append("Removed LaunchAgent")
    }

    private static func runLaunchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return 1
        }
    }

    enum InstallError: Error, CustomStringConvertible {
        case missingExecutable
        case launchctl(Int32)

        var description: String {
            switch self {
            case .missingExecutable:
                return "This copy isn't inside an application bundle."
            case .launchctl(let code):
                return "launchctl failed with status \(code)."
            }
        }
    }
}

enum FileLog {
    static func append(_ message: String) {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let store = ConfigStore(directory: SupportLayout.directory(home: home))
        try? store.prepare()
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let url = store.logURL
        if FileManager.default.fileExists(atPath: url.path), let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
        trim(url)
        NSLog("%@", message)
    }

    private static func trim(_ url: URL) {
        guard let bytes = try? Data(contentsOf: url), bytes.count > 200_000 else { return }
        let tail = bytes.suffix(150_000)
        try? tail.write(to: url, options: .atomic)
    }
}
#endif
