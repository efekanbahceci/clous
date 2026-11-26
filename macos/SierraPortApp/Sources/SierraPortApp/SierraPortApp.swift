import SwiftUI
import AppKit

@main
struct SierraPortDesktopApp: App {
    @StateObject private var vm = SierraPortViewModel()
    @StateObject private var hotkeyManager = GlobalHotkeyManager.shared
    @StateObject private var updateManager = UpdateManager.shared
    @StateObject private var locale = AppLocale.shared
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
        WindowGroup("Clous") {
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
                        updateManager: updateManager,
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
            .ignoresSafeArea()
            .font(SierraFont.ui(13))
            .tint(SierraTheme.accent)
            .environmentObject(locale)
            .background(WindowThemeSync(preference: themePref))
            .preferredColorScheme(themePref.colorScheme)
            .onAppear {
                QuickLauncherController.shared.configure(vm: vm) {
                    (AppThemePreference(rawValue: UserDefaults.standard.string(forKey: "sierraport_theme") ?? "") ?? .dark).colorScheme
                }
                GlobalHotkeyManager.shared.onTrigger = {
                    QuickLauncherController.shared.toggle()
                }
                updateManager.startPeriodicChecks()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu(locale.t("Navigate", "Gezinme")) {
                Button(locale.t("Terminal Deck", "Terminal Masası")) { vm.selectedTab = .terminal }
                    .keyboardShortcut("1", modifiers: .command)
                Button(locale.t("Live Watch", "Canlı İzleme")) { vm.selectedTab = .watch }
                    .keyboardShortcut("2", modifiers: .command)
                Button(locale.t("Security Audit", "Güvenlik Denetimi")) { vm.selectedTab = .audit }
                    .keyboardShortcut("3", modifiers: .command)
                Button(locale.t("Analytics", "Analitik")) { vm.selectedTab = .stats }
                    .keyboardShortcut("4", modifiers: .command)
                Divider()
                Button(locale.t("Toggle Forensic Inspector", "Adli İnceleyiciyi Aç/Kapat")) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.showingInspector.toggle()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
            CommandMenu(locale.t("Actions", "İşlemler")) {
                Button(locale.t("Open Quick Launcher", "Hızlı Başlatıcıyı Aç")) {
                    QuickLauncherController.shared.toggle()
                }
                Button(locale.t("Refresh Metrics", "Metrikleri Yenile")) {
                    Task {
                        await vm.refreshAudit()
                        await vm.refreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button(locale.t("Configure Global Shortcut…", "Global Kısayolu Ayarla…")) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showingShortcutEditor = true
                    }
                }
                Button(locale.t("Check for Updates…", "Güncellemeleri Denetle…")) {
                    Task {
                        await updateManager.checkForUpdates(userInitiated: true)
                    }
                }
                Divider()
                Menu(locale.t("Language", "Dil")) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            locale.language = lang
                        } label: {
                            Text(locale.language == lang ? "✓ \(lang.displayName)" : lang.displayName)
                        }
                    }
                }
                Divider()
                Button(vm.privilegedControlAuthorized
                       ? locale.t("Revoke Process Control Permission", "Süreç Sonlandırma İznini Geri Al")
                       : locale.t("Process Control Permission: Ask Each Time", "Süreç Sonlandırma İzni: Her Seferinde Sor")) {
                    vm.revokePrivilegedPermission()
                }
                .disabled(!vm.privilegedControlAuthorized)
            }
        }

        MenuBarExtra {
            MenuBarView(vm: vm, hotkeyManager: hotkeyManager)
                .tint(SierraTheme.accent)
                .environmentObject(locale)
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
