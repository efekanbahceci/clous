import SwiftUI
import AppKit

@main
struct SierraPortDesktopApp: App {
    @StateObject private var vm = SierraPortViewModel()
    @AppStorage("sierraport_theme") private var themeRaw: String = AppThemePreference.dark.rawValue

    private var themePref: AppThemePreference {
        AppThemePreference(rawValue: themeRaw) ?? .dark
    }

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("SierraPort") {
            ContentView(vm: vm, themeRaw: $themeRaw)
                .frame(minWidth: 960, minHeight: 620)
                .background(WindowThemeSync(preference: themePref))
                .preferredColorScheme(themePref.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1180, height: 760)

        MenuBarExtra("SierraPort", systemImage: "network") {
            MenuBarView(vm: vm)
                .preferredColorScheme(themePref.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }
}
