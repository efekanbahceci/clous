import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: SierraPortViewModel
    @FocusState private var isCommandFocused: Bool

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    mainDetail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if vm.showingInspector {
                        Divider()
                        inspectorDrawer
                            .frame(width: 370)
                            .background(.ultraThinMaterial)
                            .transition(.move(edge: .trailing))
                    }
                }

                if let msg = vm.statusMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 6)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: vm.showingInspector)
            .animation(.easeInOut(duration: 0.2), value: vm.statusMessage)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if let tick = vm.latestTick {
                    HStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(vm.isStreaming ? Color.green : Color.secondary)
                                .frame(width: 7, height: 7)
                            Text("\(tick.active) active")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                        if tick.exposed > 0 {
                            Text("\(tick.exposed) exposed")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                        Text("\(tick.scanMs)ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.primary.opacity(0.05), in: Capsule())
                }

                Button {
                    isCommandFocused = true
                    vm.selectedTab = .terminal
                } label: {
                    Label("Command", systemImage: "terminal")
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Focus SierraPort Command Bar (⌘K)")

                Button {
                    Task {
                        await vm.refreshAudit()
                        await vm.refreshStats()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh Metrics (⌘R)")
            }
        }
        .onAppear {
            isCommandFocused = true
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("Sierra")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                    Text("Port")
                        .font(.system(size: 20, weight: .light, design: .default))
                        .foregroundStyle(.secondary)
                }
                Text("PORT MONITOR & INSPECTOR")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)

            List(AppTab.allCases, selection: $vm.selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vm.bridge.binaryPath != nil ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(vm.bridge.binaryPath != nil ? "Rust Core Ready" : "Binary Missing")
                        .font(.system(size: 11, weight: .medium))
                }
                Text(vm.isStreaming ? "Live stream: \(vm.streamIntervalMs)ms" : "Stream paused")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
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

    // MARK: - 1. Ghostty-Inspired Terminal Deck

    private var terminalDeckView: some View {
        VStack(spacing: 0) {
            // Command Prompt Header (Ghostty + Apple Minimalist)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text("❯")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)

                    TextField("Enter SierraPort command (e.g. list --exposed, inspect 5000 --probe, audit, check 80,443)...", text: $vm.commandInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .focused($isCommandFocused)
                        .onSubmit {
                            vm.submitCommand()
                        }
                        .onKeyPress(.upArrow) {
                            vm.historyUp()
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            vm.historyDown()
                            return .handled
                        }

                    if vm.isExecuting {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button("Run") {
                        vm.submitCommand()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(vm.commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isCommandFocused ? Color.cyan.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: 1)
                )

                // Quick Autocomplete / Suggestion Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(vm.autocompleteSuggestions, id: \.self) { suggestion in
                            Button {
                                vm.commandInput = suggestion
                                vm.submitCommand()
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(.primary.opacity(0.05), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)

            Divider().opacity(0.4)

            // Rich Command Output Blocks
            if vm.blocks.isEmpty {
                ContentUnavailableView(
                    "SierraPort Command Deck",
                    systemImage: "terminal",
                    description: Text("Type any SierraPort CLI command above to inspect ports visually.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.blocks) { block in
                            commandBlockCard(block)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func commandBlockCard(_ block: CommandBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Block Header
            HStack(spacing: 8) {
                Text("❯")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Text("sierraport \(block.command)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .textSelection(.enabled)

                Spacer()

                Text("\(block.durationMs)ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(block.timestamp, style: .time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    vm.toggleRaw(for: block.id)
                } label: {
                    Text(block.showRaw ? "Visual" : "Raw")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            Divider().opacity(0.35)

            if block.showRaw {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(block.rawOutput)
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            } else {
                switch block.payload {
                case .ports(let entries):
                    PortTableView(
                        entries: entries,
                        onInspect: { vm.inspectPort($0) },
                        onKill: { vm.killPort($0) }
                    )
                case .audit(let report):
                    AuditVisualView(report: report, onInspectPort: { vm.inspectPort($0) })
                case .inspect(let report):
                    InspectVisualView(report: report, onKill: { vm.killPort($0) })
                case .probe(let results):
                    ProbeResultsVisualView(results: results)
                case .stats(let stats):
                    StatsVisualView(stats: stats)
                case .diff(let diff):
                    DiffVisualView(diff: diff)
                case .freePorts(let free):
                    FreePortsVisualView(result: free)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - 2. Live Watch Dashboard

    private var liveWatchView: some View {
        VStack(spacing: 14) {
            // Controls Bar
            HStack(spacing: 12) {
                Button {
                    if vm.isStreaming { vm.stopLiveStream() } else { vm.startLiveStream() }
                } label: {
                    Label(vm.isStreaming ? "Pause" : "Resume", systemImage: vm.isStreaming ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Picker("Interval", selection: $vm.streamIntervalMs) {
                    Text("500ms").tag(500)
                    Text("1s").tag(1000)
                    Text("2s").tag(2000)
                    Text("5s").tag(5000)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .onChange(of: vm.streamIntervalMs) { _, _ in
                    vm.restartStreamWithSettings()
                }

                Toggle("All States", isOn: $vm.streamAllStates)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: vm.streamAllStates) { _, _ in
                        vm.restartStreamWithSettings()
                    }

                Spacer()

                if let tick = vm.latestTick {
                    Text("Tick #\(tick.tick) · UTC \(tick.timestampUtc)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // KPI Strip
            if let tick = vm.latestTick {
                HStack(spacing: 10) {
                    KpiPill(title: "Active", value: "\(tick.active)", tint: .primary)
                    KpiPill(title: "TCP / UDP", value: "\(tick.tcp) / \(tick.udp)", tint: .cyan)
                    KpiPill(title: "Exposed", value: "\(tick.exposed)", tint: tick.exposed > 0 ? .orange : .green)
                    KpiPill(title: "Opened", value: "+\(tick.openedTotal)", tint: .green)
                    KpiPill(title: "Closed", value: "-\(tick.closedTotal)", tint: .red)
                    KpiPill(title: "Scan Latency", value: "\(tick.scanMs)ms", tint: .secondary)
                }
                .padding(.horizontal, 16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let tick = vm.latestTick {
                        PortTableView(
                            entries: tick.entries,
                            onInspect: { vm.inspectPort($0) },
                            onKill: { vm.killPort($0) }
                        )
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                    ScopeBadge(scope: ev.scope)
                                    Spacer()
                                    Text(ev.process)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - 3. Security Audit Tab

    private var auditTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Security & Socket Health Audit")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button {
                        Task { await vm.refreshAudit() }
                    } label: {
                        Label("Re-run Audit", systemImage: "shield.checkerboard")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if vm.isLoadingAudit && vm.auditReport == nil {
                    ProgressView("Analyzing sockets...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let report = vm.auditReport {
                    AuditVisualView(report: report, onInspectPort: { vm.inspectPort($0) })
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(18)
        }
    }

    // MARK: - 4. Analytics Tab

    private var statsTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Socket & Exposure Analytics")
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Button {
                        Task { await vm.refreshStats() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if vm.isLoadingStats && vm.statsReport == nil {
                    ProgressView("Loading analytics...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let stats = vm.statsReport {
                    StatsVisualView(stats: stats)
                }
            }
            .padding(18)
        }
    }

    // MARK: - Right-Side Forensic Inspector Drawer

    private var inspectorDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Forensic Inspector", systemImage: "sparkle.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    vm.showingInspector = false
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
                    ProgressView("Probing & tracing ancestry...")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let report = vm.inspectedReport {
                    InspectVisualView(report: report, onKill: { vm.killPort($0) })
                        .padding(14)
                }
            }
        }
    }
}

// MARK: - macOS Menu Bar Quick Monitor

struct MenuBarView: View {
    @ObservedObject var vm: SierraPortViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SierraPort")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if let tick = vm.latestTick {
                    Text("\(tick.active) active · \(tick.exposed) exposed")
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
                            .foregroundStyle(.cyan)
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
                Text("No active listeners")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Open SierraPort") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
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
