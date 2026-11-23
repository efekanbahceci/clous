import SwiftUI
import AppKit
import CoreText

enum AppThemePreference: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    case system = "System"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

// MARK: - Raycast Typography System (Bundled SIL-OFL Inter + SF Mono)

enum SierraFont {
    private static var registered = false

    static func registerBundledFonts() {
        guard !registered else { return }
        registered = true

        var fontDirs: [String] = []
        if let resPath = Bundle.main.resourcePath {
            fontDirs.append((resPath as NSString).appendingPathComponent("Fonts"))
        }
        let cwd = FileManager.default.currentDirectoryPath
        fontDirs.append((cwd as NSString).appendingPathComponent("assets/fonts"))
        fontDirs.append(((cwd as NSString).deletingLastPathComponent as NSString).appendingPathComponent("assets/fonts"))

        let fm = FileManager.default
        for dir in fontDirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for file in files where file.hasSuffix(".ttf") || file.hasSuffix(".otf") {
                let url = URL(fileURLWithPath: (dir as NSString).appendingPathComponent(file))
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        registerBundledFonts()
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Inter-Bold"
        case .semibold: name = "Inter-SemiBold"
        case .medium: name = "Inter-Medium"
        default: name = "Inter-Regular"
        }
        if NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .monospaced)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        ui(size, weight: weight)
    }
}

// MARK: - Adaptive Neutral Obsidian Theme (#07080A Dark, #FFFFFF Light, Restrained #EB0020 Accent)

enum SierraTheme {
    private static func dynamic(dark: (CGFloat, CGFloat, CGFloat), light: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0 / 255.0, green: c.1 / 255.0, blue: c.2 / 255.0, alpha: 1.0)
        })
    }

    /// Primary app canvas background: exact #07080A in Dark Mode, pure #FFFFFF in Light Mode.
    static let canvas = dynamic(dark: (0x07, 0x08, 0x0A), light: (0xFF, 0xFF, 0xFF))

    /// Sidebar & Inspector background: neutral #0C0D10 in Dark Mode, crisp #F8F9FA in Light Mode.
    static let sidebar = dynamic(dark: (0x0C, 0x0D, 0x10), light: (0xF8, 0xF9, 0xFA))

    /// Primary card & command block surface: neutral #111317 in Dark Mode, pure #FFFFFF in Light Mode.
    static let surface = dynamic(dark: (0x11, 0x13, 0x17), light: (0xFF, 0xFF, 0xFF))

    /// Elevated nested controls (input box, chips, keycaps): neutral #181A20 in Dark Mode, #F3F4F6 in Light Mode.
    static let surfaceElevated = dynamic(dark: (0x18, 0x1A, 0x20), light: (0xF3, 0xF4, 0xF6))

    /// Code / Raw ANSI output well: deep neutral #050608 in Dark Mode, #F6F7F9 in Light Mode.
    static let codeWell = dynamic(dark: (0x05, 0x06, 0x08), light: (0xF6, 0xF7, 0xF9))

    /// Primary brand accent: exact #EB0020 (--color-500) used sparingly for key interactive focal points.
    static let accent = dynamic(dark: (0xEB, 0x00, 0x20), light: (0xEB, 0x00, 0x20))

    /// High-contrast foreground accent for small inline labels/ports (HIG >= 4.5:1):
    /// #FF5C72 (--color-300) on #07080A dark, #D1001C (--color-600) on #FFFFFF light.
    static let accentBright = dynamic(dark: (0xFF, 0x5C, 0x72), light: (0xD1, 0x00, 0x1C))

    /// Clean neutral selection fill (keeps chrome calm so #EB0020 stays a true accent).
    static let selectionFill = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.09)
            : NSColor.black.withAlphaComponent(0.06)
    })

    /// Neutral adaptive borders.
    static let border = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.09)
            : NSColor.black.withAlphaComponent(0.08)
    })

    static let borderSubtle = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.05)
            : NSColor.black.withAlphaComponent(0.05)
    })

    static let topSpecular = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.13)
            : NSColor.black.withAlphaComponent(0.06)
    })

    static let rowHover = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.06)
            : NSColor.black.withAlphaComponent(0.04)
    })

    // MARK: - Apple Liquid Glass Tokens (Pure Neutral Glass)

    /// Translucent glass surface fill layered over .ultraThinMaterial
    static let glassFill = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0x11 / 255.0, green: 0x13 / 255.0, blue: 0x17 / 255.0, alpha: 0.56)
            : NSColor.white.withAlphaComponent(0.80)
    })

    /// Slightly brighter glass fill for floating inputs, active pills, and elevated cards
    static let glassFillElevated = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.09)
            : NSColor.black.withAlphaComponent(0.055)
    })

    /// Floating sidebar glass tint
    static let sidebarGlassFill = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor(srgbRed: 0x0C / 255.0, green: 0x0D / 255.0, blue: 0x10 / 255.0, alpha: 0.70)
            : NSColor.white.withAlphaComponent(0.86)
    })

    /// Luminous top specular edge for Apple glass borders
    static let glassBorderTop = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.18)
            : NSColor.black.withAlphaComponent(0.10)
    })

    /// Subtle bottom/side glass border
    static let glassBorderBottom = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.07)
            : NSColor.black.withAlphaComponent(0.08)
    })

    /// Adaptive card shadow — deep ambient in Dark Mode, near-zero whisper in Light Mode
    static let cardShadow = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.black.withAlphaComponent(0.28)
            : NSColor.black.withAlphaComponent(0.03)
    })

    static func loadBundledImage(named filename: String) -> NSImage? {
        if let resPath = Bundle.main.resourcePath {
            let bundled = (resPath as NSString).appendingPathComponent(filename)
            if let img = NSImage(contentsOfFile: bundled) {
                return img
            }
        }
        let cwd = FileManager.default.currentDirectoryPath
        let devPaths = [
            (cwd as NSString).appendingPathComponent("assets/\(filename)"),
            ((cwd as NSString).deletingLastPathComponent as NSString).appendingPathComponent("assets/\(filename)")
        ]
        for p in devPaths {
            if let img = NSImage(contentsOfFile: p) {
                return img
            }
        }
        return nil
    }

    static var menuBarTemplateImage: NSImage? {
        guard let src = loadBundledImage(named: "sierraport-mark.png") else { return nil }
        let resized = NSImage(size: NSSize(width: 17, height: 17))
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        src.draw(in: NSRect(x: 0, y: 0, width: 17, height: 17))
        resized.unlockFocus()
        resized.isTemplate = true
        return resized
    }
}

// MARK: - Apple Liquid Glass Card & Keycap Primitives

struct RaycastCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var highlighted: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark
        let highContrast = colorSchemeContrast == .increased

        content
            .background {
                if reduceTransparency {
                    shape.fill(SierraTheme.surface)
                } else {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(SierraTheme.glassFill)
                    }
                }
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: highlighted
                            ? [SierraTheme.accent.opacity(0.9), SierraTheme.accent.opacity(0.4)]
                            : (highContrast
                                ? [Color.primary.opacity(0.35), Color.primary.opacity(0.22)]
                                : [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: highlighted ? 1.35 : (highContrast ? 1.25 : 1)
                )
            )
            .shadow(color: SierraTheme.cardShadow, radius: isDark ? 12 : 3, y: isDark ? 5 : 1)
    }
}

extension View {
    func raycastCard(cornerRadius: CGFloat = 16, highlighted: Bool = false) -> some View {
        modifier(RaycastCardModifier(cornerRadius: cornerRadius, highlighted: highlighted))
    }
}

// MARK: - Ambient Restrained Crimson Backdrop (Subtle Glow over #07080A Dark / #FFFFFF Light)

struct TerminalAmbientBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        ZStack {
            // Exact #07080A in Dark Mode, pure #FFFFFF in Light Mode
            (isDark
                ? Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255)
                : Color.white)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let diag = max(w, h)

                ZStack {
                    if isDark {
                        // Subtle, restrained crimson whisper behind the lower-center deck
                        RadialGradient(
                            stops: [
                                .init(color: Color(red: 0xEB/255, green: 0x00/255, blue: 0x20/255).opacity(0.13), location: 0.0),
                                .init(color: Color(red: 0x75/255, green: 0x00/255, blue: 0x10/255).opacity(0.10), location: 0.38),
                                .init(color: Color(red: 0x47/255, green: 0x00/255, blue: 0x0A/255).opacity(0.05), location: 0.68),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.52, y: 0.74),
                            startRadius: 10,
                            endRadius: diag * 0.56
                        )

                        // Soft neutral graphite depth lift behind the center prompt
                        RadialGradient(
                            stops: [
                                .init(color: Color(red: 0xA3/255, green: 0x00/255, blue: 0x16/255).opacity(0.07), location: 0.0),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.44, y: 0.50),
                            startRadius: 10,
                            endRadius: diag * 0.40
                        )
                    } else {
                        // Light Mode: Pure crisp white with ultra-delicate blush whisper
                        RadialGradient(
                            stops: [
                                .init(color: Color(red: 0xFF/255, green: 0xE6/255, blue: 0xE9/255).opacity(0.38), location: 0.0),
                                .init(color: Color(red: 0xFF/255, green: 0xB8/255, blue: 0xC1/255).opacity(0.10), location: 0.45),
                                .init(color: .clear, location: 1.0)
                            ],
                            center: UnitPoint(x: 0.52, y: 0.74),
                            startRadius: 10,
                            endRadius: diag * 0.55
                        )
                    }
                }
            }
        }
    }
}

struct RaycastKeycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(SierraFont.mono(10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(SierraTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .strokeBorder(SierraTheme.border, lineWidth: 1)
            )
    }
}

struct SierraAppIconView: View {
    var size: CGFloat = 64

    var body: some View {
        if let nsImg = SierraTheme.loadBundledImage(named: "sierraport-app-icon.png") {
            Image(nsImage: nsImg)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(SierraTheme.accent)
                .frame(width: size, height: size)
        }
    }
}

/// Pure transparent monochrome mascot mark (no blue box — crisp white in Dark Mode, pure black in Light Mode).
struct SierraMascotMarkView: View {
    var size: CGFloat = 64
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        if let nsImg = SierraTheme.loadBundledImage(named: "sierraport-mark.png") {
            Image(nsImage: nsImg)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: size * 0.5))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }
}

/// Keeps the underlying NSWindow chrome seamlessly matched to #111110 (Dark) or #F6F6F4 (Light)
/// and hides the cramped 28pt system traffic lights so our custom Gemini-aligned MacTrafficLightsView
/// sits cleanly inside the floating glass sidebar without ever overlapping borders.
struct WindowThemeSync: NSViewRepresentable {
    let preference: AppThemePreference

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            apply(to: nsView.window)
        }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        switch preference {
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .system:
            window.appearance = nil
        }

        window.isOpaque = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        // Keep false so clicks on translucent SwiftUI buttons are never swallowed by window dragging
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0x07 / 255.0, green: 0x08 / 255.0, blue: 0x0A / 255.0, alpha: 1.0)
                : NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        }
        window.hasShadow = true

        // Hide default cramped 28pt titlebar buttons so MacTrafficLightsView renders cleanly in-layout
        let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for type in types {
            window.standardWindowButton(type)?.isHidden = true
        }
    }
}

// MARK: - Native-Feel macOS Traffic Lights (Gemini-Aligned, Group Hover Glyphs)

struct MacTrafficLightsView: View {
    @State private var isGroupHovered: Bool = false

    var body: some View {
        HStack(spacing: 8.5) {
            trafficDot(
                color: Color(red: 0xFF/255, green: 0x5F/255, blue: 0x57/255),
                stroke: Color(red: 0xE0/255, green: 0x44/255, blue: 0x3E/255),
                symbol: "xmark",
                help: "Close Window"
            ) {
                NSApp.keyWindow?.performClose(nil)
            }

            trafficDot(
                color: Color(red: 0xFE/255, green: 0xBC/255, blue: 0x2E/255),
                stroke: Color(red: 0xD8/255, green: 0x9E/255, blue: 0x24/255),
                symbol: "minus",
                help: "Minimize Window"
            ) {
                NSApp.keyWindow?.miniaturize(nil)
            }

            trafficDot(
                color: Color(red: 0x28/255, green: 0xC8/255, blue: 0x40/255),
                stroke: Color(red: 0x1A/255, green: 0xA8/255, blue: 0x2E/255),
                symbol: "plus",
                help: "Toggle Full Screen"
            ) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 2)
        .fixedSize()
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isGroupHovered = hovering
            }
        }
    }

    private func trafficDot(color: Color, stroke: Color, symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(stroke.opacity(0.65), lineWidth: 0.65))
                if isGroupHovered {
                    Image(systemName: symbol)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.68))
                }
            }
            .frame(width: 18, height: 18) // generous 18×18 hit target around 14×14 visual dot
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Window Drag Handle (Allows Dragging Window From Empty Top Bar Space)

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragHostView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragHostView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

// MARK: - Tactile Interactive Button Style (Hover Highlight + Subtle Press Scale)

struct TactileGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        TactileGlassButtonBody(configuration: configuration, cornerRadius: cornerRadius)
    }

    private struct TactileGlassButtonBody: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        @State private var isHovered: Bool = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .background(
                    isHovered ? SierraTheme.rowHover : Color.clear,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .scaleEffect((configuration.isPressed && !reduceMotion) ? 0.98 : 1.0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: configuration.isPressed)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}
