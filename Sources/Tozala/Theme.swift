import AppKit
import SwiftUI

/// Ertaga kech design system tokens (green brand). Every color adapts to the window's light/dark appearance.
enum Theme {
    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
    private static func dyn(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }

    static let accent = Color(rgb(58, 215, 84))                                         // #3AD754
    static let accentHover = dyn(rgb(44, 178, 68), rgb(90, 224, 113))
    static let accentPress = dyn(rgb(34, 150, 56), rgb(44, 178, 68))
    static let accentSoft = accent.opacity(0.15)
    static let accentInk = dyn(rgb(34, 150, 56), rgb(58, 215, 84))                   // green for icons/text: darker on light for contrast
    static let onAccent = Color.black                                                   // black ink on bright green
    static let bg = dyn(rgb(249, 249, 249), rgb(0, 0, 0))
    static let surface = dyn(rgb(255, 255, 255), rgb(17, 17, 17))
    static let surfaceRaised = dyn(rgb(255, 255, 255), rgb(26, 26, 26))
    static let sunken = dyn(rgb(0, 0, 0, 0.05), rgb(17, 17, 17))                        // track behind segmented tabs
    static let border = dyn(rgb(222, 222, 222), rgb(33, 33, 33))
    static let divider = dyn(rgb(0, 0, 0, 0.08), rgb(255, 255, 255, 0.08))
    static let dash = dyn(rgb(0, 0, 0, 0.18), rgb(255, 255, 255, 0.14))
    static let text = dyn(rgb(0, 0, 0), rgb(255, 255, 255))
    static let text2 = dyn(rgb(0, 0, 0, 0.6), rgb(255, 255, 255, 0.6))
    static let text3 = dyn(rgb(0, 0, 0, 0.5), rgb(255, 255, 255, 0.5))
    static let meta = dyn(rgb(115, 115, 115), rgb(140, 140, 140))
    static let disabled = dyn(rgb(0, 0, 0, 0.08), rgb(255, 255, 255, 0.08))
    static let danger = dyn(rgb(220, 38, 38), rgb(239, 68, 68))
    static let success = dyn(rgb(22, 163, 74), rgb(34, 197, 94))
    static let wave = LinearGradient(colors: [Color(rgb(44, 178, 68)), accent], startPoint: .leading, endPoint: .trailing)
    static let windowBackground = NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .black : rgb(249, 249, 249) }

    /// Light by default; dark is the user's opt-in, remembered across launches.
    static let darkModeKey = "darkMode"
    static func applyAppearance(dark: Bool = UserDefaults.standard.bool(forKey: darkModeKey)) {
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    }

    enum Weight: String { case regular = "Regular", medium = "Medium", semibold = "SemiBold", bold = "Bold" }
    static func font(_ size: CGFloat, _ weight: Weight = .regular) -> Font { .custom("BricolageGrotesque-\(weight.rawValue)", size: size) }
    static func mono(_ size: CGFloat) -> Font { .custom("GeistMono-Medium", size: size) }
    static let overline = Font.system(size: 11, weight: .medium)

    /// Registers the bundled Bricolage Grotesque / Geist Mono fonts for this process.
    static func registerFonts(in dir: URL? = Bundle.main.resourceURL?.appendingPathComponent("Fonts")) {
        guard let dir, let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "ttf" { CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil) }
    }
}

/// `.glow-accent`: the page lit by soft green light from the top-right and bottom-left.
struct BrandBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let k = scheme == .dark ? 1.0 : 0.6
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.24 * k), .clear], center: UnitPoint(x: 0.85, y: 0), startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Theme.accent.opacity(0.12 * k), .clear], center: UnitPoint(x: 0, y: 1), startRadius: 0, endRadius: 260)
        }
        .ignoresSafeArea()
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(14, .medium))
            .foregroundStyle(enabled ? Theme.onAccent : Theme.text3)
            .padding(.horizontal, 18).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(!enabled ? Theme.disabled : configuration.isPressed ? Theme.accentPress : hover ? Theme.accentHover : Theme.accent))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: hover)
            .onHover { hover = $0 }
    }
}

struct SecondaryButton: ButtonStyle {
    @State private var hover = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.font(14, .medium))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hover ? Theme.surfaceRaised : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: hover)
            .onHover { hover = $0 }
    }
}

/// Card surface: #111, 16px radius, hairline border, 1px top highlight.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.border))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.08), .clear], startPoint: .top, endPoint: .center))
            }
    }
}

extension View {
    func card(radius: CGFloat = 16) -> some View { modifier(CardBackground(radius: radius)) }
    func overline() -> some View { font(Theme.overline).tracking(0.44).textCase(.uppercase).foregroundStyle(Theme.meta) }
}

/// Segmented control in the design system's tab style.
struct Segmented<T: Hashable>: View {
    let options: [(String, T)]
    @Binding var selection: T
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.1) { title, value in
                Text(title)
                    .font(Theme.font(13, .medium))
                    .foregroundStyle(selection == value ? Theme.text : Theme.text2)
                    .frame(maxWidth: .infinity).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selection == value ? Theme.surfaceRaised : .clear)
                        .shadow(color: .black.opacity(selection == value ? 0.18 : 0), radius: 2, y: 1))
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { selection = value } }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.sunken))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border))
    }
}

/// Password input: #111 fill, hairline border, 1.5px green ring on focus.
struct BrandSecureField: View {
    let placeholder: String
    @Binding var text: String
    var error = false
    var autofocus = false
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool
    var body: some View {
        SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.text3))
            .textFieldStyle(.plain)
            .font(Theme.font(14))
            .foregroundStyle(Theme.text)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, 12).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(error ? Theme.danger : focused ? Theme.accent : Theme.border, lineWidth: focused ? 1.5 : 1))
            .onAppear { if autofocus { focused = true } }
    }
}
