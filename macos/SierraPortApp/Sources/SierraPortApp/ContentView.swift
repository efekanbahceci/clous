import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: SierraPortViewModel
    @Binding var themeRaw: String
    @FocusState private var isCommandFocused: Bool

    private var themePref: AppThemePreference {
        AppThemePreference(rawValue: themeRaw) ?? .dark
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .background(SierraTheme.sidebar)
        } detail: {
            ZStack(alignment: .bottom) {
                mainDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SierraTheme.canvas)

                if let msg = vm.statusMessage {
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(SierraTheme.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(SierraTheme.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(SierraTheme.canvas)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.statusMessage)
            .inspector(isPresented: $vm.showingInspector) {
                inspectorDrawer
                    .inspectorColumnWidth(min: 320, ideal: 360, max: 440)
            }
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
                                .contentTransition(.numericText())
                        }
                        if tick.exposed > 0 {
                            Text("\(tick.exposed) exposed")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.orange)
                                .contentTransition(.numericText())
                        }
                        Text("\(tick.scanMs)ms")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
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

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.showingInspector.toggle()
                    }
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .help("Toggle Forensic Inspector (⌥⌘I)")
            }
        }
        .onAppear {
            isCommandFocused = true
        }
        .background {
            // Hidden global keyboard shortcuts for mouse-free tab switching (⌘1–⌘4)
            Group {
                Button("") { vm.selectedTab = .terminal; isCommandFocused = true }
                    .keyboardShortcut("1", modifiers: .command)
                Button("") { vm.selectedTab = .watch }
                    .keyboardShortcut("2", modifiers: .command)
                Button("") { vm.selectedTab = .audit }
                    .keyboardShortcut("3", modifiers: .command)
                Button("") { vm.selectedTab = .stats }
                    .keyboardShortcut("4", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
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
            .scrollContentBackground(.hidden)

            Divider().opacity(0.4)

            // Theme Switcher (Dark #111110 / Light / System)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(AppThemePreference.allCases) { pref in
                        let isSelected = themePref == pref
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                themeRaw = pref.rawValue
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: pref.icon)
                                    .font(.system(size: 9))
                                Text(pref.rawValue)
                                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                isSelected ? SierraTheme.surfaceElevated : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(isSelected ? SierraTheme.border : Color.clear, lineWidth: 1)
                            )
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(SierraTheme.canvas.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
        .background(SierraTheme.sidebar)
        .navigationSplitViewColumnWidth(min: 195, ideal: 215, max: 245)
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
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.18), Color.blue.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.cyan.opacity(0.32), lineWidth: 1)
                        )
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .primary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Sierra")
                            .font(.system(size: 36, weight: .semibold, design: .default))
                            .tracking(-1.0)
                        Text("Port")
                            .font(.system(size: 36, weight: .light, design: .default))
                            .tracking(-1.0)
                            .foregroundStyle(.secondary)
                    }
                    Text("COMMAND DECK")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2.2)
                        .foregroundStyle(.secondary)
                }

                Text("Run any SierraPort CLI command to inspect listening ports, audit external exposure, trace process ancestry, or grab live protocol banners — rendered as clean, collapsible visual cards.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 500)
            }
            .padding(.bottom, 34)

            // Centered, Narrower Command Input Box (Positioned Lower)
            commandInputField
                .frame(maxWidth: 600)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)

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

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 8)], spacing: 8) {
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
                            Text(vm.focusedResultIndex != nil ? "⏎ inspect · Tab/↑↓ row · Esc back" : "Tab / ↓ browse rows")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(vm.focusedResultIndex != nil ? .cyan : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    vm.focusedResultIndex != nil ? Color.cyan.opacity(0.12) : SierraTheme.surface,
                                    in: Capsule()
                                )
                        }

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                vm.expandAllBlocks()
                            }
                        } label: {
                            Image(systemName: "rectangle.expand.vertical")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Expand All Command Blocks")

                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                vm.collapseAllBlocks()
                            }
                        } label: {
                            Image(systemName: "rectangle.compress.vertical")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Collapse All Command Blocks")

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                vm.blocks.removeAll()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Clear Terminal Deck")
                    }
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(hasError ? .red : .cyan)

                TextField("Type a command or plain English (e.g. 5000, close 3000, exposed, security scan, free port)...", text: $vm.commandInput)
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

                Button("Run") {
                    vm.submitCommand()
                }
                .buttonStyle(.borderedProminent)
                .tint(hasError ? .red : .accentColor)
                .controlSize(.small)
                .disabled(vm.commandInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(SierraTheme.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        hasError
                            ? Color.red.opacity(0.75)
                            : (isCommandFocused ? Color.cyan.opacity(0.55) : SierraTheme.border),
                        lineWidth: hasError ? 1.5 : 1
                    )
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
                        .foregroundStyle(isKeyboardFocused ? .cyan : .cyan.opacity(0.8))
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
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, fullWidth ? 8 : 5)
            .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
            .background(
                (isHighlighted ? Color.cyan.opacity(0.18) : SierraTheme.surface),
                in: RoundedRectangle(cornerRadius: fullWidth ? 9 : 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: fullWidth ? 9 : 14, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? Color.cyan.opacity(0.75) : SierraTheme.border,
                        lineWidth: isKeyboardFocused ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func commandBlockCard(_ block: CommandBlock) -> some View {
        let isNewlyOpened = vm.highlightedBlockId == block.id
        return VStack(alignment: .leading, spacing: 0) {
            // Clickable Collapsible Header Bar
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isNewlyOpened ? .cyan : .secondary)
                    .rotationEffect(.degrees(block.isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: block.isExpanded)
                    .frame(width: 14)

                Text("❯")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)

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
                    .foregroundStyle(.cyan)
                    .background(.cyan.opacity(0.12), in: Capsule())
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
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    vm.toggleExpand(for: block.id)
                }
            }

            if block.isExpanded {
                Divider().opacity(0.35)

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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isNewlyOpened
                        ? Color.cyan.opacity(0.65)
                        : (block.isExpanded ? SierraTheme.border : SierraTheme.borderSubtle),
                    lineWidth: isNewlyOpened ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.25), value: isNewlyOpened)
    }

    // MARK: - 2. Live Watch Dashboard

    private var liveWatchView: some View {
        VStack(spacing: 12) {
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
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            if let tick = vm.latestTick {
                HStack(spacing: 10) {
                    KpiPill(title: "Active", value: "\(tick.active)", tint: .primary, icon: "network")
                    KpiPill(title: "TCP / UDP", value: "\(tick.tcp) / \(tick.udp)", tint: .cyan, icon: "arrow.left.arrow.right")
                    KpiPill(title: "Exposed", value: "\(tick.exposed)", tint: tick.exposed > 0 ? .orange : .green, icon: "globe")
                    KpiPill(title: "Opened", value: "+\(tick.openedTotal)", tint: .green, icon: "plus.circle")
                    KpiPill(title: "Closed", value: "-\(tick.closedTotal)", tint: .red, icon: "minus.circle")
                    KpiPill(title: "Scan", value: "\(tick.scanMs)ms", tint: .secondary, icon: "speedometer")
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
                        Text("Security & Binary Trust Audit")
                            .font(.system(size: 18, weight: .semibold))
                        Text("macOS firewall posture, code-signature verification, active probing, and remediation playbooks")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Picker("Profile", selection: $vm.auditProfile) {
                        ForEach(AuditProfileOption.allCases) { opt in
                            Text(opt.label).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                    .onChange(of: vm.auditProfile) { _, _ in
                        Task { await vm.refreshAudit() }
                    }

                    Toggle("Deep Probe", isOn: $vm.auditDeepScan)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: vm.auditDeepScan) { _, _ in
                            Task { await vm.refreshAudit() }
                        }

                    Button {
                        vm.exportAuditMarkdown()
                    } label: {
                        Label("Export MD", systemImage: "square.and.arrow.up")
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
                            Label("Scan", systemImage: "shield.checkerboard")
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
                        Text("Socket & Exposure Analytics")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Real-time telemetry, bind exposure breakdown, and process activity")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Toggle("Live Sync", isOn: $vm.liveAnalyticsEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)

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
                Label("Forensic Inspector", systemImage: "sparkle.magnifyingglass")
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
                    ProgressView("Probing & tracing ancestry...")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let report = vm.inspectedReport {
                    InspectVisualView(report: report, onKill: { vm.killPort($0) })
                        .padding(14)
                } else {
                    ContentUnavailableView(
                        "No Port Selected",
                        systemImage: "sparkle.magnifyingglass",
                        description: Text("Click any row in a port table to inspect its process ancestry and live banner.")
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
