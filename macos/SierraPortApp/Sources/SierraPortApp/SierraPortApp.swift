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
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Navigate") {
                Button("Terminal Deck") { vm.selectedTab = .terminal }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Live Watch") { vm.selectedTab = .watch }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Security Audit") { vm.selectedTab = .audit }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Analytics") { vm.selectedTab = .stats }
                    .keyboardShortcut("4", modifiers: .command)
                Divider()
                Button("Toggle Forensic Inspector") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.showingInspector.toggle()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
            CommandMenu("Actions") {
                Button("Open Quick Launcher") {
                    QuickLauncherController.shared.toggle()
                }
                Button("Refresh Metrics") {
                    Task {
                        await vm.refreshAudit()
                        await vm.refreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Configure Global Shortcut…") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showingShortcutEditor = true
                    }
                }
            }
        }

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
