import SwiftUI
import AppKit

// MARK: - Raycast / Spotlight-Style Floating NSPanel

final class FloatingLauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickLauncherController: NSObject, NSWindowDelegate {
    static let shared = QuickLauncherController()

    private var panel: FloatingLauncherPanel? = nil
    private weak var viewModel: SierraPortViewModel? = nil
    private var colorSchemeProvider: (() -> ColorScheme?)? = nil
    private var wasSierraPortFrontmost: Bool = false

    func configure(vm: SierraPortViewModel, colorSchemeProvider: @escaping () -> ColorScheme?) {
        self.viewModel = vm
        self.colorSchemeProvider = colorSchemeProvider
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide(restoreMainIfNeeded: true)
        } else {
            show()
        }
    }

    func show() {
        guard let vm = viewModel else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        wasSierraPortFrontmost = (NSWorkspace.shared.frontmostApplication?.processIdentifier == currentPID)

        if panel == nil {
            let p = FloatingLauncherPanel(
                contentRect: NSRect(x: 0, y: 0, width: 660, height: 430),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            p.isFloatingPanel = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.isMovableByWindowBackground = false
            p.hidesOnDeactivate = false
            p.delegate = self
            self.panel = p
        }

        guard let panel else { return }

        let rootView = QuickLauncherView(
            vm: vm,
            hotkeyManager: GlobalHotkeyManager.shared,
            onDismiss: { [weak self] in
                self?.hide(restoreMainIfNeeded: true)
            },
            onOpenMainWindow: { [weak self] in
                self?.openMainWindow()
            }
        )
        .font(SierraFont.ui(13))
        .tint(SierraTheme.accent)
        .preferredColorScheme(colorSchemeProvider?())

        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.cornerRadius = 16
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting

        let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let screen = mouseScreen {
            let vf = screen.visibleFrame
            let x = vf.midX - panel.frame.width / 2.0
            let y = vf.maxY - panel.frame.height - (vf.height * 0.14)
            panel.setFrameOrigin(NSPoint(x: x, y: max(vf.minY + 40, y)))
        }

        panel.alphaValue = 0.0
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
    }

    func hide(restoreMainIfNeeded: Bool = false) {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1.0

        if restoreMainIfNeeded && wasSierraPortFrontmost {
            bringMainWindowToFront()
        }
    }

    func openMainWindow() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            panel.alphaValue = 1.0
        }
        bringMainWindowToFront()
    }

    private func bringMainWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        if let mainWin = NSApp.windows.first(where: { !($0 is FloatingLauncherPanel) && $0.canBecomeMain }) {
            if mainWin.isMiniaturized {
                mainWin.deminiaturize(nil)
            }
            mainWin.makeKeyAndOrderFront(nil)
            mainWin.orderFrontRegardless()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        hide(restoreMainIfNeeded: false)
    }
}

// MARK: - Raycast-Style Quick Launcher View

struct QuickLauncherItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String?
    let command: String
}

struct QuickLauncherView: View {
    @ObservedObject var vm: SierraPortViewModel
    @ObservedObject var hotkeyManager: GlobalHotkeyManager
    let onDismiss: () -> Void
    let onOpenMainWindow: () -> Void

    @State private var query: String = ""
    @State private var selectedIdx: Int = 0
    @State private var didNavigateList: Bool = false
    @State private var errorMsg: String? = nil
    @State private var shakeTrigger: CGFloat = 0
    @State private var latestBlock: CommandBlock? = nil
    @State private var isRunning: Bool = false
    @FocusState private var isInputFocused: Bool

    private var dynamicItems: [QuickLauncherItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        var items: [QuickLauncherItem] = []

        if trimmed.isEmpty {
            let defaults: [(String, String, String, String)] = [
                ("globe", "list --exposed", "Show externally exposed ports", "list --exposed"),
                ("memorychip", "list --wide --sort mem --desc", "Sort active ports by RAM", "list --wide --sort mem --desc"),
                ("shield.lefthalf.filled", "audit --deep", "Run security & binary trust audit", "audit --deep"),
                ("sparkle.magnifyingglass", "inspect 5000 --probe", "Forensic inspect + live banner probe", "inspect 5000 --probe"),
                ("plus.circle", "free --range 8000-8999 --count 3", "Find 3 available TCP ports", "free --range 8000-8999 --count 3"),
                ("chart.bar.xaxis", "stats", "Socket & exposure statistics", "stats")
            ]
            for (icon, title, sub, cmd) in defaults {
                items.append(QuickLauncherItem(id: "def-\(cmd)", icon: icon, title: title, subtitle: sub, command: cmd))
            }
            return items
        }

        // 1. Live listening ports matching query (instant dynamic Raycast feel!)
        let lower = trimmed.lowercased()
        if let entries = vm.latestTick?.entries {
            var seenPorts = Set<Int>()
            for e in entries {
                if seenPorts.contains(e.localPort) { continue }
                let matchesPort = "\(e.localPort)".contains(lower)
                let matchesProc = e.process?.lowercased().contains(lower) ?? false
                let matchesSvc = e.service?.lowercased().contains(lower) ?? false
                if matchesPort || matchesProc || matchesSvc {
                    seenPorts.insert(e.localPort)
                    items.append(
                        QuickLauncherItem(
                            id: "port-\(e.localPort)",
                            icon: "sparkle.magnifyingglass",
                            title: "inspect \(e.localPort) --probe",
                            subtitle: "\(e.process ?? "-") · \(e.protocolName) [\(e.bindScope)]",
                            command: "inspect \(e.localPort) --probe"
                        )
                    )
                    if items.count >= 3 { break }
                }
            }
        }

        // 2. Bilingual / fuzzy CLI command suggestions
        for cmd in vm.suggestRelatedCommands(for: trimmed) {
            if !items.contains(where: { $0.command == cmd }) {
                items.append(
                    QuickLauncherItem(
                        id: "cmd-\(cmd)",
                        icon: "terminal",
                        title: cmd,
                        subtitle: nil,
                        command: cmd
                    )
                )
            }
        }

        return Array(items.prefix(7))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Raycast Input Bar with Pure White Mascot Mark (zero blue box!)
            HStack(spacing: 12) {
                SierraMascotMarkView(size: 24)

                TextField("Type a command, port, or process (e.g. 5000, exposed, close 3000)...", text: $query)
                    .textFieldStyle(.plain)
                    .font(SierraFont.ui(15, weight: .regular))
                    .focused($isInputFocused)
                    .onChange(of: query) { _, _ in
                        errorMsg = nil
                        selectedIdx = 0
                        didNavigateList = false
                    }
                    .onSubmit {
                        runCurrent()
                    }
                    .onKeyPress(keys: [.tab]) { press in
                        withAnimation(.easeOut(duration: 0.1)) {
                            moveSelection(press.modifiers.contains(.shift) ? -1 : 1)
                        }
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        withAnimation(.easeOut(duration: 0.1)) { moveSelection(1) }
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        withAnimation(.easeOut(duration: 0.1)) { moveSelection(-1) }
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        if latestBlock != nil {
                            withAnimation(.easeOut(duration: 0.12)) { latestBlock = nil }
                        } else if !query.isEmpty {
                            query = ""
                            errorMsg = nil
                        } else {
                            onDismiss()
                        }
                        return .handled
                    }

                if isRunning {
                    ProgressView().controlSize(.small)
                }

                if !query.isEmpty {
                    Button {
                        query = ""
                        errorMsg = nil
                        selectedIdx = 0
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .modifier(ShakeEffect(animatableData: shakeTrigger))

            if let err = errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11))
                    Text(err)
                        .font(SierraFont.ui(11.5, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }

            Divider().opacity(0.4)

            // Body: Instant Result View OR Dynamic Command / Port List
            ScrollView {
                if let block = latestBlock {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("❯ \(block.command)")
                                .font(SierraFont.mono(12, weight: .semibold))
                                .foregroundStyle(SierraTheme.accent)
                            Text(block.summaryLabel)
                                .font(SierraFont.mono(10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(SierraTheme.accent.opacity(0.14), in: Capsule())
                                .foregroundStyle(SierraTheme.accent)
                            Spacer()
                            Text("\(block.durationMs)ms")
                                .font(SierraFont.mono(10))
                                .foregroundStyle(.secondary)
                            Button("Back (Esc)") {
                                withAnimation(.easeOut(duration: 0.15)) { latestBlock = nil }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }

                        Divider().opacity(0.35)

                        switch block.payload {
                        case .ports(let entries):
                            VStack(spacing: 4) {
                                ForEach(Array(entries.prefix(18).enumerated()), id: \.offset) { _, e in
                                    HStack(spacing: 10) {
                                        Text(e.protocolName)
                                            .font(SierraFont.mono(10, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 38, alignment: .leading)
                                        Text(":\(e.localPort)")
                                            .font(SierraFont.mono(12, weight: .bold))
                                            .foregroundStyle(SierraTheme.accent)
                                            .frame(width: 58, alignment: .leading)
                                        ScopeBadge(scope: e.bindScope)
                                        Text(e.process ?? "-")
                                            .font(SierraFont.ui(12, weight: .medium))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(e.memoryHuman)
                                            .font(SierraFont.mono(11))
                                            .foregroundStyle(.secondary)
                                        Button("Inspect") {
                                            runSpecific("inspect \(e.localPort) --probe")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(SierraTheme.surfaceElevated.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        case .audit(let report):
                            AuditVisualView(
                                report: report,
                                allowlistedKeys: vm.allowlistedKeys,
                                onInspectPort: { runSpecific("inspect \($0) --probe") }
                            )
                        case .inspect(let report):
                            InspectVisualView(report: report, onKill: { vm.killPort($0) })
                        case .probe(let results):
                            ProbeResultsVisualView(results: results)
                        case .freePorts(let free):
                            FreePortsVisualView(result: free)
                        case .diff(let diff):
                            DiffVisualView(diff: diff)
                        case .stats(let stats):
                            StatsVisualView(stats: stats)
                        case .text(let s):
                            Text(s)
                                .font(SierraFont.mono(11.5))
                                .textSelection(.enabled)
                        case .error(let err):
                            Label(err, systemImage: "exclamationmark.triangle.fill")
                                .font(SierraFont.ui(12))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(errorMsg != nil ? "DID YOU MEAN?" : (query.isEmpty ? "QUICK ACTIONS" : "RESULTS"))
                            .font(SierraFont.ui(10, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(errorMsg != nil ? .orange : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        ForEach(Array(dynamicItems.enumerated()), id: \.element.id) { idx, item in
                            let isSel = selectedIdx == idx
                            Button {
                                runSpecific(item.command)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(isSel ? SierraTheme.accent : .secondary)
                                        .frame(width: 18)
                                    Text(item.title)
                                        .font(SierraFont.mono(12.5, weight: isSel ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if let sub = item.subtitle {
                                        Text(sub)
                                            .font(SierraFont.ui(11.5))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    Spacer(minLength: 6)
                                    if isSel {
                                        RaycastKeycap(key: "⏎")
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    isSel ? SierraTheme.selectionFill : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(maxHeight: 310)

            Divider().opacity(0.4)

            // Crisp Raycast Footer Bar
            HStack(spacing: 10) {
                if let hk = hotkeyManager.currentHotkey {
                    HStack(spacing: 3) {
                        ForEach(hk.keycaps, id: \.self) { cap in
                            RaycastKeycap(key: cap)
                        }
                    }
                }
                Text("Tab / ↑↓ select · ⏎ run · Esc close")
                    .font(SierraFont.ui(11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onOpenMainWindow()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "macwindow")
                            .font(.system(size: 11))
                        Text("Open App")
                            .font(SierraFont.ui(11.5, weight: .medium))
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(SierraTheme.sidebar)
        }
        .background(SierraTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                isInputFocused = true
            }
        }
    }

    private func moveSelection(_ delta: Int) {
        let count = dynamicItems.count
        guard count > 0 else { return }
        didNavigateList = true
        selectedIdx = (selectedIdx + delta + count) % count
    }

    private func runCurrent() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = dynamicItems
        if (trimmed.isEmpty || didNavigateList || errorMsg != nil),
           selectedIdx >= 0 && selectedIdx < items.count {
            didNavigateList = false
            runSpecific(items[selectedIdx].command)
            return
        }
        guard !trimmed.isEmpty else { return }
        runSpecific(trimmed)
    }

    private func runSpecific(_ raw: String) {
        if raw.lowercased().hasPrefix("watch") {
            vm.selectedTab = .watch
            onOpenMainWindow()
            return
        }
        isRunning = true
        errorMsg = nil
        Task {
            let beforeId = vm.blocks.first?.id
            await vm.executeCommand(raw)
            isRunning = false
            if vm.inputError != nil {
                errorMsg = vm.inputError
                vm.clearInputError()
                selectedIdx = 0
                withAnimation(.default) { shakeTrigger += 1 }
            } else if let top = vm.blocks.first, top.id != beforeId {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    latestBlock = top
                }
                query = ""
                selectedIdx = 0
            }
        }
    }
}
