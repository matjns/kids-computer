import Foundation

public enum ConfigStoreError: Error, Equatable {
    case unreadable(String)
}

public enum AtomicFile {
    public static func write(_ data: Data, to url: URL, fileManager: FileManager = .default) throws {
        let folder = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let temp = folder.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        try data.write(to: temp, options: .atomic)
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: temp)
        } else {
            try fileManager.moveItem(at: temp, to: url)
        }
    }
}

public struct ConfigStore {
    public var directory: URL
    public var fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public var configURL: URL { directory.appendingPathComponent(LauncherRelease.configFileName) }
    public var usageURL: URL { directory.appendingPathComponent(LauncherRelease.usageFileName) }
    public var logURL: URL { directory.appendingPathComponent(LauncherRelease.logFileName) }
    public var iconsDirectory: URL { directory.appendingPathComponent("icons", isDirectory: true) }
    public var backupURL: URL { directory.appendingPathComponent("tiles.json.bak") }

    public func prepare() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: iconsDirectory, withIntermediateDirectories: true)
    }

    public func loadConfig() throws -> LauncherConfig {
        try prepare()
        guard fileManager.fileExists(atPath: configURL.path) else {
            let starter = LauncherConfig.starter
            try saveConfig(starter)
            return starter
        }
        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(LauncherConfig.self, from: data)
        } catch {
            throw ConfigStoreError.unreadable(error.localizedDescription)
        }
    }

    public func saveConfig(_ config: LauncherConfig) throws {
        try prepare()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(config)
        data.append(0x0a)
        try AtomicFile.write(data, to: configURL, fileManager: fileManager)
    }

    public func backupConfig() throws {
        guard fileManager.fileExists(atPath: configURL.path) else { return }
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.copyItem(at: configURL, to: backupURL)
    }

    public func loadUsage() -> UsageLog {
        guard fileManager.fileExists(atPath: usageURL.path) else {
            return UsageLog()
        }
        do {
            let data = try Data(contentsOf: usageURL)
            return try JSONDecoder().decode(UsageLog.self, from: data)
        } catch {
            let broken = directory.appendingPathComponent("usage.json.bak")
            try? fileManager.removeItem(at: broken)
            try? fileManager.moveItem(at: usageURL, to: broken)
            return UsageLog()
        }
    }

    public func saveUsage(_ log: UsageLog) throws {
        try prepare()
        var pruned = log
        pruned.prune(keepingNewest: 30)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var data = try encoder.encode(pruned)
        data.append(0x0a)
        try AtomicFile.write(data, to: usageURL, fileManager: fileManager)
    }
}
