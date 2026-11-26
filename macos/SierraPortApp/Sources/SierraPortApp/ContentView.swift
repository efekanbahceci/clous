import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: SierraPortViewModel
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject private var locale = AppLocale.shared
    @ObservedObject private var portGuard = PortGuardManager.shared
    @Binding var themeRaw: String
    let onEditShortcut: () -> Void
    @FocusState private var isCommandFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSidebarVisible: Bool = true

    private var blockExpandAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.14)
            : .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.62)
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var themePref: AppThemePreference {
        AppThemePreference(rawValue: themeRaw) ?? .dark
    }

    private var showEmptyTerminalBackdrop: Bool {
        vm.selectedTab == .terminal && vm.blocks.isEmpty
    }

    var body: some View {
        ZStack {
            // Classic solid canvas (#111110 Dark / #F6F6F4 Light) for Live Watch, Audit, Analytics & Active Deck
            SierraTheme.canvas
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Floating Apple Liquid Glass Sidebar (collapsible via top-right icon or ⌘\)
                if isSidebarVisible {
                    floatingGlassSidebar
                        .padding(.top, 8)
                        .padding(.leading, 8)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                // Right Main Detail Stage
                ZStack {
                    // Deep Sapphire Ambient Gradient ONLY on empty Terminal Deck (before any command is run)
                    if showEmptyTerminalBackdrop {
                        TerminalAmbientBackdrop()
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }

                    VStack(spacing: 0) {
                        // Top-Right Floating Glass Status & Action Pills (aligned with fixed traffic lights at y: 18)
                        topFloatingToolbar
                            .padding(.horizontal, 16)
                            .padding(.top, 15)
                            .padding(.bottom, 6)

                        ZStack(alignment: .bottom) {
                            mainDetail
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if let msg = vm.statusMessage {
                                Text(msg)
                                    .font(SierraFont.ui(12, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .background(SierraTheme.glassFillElevated, in: Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(
                                            LinearGradient(
                                                colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1
                                        )
                                    )
                                    .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
                                    .padding(.bottom, 14)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }

                        // Frosted Glass Bottom Action Bar
                        raycastFooterBar
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: showEmptyTerminalBackdrop)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.statusMessage)
                .inspector(isPresented: $vm.showingInspector) {
                    inspectorDrawer
                        .inspectorColumnWidth(min: 320, ideal: 360, max: 440)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .animation(.spring(response: 0.34, dampingFraction: 0.88), value: isSidebarVisible)
        }
        // Single persistent Traffic Lights (+ collapsed Show Sidebar button on the exact same row)
        // pinned at fixed height 26 & top 12 so the 14pt circles ALWAYS sit at y = 18 (center y = 25)
        // and NEVER shift by even 1 pixel when opening or closing the sidebar.
        .overlay(alignment: .topLeading) {
            HStack(alignment: .center, spacing: 12) {
                MacTrafficLightsView()

                if !isSidebarVisible {
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                            isSidebarVisible = true
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.85))
                            .frame(width: 30, height: 26)
                    }
                    .buttonStyle(TactileGlassButtonStyle(cornerRadius: 13))
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(SierraTheme.glassFill, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    )
                    .help("Show Sidebar (⌘\\)")
                    .accessibilityLabel("Show Sidebar")
                    .transition(.opacity)
                }
            }
            .frame(height: 26)
            .padding(.leading, 20)
            .padding(.top, 12)
            .ignoresSafeArea(.container, edges: .top)
            .animation(.spring(response: 0.30, dampingFraction: 0.86), value: isSidebarVisible)
        }
        .onAppear {
            isCommandFocused = true
        }
        .sheet(item: $vm.pendingPrivilegedAction) { req in
            PrivilegedActionApprovalSheet(
                request: req,
                onApprove: { remember in
                    vm.approvePendingPrivilegedAction(rememberPermission: remember)
                },
                onCancel: {
                    vm.cancelPendingPrivilegedAction()
                }
            )
        }
        .background {
            // Hidden global keyboard shortcuts for mouse-free tab switching (⌘1–⌘4, ⌘K, ⌘R, ⌥⌘I, ⌘\)
            Group {
                Button("") { vm.selectedTab = .terminal; isCommandFocused = true }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { vm.selectedTab = .watch }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { vm.selectedTab = .audit }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { vm.selectedTab = .stats }
                    .keyboardShortcut("4", modifiers: .command)
                Button("") { vm.selectedTab = .terminal; isCommandFocused = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button("") {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        isSidebarVisible.toggle()
                    }
                }
                .keyboardShortcut("\\", modifiers: .command)
                Button("") {
                    Task {
                        await vm.refreshAudit()
                        await vm.refreshStats()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                Button("") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.showingInspector.toggle()
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
        }
    }

    // MARK: - Top-Right Floating Glass Toolbar

    private var topFloatingToolbar: some View {
        HStack(spacing: 10) {
            if !isSidebarVisible {
                // Reserve width for the persistent top-left Traffic Lights + Show Sidebar overlay
                // so WindowDragArea never intercepts clicks on the overlay controls.
                Color.clear
                    .frame(width: 118, height: 26)
                    .allowsHitTesting(false)
            }

            // Empty space acts as a clean window drag handle without compressing left/right pills
            WindowDragArea()
                .frame(minWidth: 20, maxWidth: .infinity, minHeight: 30, maxHeight: 30)
                .layoutPriority(-1)

            restartUpdatePill

            if let tick = vm.latestTick {
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(vm.isStreaming ? Color.green : Color.secondary)
                            .frame(width: 7, height: 7)
                        Text("\(tick.active) \(locale.t("active", "aktif"))")
                            .font(SierraFont.mono(11, weight: .medium))
                            .contentTransition(.numericText())
                    }
                    if tick.exposed > 0 {
                        Text("\(tick.exposed) \(locale.t("exposed", "dışa açık"))")
                            .font(SierraFont.mono(11, weight: .medium))
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                    }
                    Text("\(tick.scanMs)ms")
                        .font(SierraFont.mono(11))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(.ultraThinMaterial, in: Capsule())
                .background(SierraTheme.glassFill, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                )
            }

            HStack(spacing: 2) {
                toolbarGlassIconButton(
                    icon: portGuard.isEnabled ? "bell.badge.fill" : "bell",
                    active: portGuard.isEnabled,
                    help: portGuard.isEnabled
                        ? locale.t("Port Guard Active (click to pause)", "Port Bekçisi Aktif (durdurmak için tıklayın)")
                        : locale.t("Enable Port Guard Alerts", "Port Bekçisi Bildirimlerini Aç")
                ) {
                    portGuard.isEnabled.toggle()
                }
                toolbarGlassIconButton(icon: "terminal", help: locale.t("Focus Command Bar (⌘K)", "Komut Çubuğuna Odaklan (⌘K)")) {
                    isCommandFocused = true
                    vm.selectedTab = .terminal
                }
                toolbarGlassIconButton(icon: "arrow.clockwise", help: "Refresh Metrics (⌘R)") {
                    Task {
                        await vm.refreshAudit()
                        await vm.refreshStats()
                    }
                }
                toolbarGlassIconButton(
                    icon: "sidebar.right",
                    active: vm.showingInspector,
                    help: "Toggle Forensic Inspector (⌥⌘I)"
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.showingInspector.toggle()
                    }
                }
            }
            .padding(3)
            .background(.ultraThinMaterial, in: Capsule())
            .background(SierraTheme.glassFill, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
        }
    }

    private func toolbarGlassIconButton(icon: String, active: Bool = false, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(active ? SierraTheme.accent : .primary.opacity(0.85))
                .frame(width: 32, height: 26)
                .background(active ? SierraTheme.selectionFill : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(TactileGlassButtonStyle(cornerRadius: 13))
        .help(help)
        .accessibilityLabel(help)
    }

    @ViewBuilder
    private var restartUpdatePill: some View {
        switch updateManager.installState {
        case .downloading, .verifying, .installing:
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.75)
                Text(updateStatusLabel)
                    .font(SierraFont.ui(11, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .background(SierraTheme.glassFill, in: Capsule())
            .overlay(Capsule().strokeBorder(SierraTheme.accent.opacity(0.55), lineWidth: 1))
            .transition(.opacity.combined(with: .scale(scale: 0.94)))

        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
                Text(locale.t("Up to date (v\(updateManager.currentVersion))", "Güncel (v\(updateManager.currentVersion))"))
                    .font(SierraFont.ui(11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.ultraThinMaterial, in: Capsule())
            .background(SierraTheme.glassFill, in: Capsule())
            .overlay(Capsule().strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))
            .transition(.opacity)

        case .failed(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(SierraFont.ui(10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .frame(maxWidth: 260)
            .background(.ultraThinMaterial, in: Capsule())
            .background(SierraTheme.glassFill, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
            .transition(.opacity)

        default:
            if let update = updateManager.availableUpdate {
                Button {
                    updateManager.restartAndUpdate()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                        Text("Restart Update")
                            .font(SierraFont.ui(11.5, weight: .semibold))
                        Text("v\(update.version)")
                            .font(SierraFont.mono(10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.22), in: Capsule())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(SierraTheme.accent, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: SierraTheme.accent.opacity(0.32), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .help("Download \(update.tagName) from GitHub Releases and restart automatically")
                .accessibilityLabel("Restart Update to version \(update.version)")
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private var updateStatusLabel: String {
        switch updateManager.installState {
        case .downloading: return locale.t("Downloading update…", "Güncelleme indiriliyor…")
        case .verifying: return locale.t("Verifying SHA-256…", "SHA-256 doğrulanıyor…")
        case .installing: return locale.t("Restarting…", "Yeniden başlatılıyor…")
        default: return locale.t("Updating…", "Güncelleniyor…")
        }
    }

    // MARK: - Frosted Glass Bottom Action Bar

    private var raycastFooterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                SierraAppIconView(size: 16)
                Text(vm.selectedTab.localizedTitle)
                    .font(SierraFont.ui(11.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Text(vm.focusedResultIndex != nil ? locale.t("Inspect", "İncele") : locale.t("Run", "Çalıştır"))
                        .font(SierraFont.ui(11, weight: .medium))
                        .foregroundStyle(.secondary)
                    RaycastKeycap(key: "⏎")
                }

                HStack(spacing: 5) {
                    Text(locale.t("Navigate", "Gezin"))
                        .font(SierraFont.ui(11, weight: .medium))
                        .foregroundStyle(.secondary)
                    RaycastKeycap(key: "Tab")
                }

                HStack(spacing: 5) {
                    Text(locale.t("Inspector", "İnceleyici"))
                        .font(SierraFont.ui(11, weight: .medium))
                        .foregroundStyle(.secondary)
                    RaycastKeycap(key: "⌥⌘I")
                }

                if let hk = hotkeyManager.currentHotkey {
                    Button {
                        QuickLauncherController.shared.toggle()
                    } label: {
                        HStack(spacing: 5) {
                            Text(locale.t("Quick Launch", "Hızlı Başlat"))
                                .font(SierraFont.ui(11, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                ForEach(hk.keycaps, id: \.self) { cap in
                                    RaycastKeycap(key: cap)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(SierraTheme.glassFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Floating Apple Liquid Glass Sidebar

    private var floatingGlassSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gemini-style Top Row: Reserved space for fixed Traffic Lights + Search & Collapse Sidebar on Right
            HStack(spacing: 4) {
                Color.clear
                    .frame(width: 74, height: 24)
                    .allowsHitTesting(false)

                WindowDragArea()
                    .frame(minWidth: 12, maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                    .layoutPriority(-1)

                Button {
                    vm.selectedTab = .terminal
                    isCommandFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(TactileGlassButtonStyle(cornerRadius: 8))
                .help("Focus Command Deck (⌘K)")
                .accessibilityLabel("Focus Command Deck")

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        isSidebarVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(TactileGlassButtonStyle(cornerRadius: 8))
                .help("Hide Sidebar (⌘\\)")
                .accessibilityLabel("Hide Sidebar")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)

            // Minimalist Monochrome Mascot Mark (White in Dark Mode, Black in Light Mode)
            HStack {
                SierraMascotMarkView(size: 32)
                    .accessibilityLabel("Clous")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Uniform Capsule Navigation Items (Gemini-style translucent active pill + generous 38pt hit height)
            VStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in
                    let isSelected = vm.selectedTab == tab
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            vm.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13.5, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .frame(width: 18)
                            Text(tab.localizedTitle)
                                .font(SierraFont.ui(13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.84))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            isSelected ? SierraTheme.glassFillElevated : Color.clear,
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? SierraTheme.glassBorderTop : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(TactileGlassButtonStyle(cornerRadius: 19))
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Divider()
                .opacity(0.28)
                .padding(.horizontal, 12)

            // Uniform Glass Bottom Controls (Quick Launch + Theme Switcher + Core Status)
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    onEditShortcut()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "command")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SierraTheme.accent)
                        Text(locale.t("Quick Launch", "Hızlı Başlat"))
                            .font(SierraFont.ui(11.5, weight: .medium))
                        Spacer()
                        Text(hotkeyManager.currentHotkey?.displayString ?? locale.t("Set", "Ayarla"))
                            .font(SierraFont.mono(10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SierraTheme.glassFillElevated, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))
                            .foregroundStyle(hotkeyManager.isRegistered ? .primary : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(SierraTheme.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(TactileGlassButtonStyle(cornerRadius: 12))
                .help(locale.t("Customize system-wide Quick Launcher hotkey", "Sistem geneli Hızlı Başlatıcı kısayolunu özelleştir"))

                // Language Switcher (English / Türkçe)
                HStack(spacing: 3) {
                    ForEach(AppLanguage.allCases) { lang in
                        let isSelected = locale.language == lang
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                locale.language = lang
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.system(size: 9))
                                Text(lang.displayName)
                                    .font(SierraFont.ui(10.5, weight: isSelected ? .semibold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(
                                isSelected ? SierraTheme.glassFillElevated : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? SierraTheme.glassBorderTop : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(TactileGlassButtonStyle(cornerRadius: 8))
                    }
                }
                .padding(3)
                .frame(height: 34)
                .background(SierraTheme.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))

                HStack(spacing: 3) {
                    ForEach(AppThemePreference.allCases) { pref in
                        let isSelected = themePref == pref
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                themeRaw = pref.rawValue
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: pref.icon)
                                    .font(.system(size: 9))
                                Text(pref.localizedLabel)
                                    .font(SierraFont.ui(10, weight: isSelected ? .semibold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(
                                isSelected ? SierraTheme.glassFillElevated : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? SierraTheme.glassBorderTop : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(TactileGlassButtonStyle(cornerRadius: 8))
                    }
                }
                .padding(3)
                .frame(height: 36)
                .background(SierraTheme.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))

                HStack(spacing: 8) {
                    Circle()
                        .fill(vm.bridge.binaryPath != nil ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(vm.bridge.binaryPath != nil ? "Clous v\(updateManager.currentVersion)" : locale.t("Binary Missing", "Çekirdek Eksik"))
                            .font(SierraFont.ui(11, weight: .medium))
                        Text(vm.isStreaming ? "\(locale.t("Live stream", "Canlı akış")) · \(vm.streamIntervalMs)ms" : locale.t("Stream paused", "Akış duraklatıldı"))
                            .font(SierraFont.mono(10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(SierraTheme.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))
            }
            .padding(12)
        }
        .frame(width: 224)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            if reduceTransparency {
                shape.fill(SierraTheme.sidebar)
            } else {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(SierraTheme.sidebarGlassFill)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: SierraTheme.cardShadow, radius: isDark ? 14 : 3, y: isDark ? 6 : 1)
    }

    // MARK: - Main Detail Switcher

    @ViewBuilder
    private var mainDetail: some View {
        switch vm.selectedTab {
        case .terminal:
            terminalDeckView
        case .watch:
            liveWatchView
        case .audit:
            auditTabView
        case .stats:
            statsTabView
        }
    }

    // MARK: - 1. Ghostty-Inspired Collapsible Terminal Deck

    private var terminalDeckView: some View {
        Group {
            if vm.blocks.isEmpty {
                emptyTerminalHeroView
            } else {
                activeTerminalDeckView
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: vm.blocks.isEmpty)
    }

    private var emptyTerminalHeroView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            // Minimalist Apple-Style Brand Header & Info
            VStack(spacing: 14) {
                SierraMascotMarkView(size: 72)
                    .shadow(color: isDark ? .black.opacity(0.28) : .clear, radius: 12, y: 5)

                VStack(spacing: 4) {
                    Text("Clous")
                        .font(SierraFont.display(38, weight: .semibold))
                        .tracking(-1.0)
                    Text(locale.t("COMMAND DECK", "KOMUT MASASI"))
                        .font(SierraFont.ui(10.5, weight: .semibold))
                        .tracking(2.2)
                        .foregroundStyle(.secondary)
                }

                Text(locale.t(
                    "Run any Clous CLI command or type a plain sentence to inspect listening ports, audit external exposure, trace process ancestry, or grab live protocol banners.",
                    "Dinleyen portları incelemek, dışa maruziyeti denetlemek, süreç soy ağacını görmek veya canlı protokol başlıklarını okumak için bir Clous CLI komutu ya da düz Türkçe/İngilizce cümle yazın."
                ))
                    .font(SierraFont.ui(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 500)
            }
            .padding(.bottom, 34)

            // Centered, Narrower Command Input Box (Positioned Lower)
            commandInputField
                .frame(maxWidth: 600)

            // Quick Command Chips Below Input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(vm.inputError != nil ? "DID YOU MEAN?" : "QUICK COMMANDS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(vm.inputError != nil ? .orange : .secondary)
                    Spacer()
                    Text("Tab / ↑↓ select · ⏎ run · Esc clear")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 4)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(Array(vm.autocompleteSuggestions.enumerated()), id: \.offset) { idx, suggestion in
                        suggestionChipButton(
                            suggestion,
                            isKeyboardFocused: vm.selectedSuggestionIndex == idx,
                            fullWidth: true
                        )
                    }
                }
            }
            .frame(maxWidth: 600)
            .padding(.top, 16)

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeTerminalDeckView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                commandInputField

                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(vm.autocompleteSuggestions.enumerated()), id: \.offset) { idx, suggestion in
                                suggestionChipButton(
                                    suggestion,
                                    isKeyboardFocused: vm.selectedSuggestionIndex == idx,
                                    fullWidth: false
                                )
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        if vm.activeResultCount > 0 && vm.commandInput.isEmpty && vm.inputError == nil {
                            HStack(spacing: 6) {
                                if vm.focusedResultIndex != nil {
                                    RaycastKeycap(key: "⏎")
                                    Text("Inspect")
                                        .font(SierraFont.ui(10.5, weight: .medium))
                                        .foregroundStyle(SierraTheme.accent)
                                    Text("·")
                                        .foregroundStyle(.secondary.opacity(0.6))
                                    RaycastKeycap(key: "Esc")
                                    Text("Back")
                                        .font(SierraFont.ui(10.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                } else {
                                    RaycastKeycap(key: "Tab")
                                    Text("Browse \(vm.activeResultCount) rows")
                                        .font(SierraFont.ui(10.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(.ultraThinMaterial, in: Capsule())
                            .background(
                                vm.focusedResultIndex != nil ? SierraTheme.selectionFill : SierraTheme.glassFill,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    vm.focusedResultIndex != nil ? SierraTheme.accent.opacity(0.45) : SierraTheme.glassBorderBottom,
                                    lineWidth: 1
                                )
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }

                        HStack(spacing: 2) {
                            Button {
                                withAnimation(blockExpandAnimation) {
                                    vm.expandAllBlocks()
                                }
                            } label: {
                                Image(systemName: "rectangle.expand.vertical")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .frame(width: 30, height: 24)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(TactileGlassButtonStyle(cornerRadius: 12))
                            .help("Expand All Command Blocks")
                            .accessibilityLabel("Expand All Command Blocks")

                            Button {
                                withAnimation(blockExpandAnimation) {
                                    vm.collapseAllBlocks()
                                }
                            } label: {
                                Image(systemName: "rectangle.compress.vertical")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .frame(width: 30, height: 24)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(TactileGlassButtonStyle(cornerRadius: 12))
                            .help("Collapse All Command Blocks")
                            .accessibilityLabel("Collapse All Command Blocks")

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    vm.blocks.removeAll()
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .frame(width: 30, height: 24)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(TactileGlassButtonStyle(cornerRadius: 12))
                            .help("Clear Terminal Deck")
                            .accessibilityLabel("Clear Terminal Deck")
                        }
                        .padding(.horizontal, 4)
                        .frame(height: 30)
                        .background(.ultraThinMaterial, in: Capsule())
                        .background(SierraTheme.glassFill, in: Capsule())
                        .overlay(Capsule().strokeBorder(SierraTheme.glassBorderBottom, lineWidth: 1))
                    }
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.18), value: vm.focusedResultIndex)
                }
            }
            .padding(16)

            Divider().opacity(0.4)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.blocks) { block in
                            commandBlockCard(block)
                                .id(block.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: vm.blocks.first?.id) { _, newId in
                    if let newId {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(newId, anchor: .top)
                        }
                    }
                }
                .onChange(of: vm.focusedResultIndex) { _, rowIdx in
                    if let rowIdx {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("port-row-\(rowIdx)", anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var commandInputField: some View {
        let hasError = vm.inputError != nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("❯")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(hasError ? .red : SierraTheme.accent)

                TextField(
                    locale.t(
                        "Type a command or plain sentence (e.g. 5000, close port 3000, exposed, security scan, free port)...",
                        "Komut veya düz cümle yazın (ör. 5000, 3000 portunu kapat, dışa açık portlar, güvenlik taraması, boş port)..."
                    ),
                    text: $vm.commandInput
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .focused($isCommandFocused)
                    .onChange(of: vm.commandInput) { _, _ in
                        vm.clearInputError()
                    }
                    .onSubmit {
                        vm.submitCommand()
                    }
                    .onKeyPress(keys: [.tab]) { press in
                        withAnimation(.easeOut(duration: 0.12)) {
                            if press.modifiers.contains(.shift) {
                                vm.selectPreviousTarget()
                            } else {
                                vm.selectNextTarget()
                            }
                        }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            vm.handleUpArrow()
                        }
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            vm.handleDownArrow()
                        }
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            vm.handleEscape()
                        }
                        return .handled
                    }

                if vm.isExecuting {
                    ProgressView()
                        .controlSize(.small)
                }

                Button(locale.t("Run", "Çalıştır")) {
                    vm.submitCommand()
                }
                .buttonStyle(.borderedProminent)
                .tint(hasError ? .red : SierraTheme.accent)
                .controlSize(.small)
                .disabled(vm.commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(SierraTheme.glassFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        hasError
                            ? LinearGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                            : (isCommandFocused
                                ? LinearGradient(colors: [SierraTheme.accent.opacity(0.85), SierraTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing)),
                        lineWidth: hasError ? 1.5 : 1.15
                    )
            )
            .shadow(
                color: isCommandFocused
                    ? SierraTheme.accent.opacity(isDark ? 0.16 : 0.08)
                    : SierraTheme.cardShadow,
                radius: isDark ? 14 : 3,
                y: isDark ? 5 : 1
            )
            .modifier(ShakeEffect(animatableData: vm.inputShakeTrigger))

            if let err = vm.inputError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text(err)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(2)
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: hasError)
    }

    private func suggestionChipButton(_ suggestion: String, isKeyboardFocused: Bool, fullWidth: Bool) -> some View {
        let isRunningThis = vm.activeChipCommand == suggestion
        let isHighlighted = isRunningThis || isKeyboardFocused
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                vm.runSuggestion(suggestion)
            }
        } label: {
            HStack(spacing: 6) {
                if isRunningThis {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: isKeyboardFocused ? "return" : "play.fill")
                        .font(.system(size: isKeyboardFocused ? 9 : 8, weight: .bold))
                        .foregroundStyle(isKeyboardFocused ? SierraTheme.accent : .secondary)
                }
                Text(suggestion)
                    .font(.system(size: 11, weight: isHighlighted ? .semibold : .regular, design: .monospaced))
                    .foregroundStyle(isHighlighted ? Color.primary : Color.primary.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if fullWidth {
                    Spacer(minLength: 4)
                }
                if isKeyboardFocused && !isRunningThis {
                    Text("⏎")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(SierraTheme.accentBright)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: fullWidth ? 42 : 30)
            .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: fullWidth ? 12 : 15, style: .continuous))
            .background(
                (isHighlighted ? SierraTheme.selectionFill : SierraTheme.glassFill),
                in: RoundedRectangle(cornerRadius: fullWidth ? 12 : 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: fullWidth ? 12 : 15, style: .continuous)
                    .strokeBorder(
                        isHighlighted
                            ? LinearGradient(colors: [SierraTheme.accent.opacity(0.8), SierraTheme.accent.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isKeyboardFocused ? 1.25 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: fullWidth ? 12 : 15, style: .continuous))
        }
        .buttonStyle(TactileGlassButtonStyle(cornerRadius: fullWidth ? 12 : 15))
    }

    private func commandBlockCard(_ block: CommandBlock) -> some View {
        let isNewlyOpened = vm.highlightedBlockId == block.id
        return VStack(alignment: .leading, spacing: 0) {
            // Clickable Collapsible Header Bar
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isNewlyOpened ? SierraTheme.accent : .secondary)
                    .rotationEffect(.degrees(block.isExpanded ? 90 : 0))
                    .animation(blockExpandAnimation, value: block.isExpanded)
                    .frame(width: 14)

                Text("❯")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(SierraTheme.accent)

                if let origin = block.originalInput {
                    Text(origin)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("→ \(block.command)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(block.command)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Text(block.summaryLabel)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .foregroundStyle(.secondary)
                    .background(SierraTheme.glassFillElevated, in: Capsule())
                    .lineLimit(1)

                if isNewlyOpened {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .foregroundStyle(.green)
                        .background(.green.opacity(0.15), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 8)

                Text("\(block.durationMs)ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(block.timestamp, style: .time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                if block.isExpanded {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            vm.toggleRaw(for: block.id)
                        }
                    } label: {
                        Text(block.showRaw ? "Visual" : "Raw")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Button {
                    Task { await vm.executeCommand(block.command) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Re-run command")

                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        vm.removeBlock(for: block.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Dismiss block")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(blockExpandAnimation) {
                    vm.toggleExpand(for: block.id)
                }
            }

            if block.isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().opacity(0.35)

                    SlowMotionBlockReveal {
                        Group {
                    if block.showRaw {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(block.rawOutput)
                                .font(.system(size: 11.5, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(SierraTheme.codeWell, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SierraTheme.borderSubtle, lineWidth: 1))
                    } else {
                        switch block.payload {
                        case .ports(let entries):
                            PortTableView(
                                entries: entries,
                                tableId: block.id.uuidString,
                                selectedRowKey: vm.selectedRowKey,
                                focusedRowIndex: vm.focusedResultBlockId == block.id ? vm.focusedResultIndex : nil,
                                onInspect: { port, rowKey in vm.inspectPort(port, rowKey: rowKey) },
                                onKill: { vm.killPort($0) }
                            )
                        case .audit(let report):
                            AuditVisualView(report: report, onInspectPort: { vm.inspectPort($0) })
                        case .inspect(let report):
                            InspectVisualView(report: report, onKill: { vm.killPort($0) })
                        case .probe(let results):
                            ProbeResultsVisualView(results: results)
                        case .stats(let stats):
                            StatsVisualView(
                                stats: stats,
                                history: vm.tickHistory,
                                onSelectProcess: { proc in
                                    vm.selectedTab = .terminal
                                    Task { await vm.executeCommand("list --all --proc \(proc)") }
                                }
                            )
                        case .diff(let diff):
                            DiffVisualView(diff: diff)
                        case .freePorts(let free):
                            FreePortsVisualView(result: free)
                        case .projects(let proj):
                            ProjectMapVisualView(
                                report: proj,
                                onInspectPort: { vm.inspectPort($0) },
                                onKillPort: { vm.killPort($0) }
                            )
                        case .doctor(let doc):
                            DoctorVisualView(
                                report: doc,
                                onRunFix: { cmd in
                                    Task { await vm.executeCommand(cmd) }
                                },
                                onInspectPort: { vm.inspectPort($0) }
                            )
                        case .httpHealth(let http):
                            HttpHealthVisualView(report: http)
                        case .history(let records, let port):
                            HistoryTimelineVisualView(records: records, filterPort: port)
                        case .text(let str):
                            Text(str)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                        case .error(let err):
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                    }
                    .padding(14)
                }
                }
                .clipped()
                .transition(.opacity)
            }
        }
        .clipped()
        .raycastCard(cornerRadius: 16, highlighted: isNewlyOpened)
        .animation(blockExpandAnimation, value: block.isExpanded)
        .animation(.easeInOut(duration: 0.25), value: isNewlyOpened)
    }

    // MARK: - 2. Live Watch Dashboard

    private var liveWatchView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    if vm.isStreaming { vm.stopLiveStream() } else { vm.startLiveStream() }
                } label: {
                    Label(vm.isStreaming ? locale.t("Pause", "Duraklat") : locale.t("Resume", "Devam Et"), systemImage: vm.isStreaming ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Picker(locale.t("Interval", "Aralık"), selection: $vm.streamIntervalMs) {
                    Text("500ms").tag(500)
                    Text("1s").tag(1000)
                    Text("2s").tag(2000)
                    Text("5s").tag(5000)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .onChange(of: vm.streamIntervalMs) { _, _ in
                    vm.restartStreamWithSettings(resetHistory: false)
                }

                Toggle(locale.t("All States", "Tüm Durumlar"), isOn: $vm.streamAllStates)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: vm.streamAllStates) { _, _ in
                        vm.restartStreamWithSettings(resetHistory: true)
                    }

                Spacer()

                if let tick = vm.latestTick {
                    Text("Tick #\(tick.tick) · UTC \(tick.timestampUtc)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if let tick = vm.latestTick {
                HStack(spacing: 10) {
                    KpiPill(title: locale.t("Active", "Aktif"), value: "\(tick.active)", tint: .primary, icon: "network")
                    KpiPill(title: "TCP / UDP", value: "\(tick.tcp) / \(tick.udp)", tint: .primary, icon: "arrow.left.arrow.right")
                    KpiPill(title: locale.t("Exposed", "Dışa Açık"), value: "\(tick.exposed)", tint: tick.exposed > 0 ? .orange : .green, icon: "globe")
                    KpiPill(title: locale.t("Opened", "Açılan"), value: "+\(tick.openedTotal)", tint: .green, icon: "plus.circle")
                    KpiPill(title: locale.t("Closed", "Kapanan"), value: "-\(tick.closedTotal)", tint: .red, icon: "minus.circle")
                    KpiPill(title: locale.t("Scan", "Tarama"), value: "\(tick.scanMs)ms", tint: .secondary, icon: "speedometer")
                }
                .padding(.horizontal, 16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    LiveSparklineView(history: vm.tickHistory, height: 95)

                    if let tick = vm.latestTick {
                        PortTableView(
                            entries: tick.entries,
                            tableId: "live-watch",
                            selectedRowKey: vm.selectedRowKey,
                            onInspect: { port, rowKey in vm.inspectPort(port, rowKey: rowKey) },
                            onKill: { vm.killPort($0) }
                        )
                        .padding(14)
                        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SierraTheme.border, lineWidth: 1))
                    } else {
                        ProgressView("Starting live port stream...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }

                    if !vm.recentEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("LIVE EVENT TIMELINE")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Clear") { vm.recentEvents.removeAll() }
                                    .buttonStyle(.borderless)
                                    .font(.system(size: 11))
                            }
                            ForEach(vm.recentEvents.prefix(20)) { ev in
                                HStack(spacing: 10) {
                                    Text(ev.time)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(ev.kind == "OPEN" ? "+ OPEN" : "- CLOSED")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ev.kind == "OPEN" ? .green : .red)
                                        .frame(width: 68, alignment: .leading)
                                    Text("\(ev.protocolName) \(ev.endpoint)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .lineLimit(1)
                                    ScopeBadge(scope: ev.scope)
                                    Spacer()
                                    Text(ev.process)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(14)
                        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SierraTheme.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - 3. Security & Binary Trust Audit Tab

    private var auditTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locale.t("Security & Binary Trust Audit", "Güvenlik ve İkili Güven Denetimi"))
                            .font(.system(size: 18, weight: .semibold))
                        Text(locale.t("macOS firewall posture, code-signature verification, active probing, and remediation playbooks", "macOS güvenlik duvarı durumu, dijital imza doğrulaması, aktif yoklama ve düzeltme önerileri"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Picker(locale.t("Profile", "Profil"), selection: $vm.auditProfile) {
                        ForEach(AuditProfileOption.allCases) { opt in
                            Text(opt.localizedLabel).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .onChange(of: vm.auditProfile) { _, _ in
                        Task { await vm.refreshAudit() }
                    }

                    Toggle(locale.t("Deep Probe", "Derin Tarama"), isOn: $vm.auditDeepScan)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: vm.auditDeepScan) { _, _ in
                            Task { await vm.refreshAudit() }
                        }

                    Button {
                        vm.exportAuditMarkdown()
                    } label: {
                        Label(locale.t("Export MD", "MD Dışa Aktar"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(vm.auditReport == nil)

                    Button {
                        Task { await vm.refreshAudit() }
                    } label: {
                        if vm.isLoadingAudit {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(locale.t("Scan", "Tara"), systemImage: "shield.checkerboard")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if vm.isLoadingAudit && vm.auditReport == nil {
                    ProgressView("Verifying firewall posture & binary signatures...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = vm.auditReport {
                    AuditVisualView(
                        report: report,
                        allowlistedKeys: vm.allowlistedKeys,
                        onInspectPort: { vm.inspectPort($0) },
                        onAllowlist: { vm.allowlistFinding($0) },
                        onRestoreAllowlist: { vm.restoreAllowlistedKey($0) }
                    )
                    .padding(16)
                    .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SierraTheme.border, lineWidth: 1))
                }
            }
            .padding(18)
        }
    }

    // MARK: - 4. Dynamic Analytics Tab

    private var statsTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locale.t("Socket & Exposure Analytics", "Soket ve Maruziyet Analitiği"))
                            .font(.system(size: 18, weight: .semibold))
                        Text(locale.t("Real-time telemetry, bind exposure breakdown, and process activity", "Gerçek zamanlı telemetri, dışa maruziyet dağılımı ve süreç aktivitesi"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Toggle(locale.t("Live Sync", "Canlı Eşitle"), isOn: $vm.liveAnalyticsEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    Button {
                        Task { await vm.refreshStats() }
                    } label: {
                        Label(locale.t("Refresh", "Yenile"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if vm.isLoadingStats && vm.statsReport == nil {
                    ProgressView("Loading analytics...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let stats = vm.statsReport {
                    StatsVisualView(
                        stats: stats,
                        history: vm.tickHistory,
                        onSelectProcess: { proc in
                            vm.selectedTab = .terminal
                            Task { await vm.executeCommand("list --all --proc \(proc)") }
                        }
                    )
                }
            }
            .padding(18)
        }
    }

    // MARK: - Native Right-Side Forensic Inspector

    private var inspectorDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(locale.t("Forensic Inspector", "Adli İnceleyici"), systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        vm.showingInspector = false
                        vm.selectedPort = nil
                        vm.selectedRowKey = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            Divider()

            ScrollView {
                if vm.isInspecting {
                    ProgressView(locale.t("Probing & tracing ancestry...", "Yoklanıyor ve süreç soy ağacı izleniyor..."))
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let report = vm.inspectedReport {
                    InspectVisualView(report: report, onKill: { vm.killPort($0) })
                        .padding(14)
                } else {
                    ContentUnavailableView(
                        locale.t("No Port Selected", "Port Seçilmedi"),
                        systemImage: "sparkle.magnifyingglass",
                        description: Text(locale.t("Click any row in a port table to inspect its process ancestry and live banner.", "Süreç soy ağacını ve canlı protokol başlığını incelemek için tablodan herhangi bir satıra tıklayın."))
                    )
                    .padding(.top, 40)
                }
            }
        }
        .background(SierraTheme.sidebar)
    }
}

// MARK: - Apple-Style Horizontal Shake Effect for Invalid Commands

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit * 2),
                y: 0
            )
        )
    }
}

// MARK: - macOS Menu Bar Quick Monitor

struct MenuBarView: View {
    @ObservedObject var vm: SierraPortViewModel
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject private var locale = AppLocale.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clous")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let tick = vm.latestTick {
                    Text("\(tick.active) \(locale.t("active", "aktif")) · \(tick.exposed) \(locale.t("exposed", "dışa açık"))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if let entries = vm.latestTick?.entries, !entries.isEmpty {
                let uniqueByPort = Dictionary(grouping: entries, by: \.localPort)
                    .compactMap { $0.value.first }
                    .sorted { $0.localPort < $1.localPort }

                ForEach(uniqueByPort.prefix(12)) { e in
                    HStack(spacing: 8) {
                        Text(":\(e.localPort)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 52, alignment: .leading)
                        Text(e.process ?? "-")
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                        ScopeBadge(scope: e.bindScope)
                        if e.pid != nil {
                            Button {
                                vm.killPort(e.localPort)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text(locale.t("No active listeners", "Aktif dinleyen port yok"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button(locale.t("Quick Launcher", "Hızlı Başlatıcı")) {
                    QuickLauncherController.shared.show()
                }
                Spacer()
                Button(locale.t("Open App", "Uygulamayı Aç")) {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button(locale.t("Quit", "Çıkış")) {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12))
        }
        .padding(12)
        .frame(width: 300)
    }
}

// MARK: - Slow-Motion Fluid Reveal for Terminal Deck Command Blocks

private struct SlowMotionBlockReveal<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : -10)
            .scaleEffect(revealed ? 1 : 0.985, anchor: .top)
            .onAppear {
                if reduceMotion {
                    revealed = true
                } else {
                    withAnimation(.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.68).delay(0.06)) {
                        revealed = true
                    }
                }
            }
    }
}

// MARK: - Privileged Command Permission & Approval Sheet (Apple Liquid Glass)

private struct PrivilegedActionApprovalSheet: View {
    let request: PrivilegedActionRequest
    let onApprove: (Bool) -> Void
    let onCancel: () -> Void
    @ObservedObject private var locale = AppLocale.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var rememberPermission: Bool = false
    @State private var keyMonitor: Any? = nil

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(SierraTheme.accent.opacity(isDark ? 0.18 : 0.12))
                        .frame(width: 44, height: 44)
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [SierraTheme.accent.opacity(0.55), SierraTheme.accent.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(SierraTheme.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.title)
                        .font(SierraFont.display(16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(request.detail)
                        .font(SierraFont.ui(12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let target = request.targetSummary {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(target)
                            .font(SierraFont.ui(11.5, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }

                HStack(spacing: 8) {
                    Text("❯")
                        .font(SierraFont.mono(12, weight: .bold))
                        .foregroundStyle(SierraTheme.accent)
                    Text(request.commandPreview)
                        .font(SierraFont.mono(12, weight: .medium))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                    Spacer()
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(SierraTheme.codeWell.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
            }

            Toggle(isOn: $rememberPermission) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locale.t("Remember permission for process termination", "Süreç sonlandırma iznini hatırla"))
                        .font(SierraFont.ui(12, weight: .medium))
                    Text(locale.t(
                        "You can revoke this anytime from Actions → Revoke Process Control Permission.",
                        "Bu izni istediğiniz zaman İşlemler → Süreç Sonlandırma İznini Geri Al menüsünden iptal edebilirsiniz."
                    ))
                        .font(SierraFont.ui(10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Divider().opacity(0.28)

            HStack(spacing: 10) {
                // Apple Liquid Glass Cancel Button (Esc)
                Button {
                    onCancel()
                } label: {
                    HStack(spacing: 7) {
                        Text(locale.t("Cancel", "Vazgeç"))
                            .font(SierraFont.ui(12.5, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.9))
                        Text("Esc")
                            .font(SierraFont.mono(10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(SierraTheme.glassFillElevated, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.ultraThinMaterial, in: Capsule())
                    .background(SierraTheme.glassFill, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [SierraTheme.glassBorderTop, SierraTheme.glassBorderBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    )
                    .contentShape(Capsule())
                }
                .buttonStyle(TactileGlassButtonStyle(cornerRadius: 18))
                .keyboardShortcut(.cancelAction)

                Spacer()

                // Apple Liquid Glass Prominent Crimson Approve Button (⏎)
                Button {
                    onApprove(rememberPermission)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(rememberPermission
                             ? locale.t("Allow Always & Run", "Her Zaman İzin Ver ve Çalıştır")
                             : locale.t("Allow Once", "Bir Kez İzin Ver"))
                            .font(SierraFont.ui(12.5, weight: .semibold))
                        Text("⏎")
                            .font(SierraFont.mono(10.5, weight: .bold))
                            .padding(.horizontal, 5.5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(
                        ZStack {
                            Capsule().fill(SierraTheme.accent)
                            Capsule().fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.18), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.36), Color.white.opacity(0.08)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: SierraTheme.accent.opacity(isDark ? 0.36 : 0.24), radius: 10, y: 3)
                    .contentShape(Capsule())
                }
                .buttonStyle(TactileGlassButtonStyle(cornerRadius: 18))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 472)
        .background {
            if reduceTransparency {
                SierraTheme.canvas
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    SierraTheme.canvas.opacity(isDark ? 0.82 : 0.88)
                }
            }
        }
        .onAppear {
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Return (36) or Numpad Enter (76) -> instant approve
            if event.keyCode == 36 || event.keyCode == 76 {
                DispatchQueue.main.async {
                    onApprove(rememberPermission)
                }
                return nil
            }
            // Escape (53) -> instant cancel
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    onCancel()
                }
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
