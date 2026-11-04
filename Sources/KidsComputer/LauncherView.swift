#if os(macOS)
import AppKit
import SwiftUI
import KidsComputerCore

struct LauncherView: View {
    @Bindable var model: LauncherModel

    var body: some View {
        ZStack {
            HomeBackground(look: model.displayedLook)
            VStack(alignment: .leading, spacing: 22) {
                header
                if model.showsLockPause {
                    Text(model.lockPauseMessage)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.9), in: Capsule())
                }
                if model.loadError != nil, model.gate == .hidden {
                    Text(KidCopy.configError)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.28, blue: 0.38))
                        .padding(18)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                ScrollView {
                    tiles
                        .padding(.bottom, 12)
                }
            }
            .padding(36)

            VStack {
                HStack(alignment: .top) {
                    StarTap {
                        model.registerCornerTap()
                    }
                    .accessibilityHidden(true)
                    Spacer()
                    if model.childCanCustomizeLook, model.gate == .hidden, !model.lookPickerOpen {
                        MakeItMineButton {
                            model.openLookPicker()
                        }
                        .padding(.trailing, 12)
                    }
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.22, green: 0.26, blue: 0.38))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.85), in: Capsule())
                    }
                }
                Spacer()
            }
            .padding(20)

            if let banner = model.banner {
                VStack {
                    Spacer()
                    Text(banner)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 24)
                }
            }

            if model.lookPickerOpen, model.gate == .hidden {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {}
                LookPickerSheet(model: model)
                    .padding(24)
            }

            if model.gate != .hidden {
                Color.black.opacity(0.28).ignoresSafeArea()
                ParentSheet(model: model)
                    .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.light)
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 6) {
                Text(Greeting.line(name: model.config.greetingName, at: context.date, calendar: .current))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(homeText)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(KidCopy.prompt)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(homeText)
            }
            .padding(.leading, 8)
            .padding(.top, 36)
        }
    }

    /// Dark or white, whichever reads best on the current background.
    private var homeText: Color {
        model.displayedLook.textTone.rgb.color
    }

    @ViewBuilder
    private var tiles: some View {
        let visible = model.visibleTiles()
        if visible.isEmpty {
            Text(KidCopy.emptyActivities)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(homeText)
                .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 420), spacing: 22)], spacing: 22) {
                ForEach(visible) { tile in
                    TileCard(
                        tile: tile,
                        accent: model.displayedLook.tileColors.accent(for: tile),
                        face: model.face(for: tile),
                        icon: icon(for: tile)
                    ) {
                        model.open(tile)
                    }
                }
            }
        }
    }

    private func icon(for tile: Tile) -> NSImage? {
        let customExists = tile.customIconPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        switch chooseTileIcon(tile: tile, installedPath: model.installedPaths[tile.id], customIconExists: customExists) {
        case .customFile(let path):
            return NSImage(contentsOfFile: path)
        case .application(let path):
            return NSWorkspace.shared.icon(forFile: path)
        case .symbol:
            return nil
        }
    }
}

private struct StarTap: View {
    var action: () -> Void

    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.20).opacity(0.7))
            .frame(width: 56, height: 56)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
    }
}

private struct TileCard: View {
    var tile: Tile
    var accent: TileAccent
    var face: TileFace
    var icon: NSImage?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    iconView
                    if case .comingSoon = face {
                        badge(KidCopy.comingSoonBadge)
                    }
                }
                Text(tile.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if !tile.subtitle.isEmpty {
                    Text(tile.subtitle)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }
                status
            }
            .foregroundStyle(accent.usesDarkText ? Color(red: 0.22, green: 0.16, blue: 0.05) : Color.white)
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 250)
            .background(background, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(alignment: .topLeading) {
                if case .doneForToday = face {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 18, weight: .bold))
                        .padding(16)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
            .opacity(face == .comingSoon ? 0.78 : 1)
            .saturation(isDimmed ? 0 : 1)
        }
        .buttonStyle(TilePressStyle())
        .accessibilityLabel(accessibilityName)
    }

    private var isDimmed: Bool {
        if case .doneForToday = face { return true }
        return false
    }

    private var background: Color {
        accent.color
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            Image(systemName: tile.symbolName)
                .font(.system(size: 64, weight: .semibold))
                .frame(width: 104, height: 104)
                .symbolRenderingMode(.hierarchical)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch face {
        case .ready(let minutes):
            if let minutes {
                Text(KidCopy.minutesLeft(minutes))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        case .comingSoon:
            EmptyView()
        case .doneForToday:
            Text(KidCopy.seeYouTomorrow)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        case .turnedOff:
            EmptyView()
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.92), in: Capsule())
            .foregroundStyle(Color(red: 0.22, green: 0.24, blue: 0.36))
    }

    private var accessibilityName: String {
        switch face {
        case .ready:
            return tile.title
        case .comingSoon:
            return "\(tile.title), \(KidCopy.comingSoonBadge)"
        case .doneForToday:
            return "\(tile.title), \(KidCopy.seeYouTomorrow)"
        case .turnedOff:
            return tile.title
        }
    }
}

private struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

extension TileAccent {
    var color: Color {
        rgb.color
    }
}

extension RGB {
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
#endif
