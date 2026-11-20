import SwiftUI
import AppKit

// MARK: - One-Time First-Launch Setup Wizard (Theme -> Security Profile -> Global Shortcut)

struct ShortcutOnboardingView: View {
    @ObservedObject var vm: SierraPortViewModel
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
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

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Brand Mascot Mark (white in Dark Mode, obsidian in Light Mode)
                SierraMascotMarkView(size: 64)
                    .shadow(color: isDark ? .black.opacity(0.35) : Color(red: 0x08/255, green: 0x24/255, blue: 0x52/255).opacity(0.18), radius: 14, y: 5)
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
                Text("Welcome to SierraPort")
                    .font(SierraFont.display(28, weight: .semibold))
                    .tracking(-0.6)
                Text("Choose your preferred interface appearance. You can switch anytime.")
                    .font(SierraFont.ui(13.5))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                themeCard(.dark, title: "Dark", subtitle: "Obsidian #111110", previewBg: Color(red: 0x11/255, green: 0x11/255, blue: 0x10/255), previewCard: Color(red: 0x1E/255, green: 0x1E/255, blue: 0x1C/255), previewText: .white)
                themeCard(.light, title: "Light", subtitle: "Porcelain #F6F6F4", previewBg: Color(red: 0xF6/255, green: 0xF6/255, blue: 0xF4/255), previewCard: .white, previewText: Color(red: 0x11/255, green: 0x11/255, blue: 0x10/255))
                themeCard(.system, title: "System", subtitle: "Follows macOS", previewBg: Color(red: 0x18/255, green: 0x18/255, blue: 0x17/255), previewCard: Color(red: 0x28/255, green: 0x28/255, blue: 0x26/255), previewText: .white, isSplit: true)
            }
            .frame(maxWidth: 580)

            HStack(spacing: 14) {
                Button {
                    advanceCurrentStep()
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
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
                            Color(red: 0x11/255, green: 0x11/255, blue: 0x10/255)
                            Color(red: 0xF6/255, green: 0xF6/255, blue: 0xF4/255)
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
                Text("Default Security Posture")
                    .font(SierraFont.display(26, weight: .semibold))
                    .tracking(-0.5)
                Text("Tailor how strictly SierraPort evaluates exposed ports, firewall state, and binary signatures.")
                    .font(SierraFont.ui(13.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            VStack(spacing: 10) {
                profileRow(.developer, icon: "hammer.fill", desc: "Balanced for local dev — ignores Apple AirPlay noise, flags real DB exposures & unsigned threats.")
                profileRow(.strict, icon: "shield.lefthalf.filled", desc: "Production-grade — flags all 0.0.0.0 dev servers, disabled firewall, and unsigned listeners.")
                profileRow(.zeroTrust, icon: "lock.shield.fill", desc: "Maximum scrutiny — flags every non-loopback listener, disabled stealth mode, and unverified binary.")
            }
            .frame(maxWidth: 520)

            HStack(spacing: 14) {
                Button("Back") {
                    navigate(to: .theme)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Button {
                    advanceCurrentStep()
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue to Shortcut")
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
                    Text(opt.label)
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
                Text(isFirstLaunch ? "Set Your Global Hotkey" : "Global Quick Launcher Shortcut")
                    .font(SierraFont.display(26, weight: .semibold))
                    .tracking(-0.5)
                Text("Summon SierraPort from any app on your Mac — just like Raycast or Spotlight.")
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

    var body: some View {
        ZStack {
            // Base canvas
            (isDark
                ? Color(red: 0x0C/255, green: 0x0D/255, blue: 0x10/255)
                : Color(red: 0xF5/255, green: 0xF6/255, blue: 0xF8/255))

            // GPU-accelerated Canvas — zero Gaussian blur passes, full native refresh rate, ultra-slow motion
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas(rendersAsynchronously: true) { ctx, size in
                    let w = size.width
                    let h = size.height
                    let diag = max(w, h)

                    if isDark {
                        drawDarkThermalSweep(ctx: &ctx, w: w, h: h, diag: diag, t: t)
                    } else {
                        drawLightBlueThermalSweep(ctx: &ctx, w: w, h: h, diag: diag, t: t)
                    }
                }
            }

            // Static top-right corner calm fade (keeps ~68% partial sweep feeling without washing out colors)
            LinearGradient(
                colors: isDark
                    ? [
                        Color(red: 0x0C/255, green: 0x0D/255, blue: 0x10/255).opacity(0.72),
                        Color(red: 0x0C/255, green: 0x0D/255, blue: 0x10/255).opacity(0.14),
                        Color.clear
                    ]
                    : [
                        Color(red: 0xF5/255, green: 0xF6/255, blue: 0xF8/255).opacity(0.55),
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
                    .opacity(isDark ? 0.048 : 0.028)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
        }
    }

    // Ultra-slow-motion Dark Mode: Deep Sapphire + Electric Cyan + Thermal Magenta + Solar Amber
    private func drawDarkThermalSweep(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, diag: CGFloat, t: TimeInterval) {
        // Layer 1: Deep Ocean Sapphire outer sweep (#082452 -> #0052D4)
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.42 + 0.06 * sin(t * 0.045)), y: h * (0.74 + 0.05 * cos(t * 0.038))),
            rx: diag * 0.68, ry: diag * 0.40,
            angleDeg: -23 + 3.5 * sin(t * 0.042),
            stops: [
                .init(color: Color(red: 0x00/255, green: 0x52/255, blue: 0xD4/255).opacity(0.58), location: 0.0),
                .init(color: Color(red: 0x08/255, green: 0x24/255, blue: 0x52/255).opacity(0.42), location: 0.48),
                .init(color: Color(red: 0x08/255, green: 0x24/255, blue: 0x52/255).opacity(0.14), location: 0.78),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 2: Electric Cyan Horizon Ribbon
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.34 + 0.07 * cos(t * 0.040 + 0.6)), y: h * (0.84 + 0.04 * sin(t * 0.046))),
            rx: diag * 0.52, ry: diag * 0.24,
            angleDeg: -17 + 4.0 * cos(t * 0.035 + 1.0),
            stops: [
                .init(color: Color(red: 0x00/255, green: 0xB8/255, blue: 0xFF/255).opacity(0.42), location: 0.0),
                .init(color: Color(red: 0x00/255, green: 0x70/255, blue: 0xF3/255).opacity(0.20), location: 0.52),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 3: Thermal Violet-Magenta Core
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.24 + 0.06 * sin(t * 0.036 + 1.8)), y: h * (0.76 + 0.05 * cos(t * 0.044 + 1.2))),
            rx: diag * 0.42, ry: diag * 0.30,
            angleDeg: -30 + 3.0 * sin(t * 0.048 + 2.1),
            stops: [
                .init(color: Color(red: 0xD9/255, green: 0x30/255, blue: 0x8A/255).opacity(0.36), location: 0.0),
                .init(color: Color(red: 0x5B/255, green: 0x2C/255, blue: 0xC6/255).opacity(0.22), location: 0.52),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 4: Solar Thermal Amber Rim
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.58 + 0.07 * cos(t * 0.034 + 2.4)), y: h * (0.64 + 0.05 * sin(t * 0.042 + 1.7))),
            rx: diag * 0.42, ry: diag * 0.22,
            angleDeg: -26 + 4.0 * cos(t * 0.040 + 0.4),
            stops: [
                .init(color: Color(red: 0xF5/255, green: 0x8A/255, blue: 0x29/255).opacity(0.34), location: 0.0),
                .init(color: Color(red: 0xE2/255, green: 0x4E/255, blue: 0x1B/255).opacity(0.15), location: 0.50),
                .init(color: .clear, location: 1.0)
            ]
        )
    }

    // Ultra-slow-motion Light Mode: Rich, clearly visible Ocean Sapphire & Luminous Cobalt Thermal Sweep
    private func drawLightBlueThermalSweep(ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, diag: CGFloat, t: TimeInterval) {
        // Layer 1: Deep Ocean Sapphire sweep (#082452 -> #155DFC) — unmistakably visible on porcelain canvas
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.40 + 0.06 * sin(t * 0.045)), y: h * (0.76 + 0.05 * cos(t * 0.038))),
            rx: diag * 0.72, ry: diag * 0.44,
            angleDeg: -22 + 3.5 * sin(t * 0.042),
            stops: [
                .init(color: Color(red: 0x08/255, green: 0x24/255, blue: 0x52/255).opacity(0.42), location: 0.0),
                .init(color: Color(red: 0x0E/255, green: 0x52/255, blue: 0xD8/255).opacity(0.34), location: 0.42),
                .init(color: Color(red: 0x3B/255, green: 0x82/255, blue: 0xF6/255).opacity(0.16), location: 0.74),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 2: Electric Sky-Cyan Luminous Band
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.32 + 0.07 * cos(t * 0.040 + 0.6)), y: h * (0.86 + 0.04 * sin(t * 0.046))),
            rx: diag * 0.56, ry: diag * 0.28,
            angleDeg: -16 + 4.0 * cos(t * 0.035 + 1.0),
            stops: [
                .init(color: Color(red: 0x00/255, green: 0xA8/255, blue: 0xFF/255).opacity(0.46), location: 0.0),
                .init(color: Color(red: 0x38/255, green: 0xBD/255, blue: 0xF8/255).opacity(0.24), location: 0.50),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 3: Royal Cobalt-Indigo Thermal Core
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.20 + 0.06 * sin(t * 0.036 + 1.8)), y: h * (0.72 + 0.05 * cos(t * 0.044 + 1.2))),
            rx: diag * 0.44, ry: diag * 0.32,
            angleDeg: -28 + 3.0 * sin(t * 0.048 + 2.1),
            stops: [
                .init(color: Color(red: 0x1D/255, green: 0x4E/255, blue: 0xD8/255).opacity(0.36), location: 0.0),
                .init(color: Color(red: 0x4F/255, green: 0x46/255, blue: 0xE5/255).opacity(0.18), location: 0.52),
                .init(color: .clear, location: 1.0)
            ]
        )

        // Layer 4: Fresh Glacier-Teal & Soft Sapphire Rim on the right arc
        drawSoftEllipse(
            ctx: &ctx,
            center: CGPoint(x: w * (0.64 + 0.07 * cos(t * 0.034 + 2.4)), y: h * (0.68 + 0.05 * sin(t * 0.042 + 1.7))),
            rx: diag * 0.44, ry: diag * 0.26,
            angleDeg: -24 + 4.0 * cos(t * 0.040 + 0.4),
            stops: [
                .init(color: Color(red: 0x06/255, green: 0xB6/255, blue: 0xD4/255).opacity(0.32), location: 0.0),
                .init(color: Color(red: 0x25/255, green: 0x63/255, blue: 0xEB/255).opacity(0.14), location: 0.54),
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
