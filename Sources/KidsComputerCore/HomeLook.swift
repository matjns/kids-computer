import Foundation

/// A plain red/green/blue color, each part from 0 to 1. Kept in the logic
/// module so the contrast rules can be tested without SwiftUI.
public struct RGB: Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    public static let white = RGB(1, 1, 1)
    /// The dark ink used for text on light backgrounds.
    public static let ink = RGB(0.10, 0.12, 0.22)

    /// WCAG relative luminance.
    public var luminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    /// WCAG contrast ratio, from 1 (none) to 21 (black on white).
    public func contrast(with other: RGB) -> Double {
        let a = luminance
        let b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// Which text color sits on top of a background.
public enum TextTone: String, Equatable {
    case dark
    case light

    public var rgb: RGB { self == .dark ? .ink : .white }
}

public enum Contrast {
    /// Large, bold home-screen text (WCAG AA for large text is 3:1; we aim higher).
    public static let homeTextTarget = 4.5
    /// Tile titles are 32 pt bold, which counts as large text.
    public static let tileTextTarget = 3.0

    /// Picks dark or light text so the worst spot on the background is as
    /// readable as possible. For a gradient, every color stop is checked.
    public static func tone(on colors: [RGB]) -> TextTone {
        guard !colors.isEmpty else { return .dark }
        let dark = worst(.ink, on: colors)
        let light = worst(.white, on: colors)
        return light > dark ? .light : .dark
    }

    public static func worst(_ text: RGB, on colors: [RGB]) -> Double {
        colors.map { text.contrast(with: $0) }.min() ?? 1
    }

    /// The contrast the chosen tone actually gets.
    public static func bestContrast(on colors: [RGB]) -> Double {
        worst(tone(on: colors).rgb, on: colors)
    }
}

extension TileAccent {
    public var rgb: RGB {
        switch self {
        case .orange: return RGB(0.93, 0.40, 0.10)
        case .teal: return RGB(0.02, 0.56, 0.52)
        case .purple: return RGB(0.40, 0.34, 0.93)
        case .blue: return RGB(0.18, 0.44, 0.95)
        case .green: return RGB(0.12, 0.56, 0.33)
        case .pink: return RGB(0.88, 0.30, 0.53)
        case .yellow: return RGB(0.98, 0.76, 0.18)
        case .red: return RGB(0.88, 0.26, 0.26)
        }
    }

    /// White text when it is readable as large text, otherwise dark text.
    public var textTone: TextTone {
        RGB.white.contrast(with: rgb) >= Contrast.tileTextTarget ? .light : .dark
    }

    public var usesDarkText: Bool {
        textTone == .dark
    }

    public var kidName: String {
        switch self {
        case .orange: return "Orange"
        case .teal: return "Teal"
        case .purple: return "Purple"
        case .blue: return "Blue"
        case .green: return "Green"
        case .pink: return "Pink"
        case .yellow: return "Yellow"
        case .red: return "Red"
        }
    }
}

/// Home-screen backgrounds the child can pick. `playroom` is the original look.
public enum LookBackground: String, Codable, CaseIterable, Hashable {
    case playroom
    // Bright solids
    case sunshine
    case peach
    case bubblegum
    case lavender
    case sky
    case mint
    case cherry
    case ocean
    case grape
    case forest
    case midnight
    // Gradients
    case sunset
    case lagoon
    case rainbow
    case space

    public var colors: [RGB] {
        switch self {
        case .playroom: return [RGB(1.0, 0.95, 0.86), RGB(0.80, 0.91, 1.0), RGB(0.86, 0.95, 0.88)]
        case .sunshine: return [RGB(1.0, 0.86, 0.30)]
        case .peach: return [RGB(1.0, 0.78, 0.62)]
        case .bubblegum: return [RGB(1.0, 0.72, 0.84)]
        case .lavender: return [RGB(0.82, 0.76, 1.0)]
        case .sky: return [RGB(0.62, 0.84, 1.0)]
        case .mint: return [RGB(0.62, 0.93, 0.78)]
        case .cherry: return [RGB(0.78, 0.12, 0.24)]
        case .ocean: return [RGB(0.10, 0.32, 0.78)]
        case .grape: return [RGB(0.42, 0.20, 0.72)]
        case .forest: return [RGB(0.08, 0.45, 0.30)]
        case .midnight: return [RGB(0.10, 0.12, 0.28)]
        case .sunset: return [RGB(1.0, 0.80, 0.55), RGB(1.0, 0.66, 0.74)]
        case .lagoon: return [RGB(0.55, 0.85, 1.0), RGB(0.62, 0.95, 0.85)]
        case .rainbow:
            return [
                RGB(1.0, 0.75, 0.75), RGB(1.0, 0.93, 0.65), RGB(0.72, 0.95, 0.75),
                RGB(0.70, 0.82, 1.0), RGB(0.85, 0.75, 1.0),
            ]
        case .space: return [RGB(0.08, 0.08, 0.25), RGB(0.30, 0.12, 0.45)]
        }
    }

    public var isGradient: Bool { colors.count > 1 }

    public var kidName: String {
        switch self {
        case .playroom: return "Playroom"
        case .sunshine: return "Sunshine"
        case .peach: return "Peach"
        case .bubblegum: return "Bubblegum"
        case .lavender: return "Lavender"
        case .sky: return "Sky"
        case .mint: return "Mint"
        case .cherry: return "Cherry"
        case .ocean: return "Ocean"
        case .grape: return "Grape"
        case .forest: return "Forest"
        case .midnight: return "Midnight"
        case .sunset: return "Sunset"
        case .lagoon: return "Lagoon"
        case .rainbow: return "Rainbow"
        case .space: return "Space"
        }
    }

    public var textTone: TextTone { Contrast.tone(on: colors) }

    public static var solids: [LookBackground] { allCases.filter { !$0.isGradient } }
    public static var gradients: [LookBackground] { allCases.filter { $0.isGradient } }
}

/// A light, drawn-in-code pattern over the background. No picture files.
public enum LookPattern: String, Codable, CaseIterable, Hashable {
    case plain
    case stars
    case dots
    case waves

    public var kidName: String {
        switch self {
        case .plain: return "Plain"
        case .stars: return "Stars"
        case .dots: return "Dots"
        case .waves: return "Waves"
        }
    }

    public var symbolName: String {
        switch self {
        case .plain: return "square"
        case .stars: return "star.fill"
        case .dots: return "circle.grid.3x3.fill"
        case .waves: return "water.waves"
        }
    }
}

/// How the activity tiles are colored.
public enum LookTileColors: Codable, Equatable, Hashable {
    /// Each activity keeps the color a parent picked.
    case activityColors
    /// Every tile uses one color the child picked.
    case all(TileAccent)

    public static var choices: [LookTileColors] {
        [.activityColors] + TileAccent.allCases.map { .all($0) }
    }

    public func accent(for tile: Tile) -> TileAccent {
        switch self {
        case .activityColors: return tile.accent
        case .all(let accent): return accent
        }
    }

    public var kidName: String {
        switch self {
        case .activityColors: return "Mix"
        case .all(let accent): return accent.kidName
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LookTileColors(rawValue: raw)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// "activity" or the accent name. Anything unknown means "activity".
    public init(rawValue: String) {
        if let accent = TileAccent(rawValue: rawValue) {
            self = .all(accent)
        } else {
            self = .activityColors
        }
    }

    public var rawValue: String {
        switch self {
        case .activityColors: return "activity"
        case .all(let accent): return accent.rawValue
        }
    }
}

/// The child's personal look for the home screen. Saved in tiles.json under
/// "look", apart from the parent-only settings. It can only change colors and
/// decoration; it never touches tiles, limits, or the lock.
public struct HomeLook: Codable, Equatable, Hashable {
    public var background: LookBackground
    public var pattern: LookPattern
    public var tileColors: LookTileColors

    public init(
        background: LookBackground = .playroom,
        pattern: LookPattern = .plain,
        tileColors: LookTileColors = .activityColors
    ) {
        self.background = background
        self.pattern = pattern
        self.tileColors = tileColors
    }

    public static let standard = HomeLook()

    public var textTone: TextTone { background.textTone }

    public var isStandard: Bool { self == .standard }

    /// Unknown or misspelled values fall back to the standard look instead of
    /// breaking the whole activity file.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let backgroundRaw = (try? container.decodeIfPresent(String.self, forKey: .background))
        let patternRaw = (try? container.decodeIfPresent(String.self, forKey: .pattern))
        let tileRaw = (try? container.decodeIfPresent(String.self, forKey: .tileColors))
        background = backgroundRaw.flatMap(LookBackground.init(rawValue:)) ?? .playroom
        pattern = patternRaw.flatMap(LookPattern.init(rawValue:)) ?? .plain
        tileColors = tileRaw.map(LookTileColors.init(rawValue:)) ?? .activityColors
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(background, forKey: .background)
        try container.encode(pattern, forKey: .pattern)
        try container.encode(tileColors, forKey: .tileColors)
    }

    private enum CodingKeys: String, CodingKey {
        case background, pattern, tileColors
    }
}

/// The rules for who may change the look.
public enum LookPermission {
    /// The child's "Make it mine" button shows only when the parent allows it
    /// and the activity file was read cleanly (so a child save can never
    /// overwrite a file a parent needs to fix).
    public static func childCanCustomize(config: LauncherConfig, configHasError: Bool) -> Bool {
        config.childCanCustomizeLook && !configHasError
    }

    /// Applies a child's look to the config. Only the look changes; every
    /// parent setting is copied through untouched.
    public static func applyingChildLook(_ look: HomeLook, to config: LauncherConfig) -> LauncherConfig? {
        guard config.childCanCustomizeLook else { return nil }
        var next = config
        next.look = look
        return next
    }

    public static func resettingLook(_ config: LauncherConfig) -> LauncherConfig {
        var next = config
        next.look = .standard
        return next
    }
}

public enum LookCopy {
    public static let button = "Make it mine"
    public static let title = "Make it mine!"
    public static let backgroundSection = "Pick a background"
    public static let patternSection = "Add a pattern"
    public static let tileSection = "Tile colors"
    public static let done = "All done"
    public static let cancel = "Never mind"
    public static let startOver = "Start over"

    public static var fixedStrings: [String] {
        [button, title, backgroundSection, patternSection, tileSection, done, cancel, startOver]
    }
}
