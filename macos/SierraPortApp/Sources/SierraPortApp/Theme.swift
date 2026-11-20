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

// MARK: - Raycast-Inspired Adaptive Theme (#111110 Dark & #F6F6F4 Light)

enum SierraTheme {
    private static func dynamic(dark: (CGFloat, CGFloat, CGFloat), light: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(srgbRed: c.0 / 255.0, green: c.1 / 255.0, blue: c.2 / 255.0, alpha: 1.0)
        })
    }

    /// Primary app canvas background: exact #111110 in Dark Mode, warm Apple porcelain #F6F6F4 in Light Mode.
    static let canvas = dynamic(dark: (0x11, 0x11, 0x10), light: (0xF6, 0xF6, 0xF4))

    /// Sidebar & Inspector background: #141413 in Dark Mode, #EFEFED in Light Mode.
    static let sidebar = dynamic(dark: (0x14, 0x14, 0x13), light: (0xEF, 0xEF, 0xED))

    /// Primary Raycast card & command block surface: #191917 in Dark Mode, #FFFFFF in Light Mode.
    static let surface = dynamic(dark: (0x19, 0x19, 0x17), light: (0xFF, 0xFF, 0xFF))

    /// Elevated nested controls (input box, chips, keycaps): #222220 in Dark Mode, #F0F0EE in Light Mode.
    static let surfaceElevated = dynamic(dark: (0x22, 0x22, 0x20), light: (0xF0, 0xF0, 0xEE))

    /// Code / Raw ANSI output well: #0C0C0B in Dark Mode, #F3F3F1 in Light Mode.
    static let codeWell = dynamic(dark: (0x0C, 0x0C, 0x0B), light: (0xF3, 0xF3, 0xF1))

    /// Brand accent harmonized with #082452 ocean sapphire app icon.
    static let accent = dynamic(dark: (0x4F, 0x8F, 0xFF), light: (0x0B, 0x3D, 0x91))

    /// Raycast signature subtle selection fill.
    static let selectionFill = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.085)
            : NSColor.black.withAlphaComponent(0.06)
    })

    /// Subtle adaptive borders.
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
            ? NSColor.white.withAlphaComponent(0.05)
            : NSColor.black.withAlphaComponent(0.04)
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

// MARK: - Raycast Card & Keycap Primitives

struct RaycastCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 13
    var highlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [SierraTheme.surface, SierraTheme.surface.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: highlighted
                                ? [SierraTheme.accent.opacity(0.75), SierraTheme.accent.opacity(0.35)]
                                : [SierraTheme.topSpecular, SierraTheme.borderSubtle],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: highlighted ? 1.25 : 1
                    )
            )
    }
}

extension View {
    func raycastCard(cornerRadius: CGFloat = 13, highlighted: Bool = false) -> some View {
        modifier(RaycastCardModifier(cornerRadius: cornerRadius, highlighted: highlighted))
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

/// Pure transparent monochrome mascot mark (no blue box — crisp white in Dark Mode, obsidian in Light Mode).
struct SierraMascotMarkView: View {
    var size: CGFloat = 64

    var body: some View {
        if let nsImg = SierraTheme.loadBundledImage(named: "sierraport-mark.png") {
            Image(nsImage: nsImg)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
        }
    }
}

/// Keeps the underlying NSWindow chrome seamlessly matched to #111110 (Dark) or #F6F6F4 (Light).
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
        window.backgroundColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x10 / 255.0, alpha: 1.0)
                : NSColor(srgbRed: 0xF6 / 255.0, green: 0xF6 / 255.0, blue: 0xF4 / 255.0, alpha: 1.0)
        }
    }
}
