import SwiftUI
import AppKit

@main
struct SierraPortDesktopApp: App {
    @StateObject private var vm = SierraPortViewModel()
    @StateObject private var hotkeyManager = GlobalHotkeyManager.shared
    @AppStorage("sierraport_theme") private var themeRaw: String = AppThemePreference.dark.rawValue
    @AppStorage("sierraport_setup_wizard_done_v2") private var onboardingDone: Bool = false
    @State private var showingShortcutEditor: Bool = false

    private var themePref: AppThemePreference {
        AppThemePreference(rawValue: themeRaw) ?? .dark
    }

    init() {
        SierraFont.registerBundledFonts()
        NSApplication.shared.setActivationPolicy(.regular)
        if let appIcon = SierraTheme.loadBundledImage(named: "sierraport-app-icon.png") {
            NSApplication.shared.applicationIconImage = appIcon
        }
    }

    var body: some Scene {
        WindowGroup("SierraPort") {
            ZStack {
                if !onboardingDone || showingShortcutEditor {
                    ShortcutOnboardingView(
                        vm: vm,
                        hotkeyManager: hotkeyManager,
                        themeRaw: $themeRaw,
                        isFirstLaunch: !onboardingDone,
                        onComplete: {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                onboardingDone = true
                                showingShortcutEditor = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    ContentView(
                        vm: vm,
                        hotkeyManager: hotkeyManager,
                        themeRaw: $themeRaw,
                        onEditShortcut: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                showingShortcutEditor = true
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .frame(minWidth: 960, minHeight: 620)
            .font(SierraFont.ui(13))
            .background(WindowThemeSync(preference: themePref))
            .preferredColorScheme(themePref.colorScheme)
            .onAppear {
                QuickLauncherController.shared.configure(vm: vm) {
                    (AppThemePreference(rawValue: UserDefaults.standard.string(forKey: "sierraport_theme") ?? "") ?? .dark).colorScheme
                }
                GlobalHotkeyManager.shared.onTrigger = {
                    QuickLauncherController.shared.toggle()
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1180, height: 760)

        MenuBarExtra {
            MenuBarView(vm: vm, hotkeyManager: hotkeyManager)
                .preferredColorScheme(themePref.colorScheme)
        } label: {
            if let menuImg = SierraTheme.menuBarTemplateImage {
                Image(nsImage: menuImg)
            } else {
                Image(systemName: "network")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
