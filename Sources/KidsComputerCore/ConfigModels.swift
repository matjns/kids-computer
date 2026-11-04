import Foundation

public enum LauncherRelease {
    public static let version = "1.0.0"
    public static let bundleID = "com.kidscomputer.launcher"
    public static let displayName = "Kids Computer"
    public static let executableName = "KidsComputer"
    /// ~/Library/Application Support/Kids Computer/
    public static let supportFolderName = "Kids Computer"
    public static let configFileName = "tiles.json"
    public static let usageFileName = "usage.json"
    public static let logFileName = "launcher.log"
}

public enum SupportLayout {
    public static func directory(home: URL) -> URL {
        home.appendingPathComponent("Library/Application Support/\(LauncherRelease.supportFolderName)", isDirectory: true)
    }
}

public enum TileAccent: String, Codable, CaseIterable, Hashable, Equatable {
    case orange
    case teal
    case purple
    case blue
    case green
    case pink
    case yellow
    case red
}

public struct Tile: Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var bundleIdentifier: String?
    public var applicationPath: String?
    public var customIconPath: String?
    public var dailyLimitMinutes: Int?
    public var accent: TileAccent
    public var enabled: Bool
    public var symbolName: String

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        bundleIdentifier: String? = nil,
        applicationPath: String? = nil,
        customIconPath: String? = nil,
        dailyLimitMinutes: Int? = nil,
        accent: TileAccent = .blue,
        enabled: Bool = true,
        symbolName: String = "sparkles"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.bundleIdentifier = bundleIdentifier
        self.applicationPath = applicationPath
        self.customIconPath = customIconPath
        self.dailyLimitMinutes = dailyLimitMinutes
        self.accent = accent
        self.enabled = enabled
        self.symbolName = symbolName
    }

    public func normalized() -> Tile {
        var copy = self
        copy.id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.bundleIdentifier = Self.blankToNil(bundleIdentifier)
        copy.applicationPath = Self.blankToNil(applicationPath)
        copy.customIconPath = Self.blankToNil(customIconPath)
        copy.symbolName = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.symbolName.isEmpty {
            copy.symbolName = "sparkles"
        }
        if let limit = copy.dailyLimitMinutes, limit <= 0 {
            copy.dailyLimitMinutes = nil
        }
        return copy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
        bundleIdentifier = Self.blankToNil(try container.decodeIfPresent(String.self, forKey: .bundleIdentifier))
        applicationPath = Self.blankToNil(try container.decodeIfPresent(String.self, forKey: .applicationPath))
        customIconPath = Self.blankToNil(try container.decodeIfPresent(String.self, forKey: .customIconPath))
        let limit = try container.decodeIfPresent(Int.self, forKey: .dailyLimitMinutes)
        dailyLimitMinutes = (limit ?? 0) > 0 ? limit : nil
        accent = try container.decodeIfPresent(TileAccent.self, forKey: .accent) ?? .blue
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        let symbol = try container.decodeIfPresent(String.self, forKey: .symbolName) ?? "sparkles"
        symbolName = symbol.isEmpty ? "sparkles" : symbol
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        if !subtitle.isEmpty {
            try container.encode(subtitle, forKey: .subtitle)
        }
        try container.encodeIfPresent(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encodeIfPresent(applicationPath, forKey: .applicationPath)
        try container.encodeIfPresent(customIconPath, forKey: .customIconPath)
        try container.encodeIfPresent(dailyLimitMinutes, forKey: .dailyLimitMinutes)
        try container.encode(accent, forKey: .accent)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(symbolName, forKey: .symbolName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, bundleIdentifier, applicationPath, customIconPath
        case dailyLimitMinutes, accent, enabled, symbolName
    }

    private static func blankToNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

public struct LauncherConfig: Codable, Equatable {
    public var version: Int
    public var greetingName: String
    public var kioskEnabled: Bool
    public var warnBeforeMinutes: Int
    public var parentPasswordHash: String?
    public var extraProtectedBundleIDs: [String]
    public var tiles: [Tile]
    /// Parent setting: may the child open "Make it mine"? On by default.
    public var childCanCustomizeLook: Bool
    /// The child's chosen colors and pattern for the home screen.
    public var look: HomeLook

    public init(
        version: Int = 1,
        greetingName: String = "",
        kioskEnabled: Bool = true,
        warnBeforeMinutes: Int = 5,
        parentPasswordHash: String? = nil,
        extraProtectedBundleIDs: [String] = [],
        tiles: [Tile],
        childCanCustomizeLook: Bool = true,
        look: HomeLook = .standard
    ) {
        self.version = version
        self.greetingName = greetingName
        self.kioskEnabled = kioskEnabled
        self.warnBeforeMinutes = warnBeforeMinutes
        self.parentPasswordHash = parentPasswordHash
        self.extraProtectedBundleIDs = extraProtectedBundleIDs
        self.tiles = tiles
        self.childCanCustomizeLook = childCanCustomizeLook
        self.look = look
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        greetingName = try container.decodeIfPresent(String.self, forKey: .greetingName) ?? ""
        kioskEnabled = try container.decodeIfPresent(Bool.self, forKey: .kioskEnabled) ?? true
        warnBeforeMinutes = try container.decodeIfPresent(Int.self, forKey: .warnBeforeMinutes) ?? 5
        let hash = try container.decodeIfPresent(String.self, forKey: .parentPasswordHash)
        parentPasswordHash = (hash?.isEmpty == false) ? hash : nil
        extraProtectedBundleIDs = try container.decodeIfPresent([String].self, forKey: .extraProtectedBundleIDs) ?? []
        tiles = try container.decode([Tile].self, forKey: .tiles)
        childCanCustomizeLook = (try? container.decodeIfPresent(Bool.self, forKey: .childCanCustomizeLook)) ?? true
        look = (try? container.decodeIfPresent(HomeLook.self, forKey: .look)) ?? .standard
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(greetingName, forKey: .greetingName)
        try container.encode(kioskEnabled, forKey: .kioskEnabled)
        try container.encode(warnBeforeMinutes, forKey: .warnBeforeMinutes)
        try container.encodeIfPresent(parentPasswordHash, forKey: .parentPasswordHash)
        try container.encode(extraProtectedBundleIDs, forKey: .extraProtectedBundleIDs)
        try container.encode(tiles, forKey: .tiles)
        try container.encode(childCanCustomizeLook, forKey: .childCanCustomizeLook)
        try container.encode(look, forKey: .look)
    }

    private enum CodingKeys: String, CodingKey {
        case version, greetingName, kioskEnabled, warnBeforeMinutes
        case parentPasswordHash, extraProtectedBundleIDs, tiles
        case childCanCustomizeLook, look
    }

    public static var starter: LauncherConfig {
        LauncherConfig(
            version: 1,
            greetingName: "",
            kioskEnabled: true,
            warnBeforeMinutes: 5,
            parentPasswordHash: nil,
            extraProtectedBundleIDs: [],
            tiles: [
                Tile(
                    id: "race-time",
                    title: "Race Time",
                    subtitle: "Physics and racing",
                    bundleIdentifier: "com.racetime.fsae",
                    applicationPath: "/Applications/RaceTime.app",
                    accent: .orange,
                    symbolName: "flag.checkered"
                ),
                Tile(
                    id: "typing-tutor",
                    title: "Typing Tutor",
                    subtitle: "Learn the keys",
                    bundleIdentifier: "com.kidscomputer.typingtutor",
                    accent: .teal,
                    symbolName: "keyboard"
                ),
                Tile(
                    id: "chess",
                    title: "Chess",
                    subtitle: "A classic board game",
                    bundleIdentifier: "com.apple.Chess",
                    applicationPath: "/System/Applications/Chess.app",
                    accent: .purple,
                    symbolName: "crown.fill"
                ),
                Tile(
                    id: "math-quiz",
                    title: "Math Quiz",
                    subtitle: "Numbers and puzzles",
                    bundleIdentifier: "com.kidscomputer.mathquiz",
                    accent: .blue,
                    symbolName: "function"
                ),
                Tile(
                    id: "reading",
                    title: "Reading",
                    subtitle: "Comprehension game",
                    bundleIdentifier: "com.kidscomputer.reading",
                    accent: .green,
                    symbolName: "book.fill"
                ),
                Tile(
                    id: "drawing",
                    title: "Drawing Helper",
                    subtitle: "Sketch and create",
                    bundleIdentifier: "com.kidscomputer.drawing",
                    accent: .pink,
                    symbolName: "paintbrush.pointed.fill"
                ),
            ]
        )
    }

    public func restoringStarterTiles() -> LauncherConfig {
        var copy = self
        copy.tiles = LauncherConfig.starter.tiles
        return copy
    }

    public func approvedTargets(resolvedPaths: [String: String] = [:]) -> [ApprovedTarget] {
        tiles.filter(\.enabled).map { tile in
            ApprovedTarget(
                bundleIdentifier: tile.bundleIdentifier,
                applicationPath: resolvedPaths[tile.id] ?? tile.applicationPath
            )
        }
    }

    public func limitMinutesByTile() -> [String: Int?] {
        Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0.dailyLimitMinutes) })
    }
}

public enum ConfigCheck {
    public static func issues(in config: LauncherConfig) -> [String] {
        var issues: [String] = []
        if config.warnBeforeMinutes < 0 {
            issues.append("The warning time can't be negative.")
        }
        var seen: Set<String> = []
        for tile in config.tiles {
            let normalized = tile.normalized()
            if normalized.id.isEmpty {
                issues.append("Every activity needs an id.")
            } else if !seen.insert(normalized.id).inserted {
                issues.append("Two activities share the id \"\(normalized.id)\".")
            }
            if normalized.title.isEmpty {
                issues.append("An activity is missing a name.")
            }
            if normalized.bundleIdentifier == nil && normalized.applicationPath == nil {
                let name = normalized.title.isEmpty ? "An activity" : "\"\(normalized.title)\""
                issues.append("\(name) needs a bundle id or an application path.")
            }
        }
        return issues
    }
}

public enum TileList {
    public enum Direction: Equatable {
        case up
        case down
    }

    public static func move(_ id: String, _ direction: Direction, in tiles: inout [Tile]) {
        guard let index = tiles.firstIndex(where: { $0.id == id }) else { return }
        let destination = direction == .up ? index - 1 : index + 1
        guard tiles.indices.contains(destination) else { return }
        tiles.swapAt(index, destination)
    }

    public static func removing(_ id: String, from tiles: [Tile]) -> [Tile] {
        tiles.filter { $0.id != id }
    }

    public static func uniqueID(basedOn title: String, existing: [Tile]) -> String {
        let base = slug(title).isEmpty ? "activity" : slug(title)
        if !existing.contains(where: { $0.id == base }) {
            return base
        }
        var suffix = 2
        while existing.contains(where: { $0.id == "\(base)-\(suffix)" }) {
            suffix += 1
        }
        return "\(base)-\(suffix)"
    }

    public static func slug(_ title: String) -> String {
        let lowered = title.lowercased()
        var output = ""
        var pendingDash = false
        for character in lowered {
            if character.isLetter || character.isNumber {
                if pendingDash && !output.isEmpty {
                    output.append("-")
                }
                pendingDash = false
                output.append(character)
            } else {
                pendingDash = true
            }
        }
        return output
    }
}
