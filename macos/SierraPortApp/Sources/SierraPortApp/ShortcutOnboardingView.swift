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
    @State private var selectedConfig: HotkeyConfig = .optionSpace
    @State private var isRecording: Bool = false
    @State private var recorderError: String? = nil
    @State private var recorderShake: CGFloat = 0
    @State private var keyMonitor: Any? = nil
    @State private var savedPulse: Bool = false

    // Staggered entrance motion
    @State private var appeared: Bool = false

    private var themePref: AppThemePreference {
        AppThemePreference(rawValue: themeRaw) ?? .dark
    }

    var body: some View {
        ZStack {
            // Sweeping Slow-Motion Thermal Eclipse Arc (partial canvas sweep + fine organic grain)
            ThermalEclipseBackground(isDark: colorScheme == .dark)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 20)

                // Brand Mascot Mark (pure white/monochrome)
                SierraMascotMarkView(size: 64)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
                    .scaleEffect(appeared ? 1.0 : 0.78)
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
                                    .fill(isActive ? Color.white : (isDone ? Color.green : Color.secondary.opacity(0.35)))
                                    .frame(width: 6, height: 6)
                                Text(s.label)
                                    .font(SierraFont.ui(11, weight: isActive ? .semibold : .regular))
                                    .foregroundStyle(isActive ? .primary : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                isActive ? Color.primary.opacity(0.10) : Color.clear,
                                in: Capsule()
                            )
                            .onTapGesture {
                                stopRecording()
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                                    step = s
                                }
                            }
                        }
                    }
                    .padding(.bottom, 22)
                    .opacity(appeared ? 1.0 : 0.0)
                }

                // Dynamic Step Content
                Group {
                    switch step {
                    case .theme:
                        themeStepView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case .profile:
                        profileStepView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    case .shortcut:
                        shortcutStepView
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                }
                .offset(y: appeared ? 0 : 16)
                .opacity(appeared ? 1.0 : 0.0)

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 36)
        }
        .onAppear {
            if let existing = hotkeyManager.currentHotkey {
                selectedConfig = existing
            }
            // If opened from sidebar to edit shortcut only, jump straight to Shortcut step
            step = isFirstLaunch ? .theme : .shortcut
            withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                appeared = true
            }
        }
        .onDisappear {
            stopRecording()
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
                Button("Continue") {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        step = .profile
                    }
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .background(SierraTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? SierraTheme.accent : SierraTheme.topSpecular, lineWidth: isSelected ? 1.8 : 1)
            )
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
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        step = .theme
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Button("Continue to Shortcut") {
                    Task { await vm.refreshAudit() }
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        step = .shortcut
                    }
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.84)) {
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .background(SierraTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? SierraTheme.accent : SierraTheme.topSpecular, lineWidth: isSelected ? 1.6 : 1)
            )
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

            // Frosted Glass Keycap Recorder Card
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
                .background(SierraTheme.codeWell.opacity(0.85), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(SierraTheme.surface.opacity(0.68), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SierraTheme.topSpecular, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 24, y: 10)

            HStack(spacing: 14) {
                if isFirstLaunch {
                    Button("Back") {
                        stopRecording()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            step = .profile
                        }
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
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) {
            onComplete()
        }
    }
}

// MARK: - Sweeping Slow-Motion Thermal Eclipse Gradient (Inspired by Horizon Wave + Thermal Arc)

struct ThermalEclipseBackground: View {
    let isDark: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let diag = max(w, h)

                ZStack {
                    // Clean base canvas — top-left / top-right corners remain deep & calm
                    SierraTheme.canvas

                    // Sweeping diagonal thermal eclipse arc covering ~65–72% of canvas
                    ZStack {
                        // Layer 1: Deep Ocean Sapphire outer sweep (#082452 -> #0052D4)
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0x00/255, green: 0x52/255, blue: 0xD4/255).opacity(isDark ? 0.62 : 0.28),
                                        Color(red: 0x08/255, green: 0x24/255, blue: 0x52/255).opacity(isDark ? 0.45 : 0.16),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: diag * 0.04,
                                    endRadius: diag * 0.52
                                )
                            )
                            .frame(width: diag * 1.15, height: diag * 0.62)
                            .rotationEffect(.degrees(-24 + 5.0 * sin(t * 0.12)))
                            .position(
                                x: w * (0.42 + 0.08 * sin(t * 0.10)),
                                y: h * (0.72 + 0.06 * cos(t * 0.09))
                            )
                            .blur(radius: 56)

                        // Layer 2: Electric Cyan Horizon Ribbon (reference image 1 luminous cyan band)
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0x00/255, green: 0xB4/255, blue: 0xFF/255).opacity(isDark ? 0.44 : 0.22),
                                        Color(red: 0x00/255, green: 0x70/255, blue: 0xF3/255).opacity(isDark ? 0.22 : 0.10),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: diag * 0.36
                                )
                            )
                            .frame(width: diag * 0.88, height: diag * 0.34)
                            .rotationEffect(.degrees(-18 + 6.0 * cos(t * 0.08 + 1.0)))
                            .position(
                                x: w * (0.34 + 0.10 * cos(t * 0.09 + 0.6)),
                                y: h * (0.82 + 0.05 * sin(t * 0.11))
                            )
                            .blur(radius: 44)

                        // Layer 3: Thermal Violet-Magenta Core (reference image 2 warm thermal eclipse)
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0xD9/255, green: 0x30/255, blue: 0x8A/255).opacity(isDark ? 0.36 : 0.16),
                                        Color(red: 0x5B/255, green: 0x2C/255, blue: 0xC6/255).opacity(isDark ? 0.26 : 0.10),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: diag * 0.32
                                )
                            )
                            .frame(width: diag * 0.64, height: diag * 0.42)
                            .rotationEffect(.degrees(-32 + 4.5 * sin(t * 0.11 + 2.1)))
                            .position(
                                x: w * (0.24 + 0.08 * sin(t * 0.08 + 1.8)),
                                y: h * (0.76 + 0.06 * cos(t * 0.10 + 1.2))
                            )
                            .blur(radius: 48)

                        // Layer 4: Solar Thermal Amber Rim (reference image 2 golden-orange arc edge)
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0xF5/255, green: 0x8A/255, blue: 0x29/255).opacity(isDark ? 0.32 : 0.15),
                                        Color(red: 0xE2/255, green: 0x4E/255, blue: 0x1B/255).opacity(isDark ? 0.16 : 0.07),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: diag * 0.30
                                )
                            )
                            .frame(width: diag * 0.62, height: diag * 0.28)
                            .rotationEffect(.degrees(-28 + 5.5 * cos(t * 0.10 + 0.4)))
                            .position(
                                x: w * (0.58 + 0.09 * cos(t * 0.07 + 2.4)),
                                y: h * (0.64 + 0.07 * sin(t * 0.09 + 1.7))
                            )
                            .blur(radius: 52)
                    }

                    // Subtle dark vignette in top-right / corners so the thermal sweep feels dramatic and partial
                    LinearGradient(
                        colors: [
                            SierraTheme.canvas.opacity(isDark ? 0.82 : 0.72),
                            SierraTheme.canvas.opacity(isDark ? 0.22 : 0.28),
                            SierraTheme.canvas.opacity(isDark ? 0.18 : 0.22)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )

                    // Organic studio film-grain texture (cached procedural CGImage)
                    if let grain = ProceduralGrain.sharedImage {
                        Image(nsImage: grain)
                            .resizable(resizingMode: .tile)
                            .opacity(isDark ? 0.055 : 0.03)
                            .blendMode(.overlay)
                    }
                }
            }
        }
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
