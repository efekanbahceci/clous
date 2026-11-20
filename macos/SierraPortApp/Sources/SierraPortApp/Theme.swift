import SwiftUI
import AppKit

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

    /// Sidebar & Inspector background: #151514 in Dark Mode, #EFEFED in Light Mode.
    static let sidebar = dynamic(dark: (0x15, 0x15, 0x14), light: (0xEF, 0xEF, 0xED))

    /// Primary card & command block surface: #1A1A18 in Dark Mode, pure #FFFFFF in Light Mode.
    static let surface = dynamic(dark: (0x1A, 0x1A, 0x18), light: (0xFF, 0xFF, 0xFF))

    /// Elevated nested controls (input box, chips, nested rows): #222220 in Dark Mode, #F0F0EE in Light Mode.
    static let surfaceElevated = dynamic(dark: (0x22, 0x22, 0x20), light: (0xF0, 0xF0, 0xEE))

    /// Code / Raw ANSI output well: #0C0C0B in Dark Mode, #F3F3F1 in Light Mode.
    static let codeWell = dynamic(dark: (0x0C, 0x0C, 0x0B), light: (0xF3, 0xF3, 0xF1))

    /// Subtle adaptive borders.
    static let border = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.085)
            : NSColor.black.withAlphaComponent(0.08)
    })

    static let borderSubtle = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.05)
            : NSColor.black.withAlphaComponent(0.05)
    })

    static let rowHover = Color(nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark
            ? NSColor.white.withAlphaComponent(0.05)
            : NSColor.black.withAlphaComponent(0.04)
    })
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
