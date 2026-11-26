import SwiftUI
import AppKit

// MARK: - One-Time First-Launch Setup Wizard (Theme -> Security Profile -> Global Shortcut)

struct ShortcutOnboardingView: View {
    @ObservedObject var vm: SierraPortViewModel
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    @ObservedObject private var locale = AppLocale.shared
    @Binding var themeRaw: String
    let isFirstLaunch: Bool
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    enum SetupStep: Int, CaseIterable {
        case theme = 0
        case profile = 1
        case shortcut = 2

        var label: String {
            switch self {
            case .theme: return "Appearance"
            case .profile: return "Security"
            case .shortcut: return "Shortcut"
            }
        }
    }

    @State private var step: SetupStep = .theme
    @State private var isMovingForward: Bool = true
    @State private var selectedConfig: HotkeyConfig = .optionSpace
    @State private var isRecording: Bool = false
    @State private var recorderError: String? = nil
    @State private var recorderShake: CGFloat = 0
    @State private var keyMonitor: Any? = nil
    @State private var returnMonitor: Any? = nil
    @State private var savedPulse: Bool = false

    // Staggered entrance motion
    @State private var appeared: Bool = false

    private var themePref: AppThemePreference {
        AppThemePreference(rawValue: themeRaw) ?? .dark
    }

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var stepTransition: AnyTransition {
        let insertionEdge: Edge = isMovingForward ? .trailing : .leading
        let removalEdge: Edge = isMovingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98)),
            removal: .move(edge: removalEdge)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98))
        )
    }

    var body: some View {
        ZStack {
            // Ultra-smooth Metal-backed slow-motion Thermal Eclipse Gradient
            ThermalEclipseBackground(isDark: isDark)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.45), value: isDark)

            // Top Window Bar (Traffic Lights + Drag Area)
            VStack {
                HStack(spacing: 10) {
                    MacTrafficLightsView()
                    WindowDragArea()
                        .frame(height: 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                Spacer()
            }
            .ignoresSafeArea(.container, edges: .top)

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Brand Mascot Mark (white in Dark Mode, obsidian in Light Mode)
                SierraMascotMarkView(size: 64)
                    .shadow(color: isDark ? .black.opacity(0.35) : Color(red: 0xEB/255, green: 0x00/255, blue: 0x20/255).opacity(0.14), radius: 14, y: 5)
                    .scaleEffect(appeared ? 1.0 : 0.84)
                    .opacity(appeared ? 1.0 : 0.0)
                    .padding(.bottom, 16)

                // Step Progress Pills (only in first-launch wizard)
                if isFirstLaunch {
                    HStack(spacing: 8) {
                        ForEach(SetupStep.allCases, id: \.rawValue) { s in
                            let isActive = s == step
                            let isDone = s.rawValue < step.rawValue
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isActive ? SierraTheme.accent : (isDone ? Color.green : Color.secondary.opacity(0.35)))
                                    .frame(width: 6, height: 6)
                                Text(s.label)
                                    .font(SierraFont.ui(11, weight: isActive ? .semibold : .regular))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                isActive ? Color.primary.opacity(isDark ? 0.11 : 0.08) : Color.clear,
                                in: Capsule()
                            )
                            .onTapGesture {
                                navigate(to: s)
                            }
                        }
                    }
                    .padding(.bottom, 22)
                    .opacity(appeared ? 1.0 : 0.0)
                }

                // Dynamic Step Content
                ZStack {
                    switch step {
                    case .theme:
                        themeStepView
                            .id(SetupStep.theme)
                            .transition(stepTransition)
                    case .profile:
                        profileStepView
                            .id(SetupStep.profile)
                            .transition(stepTransition)
                    case .shortcut:
                        shortcutStepView
                            .id(SetupStep.shortcut)
                            .transition(stepTransition)
                    }
                }
                .offset(y: appeared ? 0 : 14)
                .opacity(appeared ? 1.0 : 0.0)

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 36)
        }
        .onAppear {
            if let existing = hotkeyManager.currentHotkey {
                selectedConfig = existing
            }
            step = isFirstLaunch ? .theme : .shortcut
            withAnimation(.spring(response: 0.48, dampingFraction: 0.88)) {
                appeared = true
            }
            installReturnKeyMonitor()
        }
        .onDisappear {
            stopRecording()
            removeReturnKeyMonitor()
        }
    }

    // MARK: - Step Navigation & Enter Key Handler

    private func navigate(to target: SetupStep) {
        guard target != step else { return }
        stopRecording()
        isMovingForward = target.rawValue > step.rawValue
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            step = target
        }
    }

    private func advanceCurrentStep() {
        guard !isRecording, !savedPulse else { return }
        switch step {
        case .theme:
            navigate(to: .profile)
        case .profile:
            Task { await vm.refreshAudit() }
            navigate(to: .shortcut)
        case .shortcut:
            confirmAndActivate()
        }
    }

    private func installReturnKeyMonitor() {
        removeReturnKeyMonitor()
        returnMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore while custom shortcut recording is active
            if isRecording { return event }
            let significantMods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard significantMods.isEmpty else { return event }
            // 36 = Return, 76 = Numpad Enter
            if event.keyCode == 36 || event.keyCode == 76 {
                DispatchQueue.main.async {
                    advanceCurrentStep()
                }
                return nil
            }
            return event
        }
    }

    private func removeReturnKeyMonitor() {
        if let monitor = returnMonitor {
            NSEvent.removeMonitor(monitor)
            returnMonitor = nil
        }
    }

    // MARK: - Step 1: Appearance / Theme

    private var themeStepView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(locale.t("Welcome to Clous", "Clous'a Hoş Geldiniz"))
                    .font(SierraFont.display(28, weight: .semibold))
                    .tracking(-0.6)
                Text(locale.t("Choose your preferred interface appearance and language. You can switch anytime.", "Tercih ettiğiniz görünümü ve dili seçin. İstediğiniz zaman değiştirebilirsiniz."))
                    .font(SierraFont.ui(13.5))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(AppLanguage.allCases) { lang in
                    let isSelected = locale.language == lang
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            locale.language = lang
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "globe")
                                .font(.system(size: 10.5))
                            Text(lang.displayName)
                                .font(SierraFont.ui(11.5, weight: isSelected ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(isSelected ? SierraTheme.accent : SierraTheme.glassFill, in: Capsule())
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .overlay(Capsule().strokeBorder(isSelected ? Color.clear : SierraTheme.glassBorderBottom, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 14) {
                themeCard(.dark, title: locale.t("Dark", "Koyu"), subtitle: "Obsidian #07080A", previewBg: Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255), previewCard: Color(red: 0x18/255, green: 0x1A/255, blue: 0x20/255), previewText: .white)
                themeCard(.light, title: locale.t("Light", "Açık"), subtitle: locale.t("Pure White #FFFFFF", "Saf Beyaz #FFFFFF"), previewBg: .white, previewCard: Color(red: 0xF3/255, green: 0xF4/255, blue: 0xF6/255), previewText: Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255))
                themeCard(.system, title: locale.t("System", "Sistem"), subtitle: locale.t("Follows macOS", "macOS ile Eşleşir"), previewBg: Color(red: 0x0C/255, green: 0x0D/255, blue: 0x10/255), previewCard: Color(red: 0x1E/255, green: 0x20/255, blue: 0x26/255), previewText: .white, isSplit: true)
            }
            .frame(maxWidth: 580)

            HStack(spacing: 14) {
                Button {
                    advanceCurrentStep()
                } label: {
                    HStack(spacing: 8) {
                        Text(locale.t("Continue", "Devam Et"))
                            .font(SierraFont.ui(13.5, weight: .semibold))
                        EnterKeyHintPill()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(SierraTheme.accent)
                .controlSize(.large)
            }
        }
    }

    private func themeCard(_ pref: AppThemePreference, title: String, subtitle: String, previewBg: Color, previewCard: Color, previewText: Color, isSplit: Bool = false) -> some View {
        let isSelected = themePref == pref
        return Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                themeRaw = pref.rawValue
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Mini macOS Window Preview
                ZStack {
                    if isSplit {
                        HStack(spacing: 0) {
                            Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255)
                            Color.white
                        }
                    } else {
                        previewBg
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Circle().fill(.red.opacity(0.75)).frame(width: 6, height: 6)
                            Circle().fill(.yellow.opacity(0.75)).frame(width: 6, height: 6)
                            Circle().fill(.green.opacity(0.75)).frame(width: 6, height: 6)
                            Spacer()
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(previewCard)
                            .frame(height: 16)
                            .overlay(
                                HStack(spacing: 4) {
                                    Circle().fill(SierraTheme.accent).frame(width: 5, height: 5)
                                    RoundedRectangle(cornerRadius: 2).fill(previewText.opacity(0.35)).frame(width: 44, height: 4)
                                    Spacer()
                                }
                                .padding(.horizontal, 6)
                            )
                        RoundedRectangle(cornerRadius: 4)
                            .fill(previewCard.opacity(0.75))
                            .frame(height: 24)
                    }
                    .padding(10)
                }
                .frame(height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(SierraTheme.border, lineWidth: 1))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(SierraFont.ui(13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(SierraFont.ui(11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(SierraTheme.accent)
                            .font(.system(size: 15))
                    }
                }
            }
            .padding(12)
            .background(
                SierraTheme.surface.opacity(isDark ? 0.80 : 0.88),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? SierraTheme.accent : SierraTheme.topSpecular, lineWidth: isSelected ? 1.8 : 1)
            )
            .shadow(color: .black.opacity(isDark ? 0.24 : 0.08), radius: 12, y: 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Default Security Audit Profile

    private var profileStepView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(locale.t("Default Security Posture", "Varsayılan Güvenlik Profili"))
                    .font(SierraFont.display(26, weight: .semibold))
                    .tracking(-0.5)
                Text(locale.t("Tailor how strictly Clous evaluates exposed ports, firewall state, and binary signatures.", "Clous'un dışa açık portları, güvenlik duvarını ve dijital imzaları ne kadar sıkı denetleyeceğini seçin."))
                    .font(SierraFont.ui(13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            VStack(spacing: 10) {
                profileRow(.developer, icon: "hammer.fill", desc: locale.t("Balanced for local dev — ignores Apple AirPlay noise, flags real DB exposures & unsigned threats.", "Yerel geliştirme için dengeli — AirPlay gürültüsünü yoksayar, gerçek veritabanı ve imzasız tehditleri işaretler."))
                profileRow(.strict, icon: "shield.lefthalf.filled", desc: locale.t("Production-grade — flags all 0.0.0.0 dev servers, disabled firewall, and unsigned listeners.", "Üretim seviyesi — tüm 0.0.0.0 sunucularını, kapalı güvenlik duvarını ve imzasız dinleyicileri işaretler."))
                profileRow(.zeroTrust, icon: "lock.shield.fill", desc: locale.t("Maximum scrutiny — flags every non-loopback listener, disabled stealth mode, and unverified binary.", "Maksimum denetim — localhost dışındaki her portu, kapalı gizli modu ve doğrulanmamış ikilileri işaretler."))
            }
            .frame(maxWidth: 520)

            HStack(spacing: 14) {
                Button(locale.t("Back", "Geri")) {
                    navigate(to: .theme)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Button {
                    advanceCurrentStep()
                } label: {
                    HStack(spacing: 8) {
                        Text(locale.t("Continue to Shortcut", "Kısayol Ayarına Geç"))
                            .font(SierraFont.ui(13.5, weight: .semibold))
                        EnterKeyHintPill()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(SierraTheme.accent)
                .controlSize(.large)
            }
        }
    }

    private func profileRow(_ opt: AuditProfileOption, icon: String, desc: String) -> some View {
        let isSelected = vm.auditProfile == opt
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                vm.auditProfile = opt
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? SierraTheme.accent : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(opt.localizedLabel)
                        .font(SierraFont.ui(13.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(SierraFont.ui(11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? SierraTheme.accent : .secondary.opacity(0.4))
                    .font(.system(size: 16))
            }
            .padding(14)
            .background(
                SierraTheme.surface.opacity(isDark ? 0.80 : 0.88),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? SierraTheme.accent : SierraTheme.topSpecular, lineWidth: isSelected ? 1.6 : 1)
            )
            .shadow(color: .black.opacity(isDark ? 0.20 : 0.06), radius: 10, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Global Shortcut Recorder

    private var shortcutStepView: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text(isFirstLaunch
                     ? locale.t("Set Your Global Hotkey", "Global Kısayolunu Belirle")
                     : locale.t("Global Quick Launcher Shortcut", "Global Hızlı Başlatıcı Kısayolu"))
                    .font(SierraFont.display(26, weight: .semibold))
                    .tracking(-0.5)
                Text(locale.t("Summon Clous from any app on your Mac — just like Raycast or Spotlight.", "Mac'indeki herhangi bir uygulamadayken Clous'u anında çağır — tıpkı Raycast veya Spotlight gibi."))
                    .font(SierraFont.ui(13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            // Frosted Keycap Recorder Card
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    if isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(SierraTheme.accent)
                                .frame(width: 8, height: 8)
                            Text("Press modifier + key (e.g. ⌥ Space)...")
                                .font(SierraFont.mono(13, weight: .medium))
                                .foregroundStyle(SierraTheme.accent)
                        }
                        .padding(.vertical, 14)
                    } else {
                        ForEach(Array(selectedConfig.keycaps.enumerated()), id: \.offset) { idx, cap in
                            if idx > 0 {
                                Text("+")
                                    .font(SierraFont.ui(16, weight: .medium))
                                    .foregroundStyle(.secondary.opacity(0.6))
                            }
                            TactileKeycapView(label: cap, highlighted: savedPulse)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 66)
                .padding(.horizontal, 20)
                .background(SierraTheme.codeWell.opacity(0.90), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            isRecording
                                ? SierraTheme.accent.opacity(0.8)
                                : (savedPulse ? Color.green.opacity(0.75) : SierraTheme.border),
                            lineWidth: (isRecording || savedPulse) ? 1.5 : 1
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleRecording()
                }
                .modifier(ShakeEffect(animatableData: recorderShake))

                if let err = recorderError {
                    Label(err, systemImage: "exclamationmark.circle.fill")
                        .font(SierraFont.ui(11.5, weight: .medium))
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 10) {
                    Button {
                        toggleRecording()
                    } label: {
                        Label(
                            isRecording ? "Cancel Recording" : "Record Custom",
                            systemImage: isRecording ? "xmark.circle" : "record.circle"
                        )
                        .font(SierraFont.ui(12, weight: .medium))
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    HStack(spacing: 6) {
                        ForEach(HotkeyConfig.presets, id: \.label) { preset in
                            let isChosen = !isRecording && selectedConfig == preset.config
                            Button {
                                stopRecording()
                                recorderError = nil
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedConfig = preset.config
                                }
                            } label: {
                                Text(preset.label)
                                    .font(SierraFont.mono(11, weight: isChosen ? .semibold : .regular))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(
                                        isChosen ? SierraTheme.selectionFill : SierraTheme.surfaceElevated,
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(isChosen ? SierraTheme.accent.opacity(0.7) : SierraTheme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 530)
            .background(
                SierraTheme.surface.opacity(isDark ? 0.80 : 0.90),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SierraTheme.topSpecular, lineWidth: 1)
            )
            .shadow(color: .black.opacity(isDark ? 0.28 : 0.10), radius: 22, y: 8)

            HStack(spacing: 14) {
                if isFirstLaunch {
                    Button("Back") {
                        navigate(to: .profile)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                } else {
                    Button("Cancel") {
                        stopRecording()
                        onComplete()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }

                Button {
                    confirmAndActivate()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: savedPulse ? "checkmark.circle.fill" : "bolt.fill")
                        Text(savedPulse ? "All Set!" : (isFirstLaunch ? "Activate \(selectedConfig.displayString) & Launch" : "Save \(selectedConfig.displayString)"))
                            .font(SierraFont.ui(13.5, weight: .semibold))
                        if !savedPulse {
                            EnterKeyHintPill()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(savedPulse ? .green : SierraTheme.accent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Recorder Helpers

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        stopRecording()
        recorderError = nil
        withAnimation(.easeInOut(duration: 0.16)) { isRecording = true }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let mods = HotkeyConfig.carbonModifiers(from: event.modifierFlags)
            let hasPrimaryMod = !event.modifierFlags.intersection([.command, .option, .control]).isEmpty
            if !hasPrimaryMod {
                recorderError = "Include at least one modifier key (⌘, ⌥, or ⌃)."
                withAnimation(.default) { recorderShake += 1 }
                return nil
            }
            let newConfig = HotkeyConfig(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
            stopRecording()
            recorderError = nil
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedConfig = newConfig
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        withAnimation(.easeInOut(duration: 0.15)) { isRecording = false }
    }

    private func confirmAndActivate() {
        stopRecording()
        hotkeyManager.register(hotkey: selectedConfig, persist: true)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            savedPulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onComplete()
        }
    }
}

// MARK: - Inline Return Keycap Badge for Primary Action Buttons

private struct EnterKeyHintPill: View {
    var body: some View {
        Text("⏎")
            .font(SierraFont.mono(10.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 4.5, style: .continuous))
    }
}

// MARK: - Native 60/120fps Metal Canvas Slow-Motion Thermal Eclipse Gradient

struct ThermalEclipseBackground: View {
    let isDark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Base canvas (#07080A Dark, pure #FFFFFF Light)
            (isDark
                ? Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255)
                : Color.white)

            // GPU-accelerated Canvas — pauses motion automatically when macOS Reduce Motion is enabled
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas(rendersAsynchronously: true) { ctx, size in
                    let w = size.width
                    let h = size.height
                    let diag = max(w, h)

                    if isDark {
                        drawDarkThermalSweep(ctx: &ctx, w: w, h: h, diag: diag, t: t)
                    } else {
                        drawLightCrimsonThermalSweep(ctx: &ctx, w: w, h: h, diag: diag, t: t)
                    }
                }
            }

            // Static top-right corner calm fade
            LinearGradient(
                colors: isDark
                    ? [
                        Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255).opacity(0.80),
                        Color(red: 0x07/255, green: 0x08/255, blue: 0x0A/255).opacity(0.22),
                        Color.clear
                    ]
                    : [
                        Color.white.opacity(0.75),
                        Color.clear,
                        Color.clear
                    ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            // Static organic film-grain texture (outside TimelineView so it never redraws)
            if let grain = ProceduralGrain.sharedImage {
                Image(nsImage: grain)
                    .resizable(resizingMode: .tile)
                    .opacity(isDark ? 0.048 : 0.025)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
        }
    }

    // Ultra-slow-motion Dark Mode: Deep Crimson (#EB0020 -> #A30016 -> #47000A) & Luminous Ruby (#FF2E4A -> #FF5C72)
    private func drawDarkThermalSweep(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, diag: CGFloat, t: TimeInterval) {
        // Layer 1: Primary Crimson outer sweep (#EB0020 -> #A30016 -> #47000A)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.42 + 0.06 * sin(t * 0.045)), y: h * (0.74 + 0.05 * cos(t * 0.038))),
            rx: diag * 0.68, ry: diag * 0.40,
            angleDeg: -23 + 3.5 * sin(t * 0.042),
            stops: [
                .init(color: Color(red: 0xEB/255, green: 0x00/255, blue: 0x20/255).opacity(0.46), location: 0.0),
                .init(color: Color(red: 0xA3/255, green: 0x00/255, blue: 0x16/255).opacity(0.36), location: 0.48),
                .init(color: Color(red: 0x47/255, green: 0x00/255, blue: 0x0A/255).opacity(0.18), location: 0.78),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 2: Electric Coral-Crimson Horizon Ribbon (#FF2E4A -> #D1001C)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.34 + 0.07 * cos(t * 0.040 + 0.6)), y: h * (0.84 + 0.04 * sin(t * 0.046))),
            rx: diag * 0.52, ry: diag * 0.24,
            angleDeg: -17 + 4.0 * cos(t * 0.035 + 1.0),
            stops: [
                .init(color: Color(red: 0xFF/255, green: 0x2E/255, blue: 0x4A/255).opacity(0.36), location: 0.0),
                .init(color: Color(red: 0xD1/255, green: 0x00/255, blue: 0x1C/255).opacity(0.18), location: 0.52),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 3: Rose-Crimson Core (#FF5C72 -> #750010)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.24 + 0.06 * sin(t * 0.036 + 1.8)), y: h * (0.76 + 0.05 * cos(t * 0.044 + 1.2))),
            rx: diag * 0.42, ry: diag * 0.30,
            angleDeg: -30 + 3.0 * sin(t * 0.048 + 2.1),
            stops: [
                .init(color: Color(red: 0xFF/255, green: 0x5C/255, blue: 0x72/255).opacity(0.28), location: 0.0),
                .init(color: Color(red: 0x75/255, green: 0x00/255, blue: 0x10/255).opacity(0.24), location: 0.52),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 4: Soft Velvet-Bordeaux Rim (#D1001C -> #47000A)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.58 + 0.07 * cos(t * 0.034 + 2.4)), y: h * (0.64 + 0.05 * sin(t * 0.042 + 1.7))),
            rx: diag * 0.42, ry: diag * 0.22,
            angleDeg: -26 + 4.0 * cos(t * 0.040 + 0.4),
            stops: [
                .init(color: Color(red: 0xD1/255, green: 0x00/255, blue: 0x1C/255).opacity(0.28), location: 0.0),
                .init(color: Color(red: 0x47/255, green: 0x00/255, blue: 0x0A/255).opacity(0.16), location: 0.50),
                .init(color: .clear, location: 1.0)
            ]
        )
    }

    // Ultra-slow-motion Light Mode: Pure White base with luminous Crimson & Rose-Blush Thermal Sweep
    private func drawLightCrimsonThermalSweep(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, diag: CGFloat, t: TimeInterval) {
        // Layer 1: Primary Crimson sweep (#EB0020 -> #FF5C72 -> #FFE6E9)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.40 + 0.06 * sin(t * 0.045)), y: h * (0.76 + 0.05 * cos(t * 0.038))),
            rx: diag * 0.72, ry: diag * 0.44,
            angleDeg: -22 + 3.5 * sin(t * 0.042),
            stops: [
                .init(color: Color(red: 0xEB/255, green: 0x00/255, blue: 0x20/255).opacity(0.28), location: 0.0),
                .init(color: Color(red: 0xFF/255, green: 0x5C/255, blue: 0x72/255).opacity(0.24), location: 0.42),
                .init(color: Color(red: 0xFF/255, green: 0xE6/255, blue: 0xE9/255).opacity(0.32), location: 0.74),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 2: Soft Rose-Coral Luminous Band (#FF2E4A -> #FF8A99)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.32 + 0.07 * cos(t * 0.040 + 0.6)), y: h * (0.86 + 0.04 * sin(t * 0.046))),
            rx: diag * 0.56, ry: diag * 0.28,
            angleDeg: -16 + 4.0 * cos(t * 0.035 + 1.0),
            stops: [
                .init(color: Color(red: 0xFF/255, green: 0x2E/255, blue: 0x4A/255).opacity(0.28), location: 0.0),
                .init(color: Color(red: 0xFF/255, green: 0x8A/255, blue: 0x99/255).opacity(0.20), location: 0.50),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 3: Deep Ruby Core (#D1001C -> #FFB8C1)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.20 + 0.06 * sin(t * 0.036 + 1.8)), y: h * (0.72 + 0.05 * cos(t * 0.044 + 1.2))),
            rx: diag * 0.44, ry: diag * 0.32,
            angleDeg: -28 + 3.0 * sin(t * 0.048 + 2.1),
            stops: [
                .init(color: Color(red: 0xD1/255, green: 0x00/255, blue: 0x1C/255).opacity(0.24), location: 0.0),
                .init(color: Color(red: 0xFF/255, green: 0xB8/255, blue: 0xC1/255).opacity(0.20), location: 0.52),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 4: Delicate Blush-Rose Rim on the right arc (#FF8A99 -> #FFE6E9)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.64 + 0.07 * cos(t * 0.034 + 2.4)), y: h * (0.68 + 0.05 * sin(t * 0.042 + 1.7))),
            rx: diag * 0.44, ry: diag * 0.26,
            angleDeg: -24 + 4.0 * cos(t * 0.040 + 0.4),
            stops: [
                .init(color: Color(red: 0xFF/255, green: 0x8A/255, blue: 0x99/255).opacity(0.22), location: 0.0),
                .init(color: Color(red: 0xFF/255, green: 0xE6/255, blue: 0xE9/255).opacity(0.24), location: 0.54),
                .init(color: .clear, location: 1.0)
            ]
        )
    }

    /// Draws an organically feathered radial gradient stretched into an angled ellipse — pure GPU, zero blur cost.
    private func drawSoftEllipse(
        ctx: inout GraphicsContext,
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        angleDeg: Double,
        stops: [Gradient.Stop]
    ) {
        var copy = ctx
        copy.translateBy(x: center.x, y: center.y)
        copy.rotate(by: .degrees(angleDeg))
        copy.scaleBy(x: 1.0, y: ry / max(rx, 1.0))

        let rect = CGRect(x: -rx, y: -rx, width: rx * 2, height: rx * 2)
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(stops: stops),
            center: .zero,
            startRadius: 0,
            endRadius: rx
        )
        copy.fill(Path(ellipseIn: rect), with: shading)
    }
}

private enum ProceduralGrain {
    static let sharedImage: NSImage? = {
        let size = 128
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<(size * size) {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let v = UInt8((seed >> 33) & 0xFF)
            bytes[i * 4] = v
            bytes[i * 4 + 1] = v
            bytes[i * 4 + 2] = v
            bytes[i * 4 + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &bytes, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cg = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }()
}

// MARK: - Tactile 3D-Style macOS Keycap

struct TactileKeycapView: View {
    let label: String
    var highlighted: Bool = false

    var body: some View {
        Text(label)
            .font(SierraFont.ui(label.count > 1 ? 15 : 20, weight: .semibold))
            .foregroundStyle(highlighted ? .green : .primary)
            .frame(minWidth: label.count > 1 ? 76 : 46, minHeight: 44)
            .padding(.horizontal, label.count > 1 ? 12 : 4)
            .background(
                LinearGradient(
                    colors: [SierraTheme.surfaceElevated, SierraTheme.surface],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(highlighted ? Color.green.opacity(0.65) : SierraTheme.border, lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(0.28), radius: 2, y: 2.5)
    }
}
