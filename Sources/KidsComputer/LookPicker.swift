#if os(macOS)
import SwiftUI
import KidsComputerCore

// The child's "Make it mine" sheet. It is plain SwiftUI drawn inside the
// launcher window: no file dialogs, no other apps, no system settings. The
// only thing it can change is the HomeLook (colors and a pattern).

struct HomeBackground: View {
    var look: HomeLook

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if look.background == .playroom {
                PlayroomBubbles()
            }
            PatternLayer(pattern: look.pattern, tone: look.textTone)
        }
        .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        let colors = look.background.colors.map(\.color)
        return colors.count == 1 ? [colors[0], colors[0]] : colors
    }
}

private struct PlayroomBubbles: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.62, blue: 0.30).opacity(0.28))
                .frame(width: 460)
                .offset(x: -420, y: -260)
            Circle()
                .fill(Color(red: 0.45, green: 0.55, blue: 0.98).opacity(0.22))
                .frame(width: 380)
                .offset(x: 460, y: 240)
            Circle()
                .fill(Color(red: 0.35, green: 0.82, blue: 0.70).opacity(0.25))
                .frame(width: 280)
                .offset(x: 280, y: -280)
        }
    }
}

/// A faint pattern drawn in code. It uses the same tone as the text, kept
/// very light, so it never fights with the words on top.
struct PatternLayer: View {
    var pattern: LookPattern
    var tone: TextTone
    var spacing: CGFloat = 72

    var body: some View {
        let ink = tone == .dark ? Color.black.opacity(0.07) : Color.white.opacity(0.13)
        let kind = pattern
        let step = spacing
        Canvas { context, size in
            switch kind {
            case .plain:
                break
            case .dots:
                var row = 0
                var y: CGFloat = step / 2
                while y < size.height + step {
                    var x: CGFloat = row % 2 == 0 ? step / 2 : step
                    while x < size.width + step {
                        let radius = step * 0.09
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(ink))
                        x += step
                    }
                    y += step * 0.8
                    row += 1
                }
            case .stars:
                var row = 0
                var y: CGFloat = step / 2
                while y < size.height + step {
                    var column = 0
                    var x: CGFloat = row % 2 == 0 ? step / 2 : step * 1.1
                    while x < size.width + step {
                        let big = (row + column) % 3 == 0
                        let radius = step * (big ? 0.22 : 0.13)
                        context.fill(PatternLayer.star(center: CGPoint(x: x, y: y), radius: radius), with: .color(ink))
                        x += step * 1.2
                        column += 1
                    }
                    y += step
                    row += 1
                }
            case .waves:
                var y: CGFloat = step / 2
                while y < size.height + step {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x <= size.width + 8 {
                        let wave = sin(x / step * 2 * .pi) * step * 0.12
                        path.addLine(to: CGPoint(x: x, y: y + wave))
                        x += 8
                    }
                    context.stroke(path, with: .color(ink), lineWidth: step * 0.07)
                    y += step * 0.7
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func star(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let inner = radius * 0.45
        for index in 0..<10 {
            let angle = (Double(index) * .pi / 5) - .pi / 2
            let length = index % 2 == 0 ? radius : inner
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * length,
                y: center.y + CGFloat(sin(angle)) * length
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct MakeItMineButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 26, weight: .bold))
                    .symbolRenderingMode(.multicolor)
                Text(LookCopy.button)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(RGB.ink.color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .background(.white.opacity(0.9), in: Capsule())
            .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LookCopy.button)
    }
}

struct LookPickerSheet: View {
    @Bindable var model: LauncherModel

    private var look: HomeLook { model.displayedLook }
    private let ink = RGB.ink.color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 40, weight: .bold))
                    .symbolRenderingMode(.multicolor)
                Text(LookCopy.title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Spacer()
                LookPreview(look: look)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(LookCopy.backgroundSection) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 110), spacing: 14)], spacing: 14) {
                            ForEach(LookBackground.allCases, id: \.self) { background in
                                BackgroundSwatch(background: background, selected: look.background == background) {
                                    var next = look
                                    next.background = background
                                    model.previewLook(next)
                                }
                            }
                        }
                    }
                    section(LookCopy.patternSection) {
                        HStack(spacing: 14) {
                            ForEach(LookPattern.allCases, id: \.self) { pattern in
                                PatternSwatch(background: look.background, pattern: pattern, selected: look.pattern == pattern) {
                                    var next = look
                                    next.pattern = pattern
                                    model.previewLook(next)
                                }
                            }
                        }
                    }
                    section(LookCopy.tileSection) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 12)], spacing: 12) {
                            ForEach(LookTileColors.choices, id: \.self) { choice in
                                TileColorSwatch(choice: choice, selected: look.tileColors == choice) {
                                    var next = look
                                    next.tileColors = choice
                                    model.previewLook(next)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 14) {
                Button {
                    model.closeLookPicker(save: false)
                } label: {
                    bigLabel(LookCopy.cancel, filled: false)
                }
                .buttonStyle(.plain)
                Button {
                    model.previewLook(.standard)
                } label: {
                    bigLabel(LookCopy.startOver, filled: false)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    model.closeLookPicker(save: true)
                } label: {
                    bigLabel(LookCopy.done, filled: true)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(maxWidth: 900, maxHeight: 760)
        .background(.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bigLabel(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(filled ? Color.white : ink)
            .padding(.horizontal, 26)
            .frame(minHeight: 56)
            .background(
                filled ? TileAccent.purple.color : Color(red: 0.93, green: 0.94, blue: 0.97),
                in: Capsule()
            )
            .contentShape(Capsule())
    }
}

private struct LookPreview: View {
    var look: HomeLook

    var body: some View {
        ZStack {
            HomeBackground(look: look)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(look.textTone.rgb.color)
                    .frame(width: 70, height: 8)
                HStack(spacing: 6) {
                    ForEach(Array(previewAccents.enumerated()), id: \.offset) { _, accent in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent.color)
                            .frame(width: 30, height: 30)
                    }
                }
            }
        }
        .frame(width: 150, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.12)))
        .accessibilityHidden(true)
    }

    private var previewAccents: [TileAccent] {
        switch look.tileColors {
        case .activityColors: return [.orange, .blue, .teal, .pink]
        case .all(let accent): return [accent, accent, accent, accent]
        }
    }
}

private struct SelectionRing: ViewModifier {
    var selected: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? RGB.ink.color : Color.black.opacity(0.12), lineWidth: selected ? 5 : 1)
            )
    }
}

private struct BackgroundSwatch: View {
    var background: LookBackground
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(background.textTone.rgb.color)
                    }
                }
                .frame(width: 88, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .modifier(SelectionRing(selected: selected))
                Text(background.kidName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RGB.ink.color)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(background.kidName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var colors: [Color] {
        let list = background.colors.map(\.color)
        return list.count == 1 ? [list[0], list[0]] : list
    }
}

private struct PatternSwatch: View {
    var background: LookBackground
    var pattern: LookPattern
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    HomeBackground(look: HomeLook(background: background, pattern: pattern))
                    Image(systemName: pattern.symbolName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(background.textTone.rgb.color)
                }
                .frame(width: 104, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .modifier(SelectionRing(selected: selected))
                Text(pattern.kidName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RGB.ink.color)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pattern.kidName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct TileColorSwatch: View {
    var choice: LookTileColors
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                face
                    .frame(width: 76, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .modifier(SelectionRing(selected: selected))
                Text(choice.kidName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(RGB.ink.color)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.kidName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var face: some View {
        switch choice {
        case .activityColors:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    TileAccent.orange.color
                    TileAccent.blue.color
                }
                HStack(spacing: 0) {
                    TileAccent.teal.color
                    TileAccent.pink.color
                }
            }
        case .all(let accent):
            ZStack {
                accent.color
                Text("Aa")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(accent.usesDarkText ? Color(red: 0.22, green: 0.16, blue: 0.05) : Color.white)
            }
        }
    }
}
#endif
