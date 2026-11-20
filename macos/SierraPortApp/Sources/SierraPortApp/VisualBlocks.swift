import SwiftUI
import AppKit
import Charts

// MARK: - Badges

struct ScopeBadge: View {
    let scope: String

    var color: Color {
        switch scope {
        case "LOCAL": return .green
        case "LAN": return .cyan
        case "ALL(*)": return .orange
        case "PUBLIC": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(scope)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct StateBadge: View {
    let state: String

    var color: Color {
        switch state {
        case "LISTEN": return .green
        case "ESTABLISHED": return .blue
        case "TIME_WAIT", "CLOSE_WAIT": return .orange
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(state)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

struct KpiPill: View {
    let title: String
    let value: String
    let tint: Color
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.85))
                }
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Live Real-Time Activity Sparkline

struct LiveSparklineView: View {
    let history: [TickHistoryPoint]
    var height: CGFloat = 115

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Live Socket Activity", systemImage: "waveform.path.ecg")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let last = history.last {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Circle().fill(.cyan).frame(width: 6, height: 6)
                            Text("Active: \(last.active)")
                        }
                        HStack(spacing: 4) {
                            Circle().fill(.orange).frame(width: 6, height: 6)
                            Text("Exposed: \(last.exposed)")
                        }
                        Text("\(last.scanMs)ms")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .contentTransition(.numericText())
                }
            }

            if history.count < 2 {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Collecting live telemetry...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: height)
            } else {
                let minTick = history.first?.tick ?? 0
                let maxTick = max((history.last?.tick ?? 1), minTick + 1)
                let maxVal = max(history.map(\.active).max() ?? 10, 5)
                let yTop = maxVal + max(2, maxVal / 5)

                Chart {
                    ForEach(history) { pt in
                        AreaMark(
                            x: .value("Tick", pt.tick),
                            yStart: .value("Zero", 0),
                            yEnd: .value("Active", pt.active),
                            series: .value("Series", "ActiveArea")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.24), Color.cyan.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Tick", pt.tick),
                            y: .value("Active", pt.active),
                            series: .value("Series", "Active")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.cyan)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        LineMark(
                            x: .value("Tick", pt.tick),
                            y: .value("Exposed", pt.exposed),
                            series: .value("Series", "Exposed")
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1.75, dash: [4, 3]))
                    }
                }
                .chartXScale(domain: minTick...maxTick)
                .chartYScale(domain: 0...yTop)
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(.primary.opacity(0.08))
                        AxisValueLabel()
                            .font(.system(size: 9, design: .monospaced))
                    }
                }
                .frame(height: height)
            }
        }
        .padding(14)
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Interactive Port Table (Zero Overlap, Sortable, Horizontally Safe)

enum TableSortColumn: String {
    case proto, port, state, pid, mem, process
}

struct PortTableView: View {
    let entries: [PortEntry]
    var tableId: String = "ports"
    var selectedRowKey: String? = nil
    var focusedRowIndex: Int? = nil
    let onInspect: (Int, String) -> Void
    let onKill: (Int) -> Void

    @State private var filterText: String = ""
    @State private var sortCol: TableSortColumn = .port
    @State private var sortAsc: Bool = true

    private var displayed: [PortEntry] {
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = q.isEmpty ? entries : entries.filter { e in
            "\(e.localPort)".contains(q)
                || e.protocolName.lowercased().contains(q)
                || e.bindScope.lowercased().contains(q)
                || (e.process?.lowercased().contains(q) ?? false)
                || (e.service?.lowercased().contains(q) ?? false)
                || (e.user?.lowercased().contains(q) ?? false)
                || (e.cmdline?.lowercased().contains(q) ?? false)
        }

        return base.sorted { a, b in
            let less: Bool
            switch sortCol {
            case .proto:
                less = a.protocolName == b.protocolName ? a.localPort < b.localPort : a.protocolName < b.protocolName
            case .port:
                less = a.localPort == b.localPort ? a.protocolName < b.protocolName : a.localPort < b.localPort
            case .state:
                less = a.state == b.state ? a.localPort < b.localPort : a.state < b.state
            case .pid:
                less = (a.pid ?? Int.max) < (b.pid ?? Int.max)
            case .mem:
                less = (a.memoryKb ?? 0) < (b.memoryKb ?? 0)
            case .process:
                less = (a.process ?? "~").lowercased() < (b.process ?? "~").lowercased()
            }
            return sortAsc ? less : !less
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entries.count > 6 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter ports, processes, users, scopes...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !filterText.isEmpty {
                        Button { filterText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Text("\(displayed.count) / \(entries.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }

            if displayed.isEmpty {
                Text("No matching sockets.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Horizontal scroll safety prevents columns from ever overlapping when Inspector opens
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            sortHeader("PROTO", col: .proto, width: 46, alignment: .leading)
                            sortHeader("PORT", col: .port, width: 58, alignment: .leading)
                            Text("SCOPE")
                                .frame(width: 64, alignment: .leading)
                            Text("LOCAL")
                                .frame(width: 146, alignment: .leading)
                            sortHeader("STATE", col: .state, width: 102, alignment: .leading)
                            sortHeader("PID", col: .pid, width: 56, alignment: .leading)
                            sortHeader("MEM", col: .mem, width: 56, alignment: .trailing)
                            sortHeader("PROCESS", col: .process, width: 170, alignment: .leading)
                            Text("ACTIONS")
                                .frame(width: 60, alignment: .trailing)
                        }
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)

                        Divider().opacity(0.4)

                        LazyVStack(spacing: 2) {
                            ForEach(Array(displayed.prefix(200).enumerated()), id: \.offset) { idx, entry in
                                let rowKey = "\(tableId)-\(idx)"
                                PortRowView(
                                    entry: entry,
                                    isSelected: selectedRowKey == rowKey,
                                    isKeyboardFocused: focusedRowIndex == idx,
                                    onInspect: { port in onInspect(port, rowKey) },
                                    onKill: onKill
                                )
                                .id("port-row-\(idx)")
                            }
                        }
                    }
                    .frame(minWidth: 838, alignment: .leading)
                }
            }
        }
    }

    private func sortHeader(_ title: String, col: TableSortColumn, width: CGFloat, alignment: Alignment) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if sortCol == col {
                    sortAsc.toggle()
                } else {
                    sortCol = col
                    sortAsc = col != .mem
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortCol == col {
                    Image(systemName: sortAsc ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.cyan)
                }
            }
            .frame(width: width, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PortRowView: View {
    let entry: PortEntry
    let isSelected: Bool
    var isKeyboardFocused: Bool = false
    let onInspect: (Int) -> Void
    let onKill: (Int) -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.protocolName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 46, alignment: .leading)
                .clipped()

            Text("\(entry.localPort)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan)
                .lineLimit(1)
                .frame(width: 58, alignment: .leading)
                .clipped()

            ScopeBadge(scope: entry.bindScope)
                .frame(width: 64, alignment: .leading)
                .clipped()

            Text(entry.localEndpoint)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 146, alignment: .leading)
                .clipped()

            StateBadge(state: entry.state)
                .frame(width: 102, alignment: .leading)
                .clipped()

            Text(entry.pid.map(String.init) ?? "-")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 56, alignment: .leading)
                .clipped()

            Text(entry.memoryHuman)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 56, alignment: .trailing)
                .clipped()

            HStack(spacing: 5) {
                Text(entry.process ?? "-")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let svc = entry.service {
                    Text(svc)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let tag = entry.runtime {
                    Text(tag)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .foregroundStyle(.purple)
                        .background(.purple.opacity(0.14), in: Capsule())
                }
            }
            .frame(width: 170, alignment: .leading)
            .clipped()

            HStack(spacing: 8) {
                if isKeyboardFocused {
                    Text("⏎")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan)
                }
                Button {
                    onInspect(entry.localPort)
                } label: {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle((isSelected || isKeyboardFocused) ? .cyan : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Deep Inspect & Probe Port \(entry.localPort)")

                if entry.pid != nil {
                    Button {
                        onKill(entry.localPort)
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.borderless)
                    .help("Terminate Process on Port \(entry.localPort)")
                }
            }
            .frame(width: 68, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    isKeyboardFocused
                        ? Color.cyan.opacity(0.18)
                        : (isSelected ? Color.cyan.opacity(0.11) : (isHovered ? SierraTheme.rowHover : Color.clear))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    isKeyboardFocused
                        ? Color.cyan.opacity(0.75)
                        : (isSelected ? Color.cyan.opacity(0.35) : Color.clear),
                    lineWidth: isKeyboardFocused ? 1.5 : 1
                )
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onInspect(entry.localPort) }
    }
}

// MARK: - Security & Binary Trust Audit View

struct AuditVisualView: View {
    let report: AuditReport
    var allowlistedKeys: Set<String> = []
    let onInspectPort: (Int) -> Void
    var onAllowlist: ((AuditFinding) -> Void)? = nil
    var onRestoreAllowlist: ((String) -> Void)? = nil

    @State private var showBinaryTrusts: Bool = true
    @State private var showAcceptedRisks: Bool = false
    @State private var copiedCmdId: String? = nil

    private var activeFindings: [AuditFinding] {
        report.findings.filter { !allowlistedKeys.contains($0.allowlistKey) }
    }

    private var suppressedFindings: [AuditFinding] {
        report.findings.filter { allowlistedKeys.contains($0.allowlistKey) }
    }

    private var effectiveScore: Int {
        let penalty = activeFindings.reduce(0) { $0 + $1.penalty }
        return max(0, 100 - penalty)
    }

    private var effectiveGrade: String {
        switch effectiveScore {
        case 90...100: return "A"
        case 80...89: return "B"
        case 70...79: return "C"
        case 55...69: return "D"
        default: return "F"
        }
    }

    var scoreColor: Color {
        switch effectiveScore {
        case 90...100: return .green
        case 70...89: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. Score Ring + Summary Header
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.18), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(effectiveScore) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.55, dampingFraction: 0.8), value: effectiveScore)
                    VStack(spacing: 0) {
                        Text("\(effectiveScore)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("Grade \(effectiveGrade)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(scoreColor)
                    }
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Security & Binary Trust")
                            .font(.system(size: 16, weight: .semibold))
                        if let prof = report.profile {
                            Text(prof.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.cyan.opacity(0.14), in: Capsule())
                                .foregroundStyle(.cyan)
                        }
                        if report.deepScan == true {
                            Text("DEEP PROBE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.16), in: Capsule())
                                .foregroundStyle(.purple)
                        }
                    }

                    HStack(spacing: 16) {
                        Label("\(report.totalSockets) Sockets", systemImage: "network")
                        Label("\(report.listeningCount) Listening", systemImage: "ear")
                        Label("\(report.exposedCount) Exposed", systemImage: "globe")
                            .foregroundStyle(report.exposedCount > 0 ? .orange : .green)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // 2. Host Defense Posture Strip (Firewall, Stealth, Binary Trust, Policy)
            if let posture = report.posture {
                HStack(spacing: 10) {
                    let fwOn = posture.firewallEnabled == true
                    let fwKnown = posture.firewallEnabled != nil
                    KpiPill(
                        title: "macOS Firewall",
                        value: fwKnown ? (fwOn ? "ON" : "OFF") : "N/A",
                        tint: fwKnown ? (fwOn ? .green : .red) : .secondary,
                        icon: fwOn ? "flame.fill" : "exclamationmark.shield"
                    )

                    let stOn = posture.stealthMode == true
                    let stKnown = posture.stealthMode != nil
                    KpiPill(
                        title: "Stealth Mode",
                        value: stKnown ? (stOn ? "ON" : "OFF") : "N/A",
                        tint: stKnown ? (stOn ? .green : .orange) : .secondary,
                        icon: "eye.slash.fill"
                    )

                    KpiPill(
                        title: "Signed Binaries",
                        value: "\(posture.verifiedBinaries) / \(posture.verifiedBinaries + posture.unsignedBinaries)",
                        tint: posture.unsignedBinaries == 0 ? .green : .orange,
                        icon: "checkmark.seal.fill"
                    )

                    KpiPill(
                        title: "Allowlisted",
                        value: "\(suppressedFindings.count)",
                        tint: .cyan,
                        icon: "checkmark.circle"
                    )
                }
            }

            // 3. Active Security Findings with Remediation Playbook & Allowlist
            if activeFindings.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("No active security or binary trust issues under this profile.")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIVE FINDINGS (\(activeFindings.count))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(activeFindings.enumerated()), id: \.offset) { _, finding in
                        let sevColor = severityColor(finding.severity)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(finding.severity)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(sevColor)
                                    .background(sevColor.opacity(0.16), in: Capsule())
                                    .fixedSize()

                                Text(finding.code)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()

                                Text(finding.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 6)

                                if let port = finding.port {
                                    Button("Inspect :\(port)") {
                                        onInspectPort(port)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }

                                if let onAllowlist {
                                    Button {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                            onAllowlist(finding)
                                        }
                                    } label: {
                                        Text("Accept Risk")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help("Allowlist this finding under your local security policy")
                                }
                            }

                            Text(finding.recommendation)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let remCmd = finding.remediationCmd {
                                HStack(spacing: 8) {
                                    Text(remCmd)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                    Spacer(minLength: 4)
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(remCmd, forType: .string)
                                        copiedCmdId = finding.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            if copiedCmdId == finding.id { copiedCmdId = nil }
                                        }
                                    } label: {
                                        Label(
                                            copiedCmdId == finding.id ? "Copied" : "Copy Fix",
                                            systemImage: copiedCmdId == finding.id ? "checkmark" : "doc.on.doc"
                                        )
                                        .font(.system(size: 10, weight: .medium))
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(SierraTheme.codeWell, in: RoundedRectangle(cornerRadius: 7))
                                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(SierraTheme.borderSubtle, lineWidth: 1))
                            }
                        }
                        .padding(12)
                        .background(SierraTheme.surfaceElevated.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(sevColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
            }

            // 4. Collapsible Binary Code-Signature & Origin Trust Table
            if let trusts = report.binaryTrusts, !trusts.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showBinaryTrusts ? 90 : 0))
                        Label("Listening Binary Code-Signature Trust (\(trusts.count))", systemImage: "checkmark.seal")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text("macOS codesign verification")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            showBinaryTrusts.toggle()
                        }
                    }

                    if showBinaryTrusts {
                        Divider().opacity(0.35)
                        VStack(spacing: 6) {
                            ForEach(Array(trusts.enumerated()), id: \.offset) { _, b in
                                HStack(spacing: 10) {
                                    trustBadge(b.trust, suspicious: b.suspiciousPath)
                                        .frame(width: 112, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(b.process)
                                                .font(.system(size: 12, weight: .semibold))
                                                .lineLimit(1)
                                            if let auth = b.authority {
                                                Text(auth)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Text(b.path)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer(minLength: 6)

                                    Text(b.ports.map { ":\($0)" }.joined(separator: " "))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(SierraTheme.canvas.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
                            }
                        }
                        .padding(10)
                    }
                }
                .background(SierraTheme.surfaceElevated.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(SierraTheme.border, lineWidth: 1))
            }

            // 5. Collapsible Accepted Risks / Allowlist
            if !suppressedFindings.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showAcceptedRisks ? 90 : 0))
                        Text("Accepted Risks / Allowlist (\(suppressedFindings.count))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(10)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            showAcceptedRisks.toggle()
                        }
                    }

                    if showAcceptedRisks {
                        Divider().opacity(0.35)
                        VStack(spacing: 6) {
                            ForEach(Array(suppressedFindings.enumerated()), id: \.offset) { _, f in
                                HStack(spacing: 8) {
                                    Text(f.code)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(f.title)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    if let onRestoreAllowlist {
                                        Button("Restore") {
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                                onRestoreAllowlist(f.allowlistKey)
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.mini)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                            }
                        }
                        .padding(8)
                    }
                }
                .background(SierraTheme.surfaceElevated.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(SierraTheme.borderSubtle, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func trustBadge(_ trust: String, suspicious: Bool) -> some View {
        let (label, color): (String, Color) = suspicious
            ? ("SUSPICIOUS", .red)
            : {
                switch trust {
                case "APPLE_SIGNED": return ("APPLE SIGNED", .green)
                case "DEVELOPER_SIGNED": return ("DEVELOPER ID", .cyan)
                case "AD_HOC": return ("AD-HOC", .orange)
                case "UNSIGNED": return ("UNSIGNED", .red)
                default: return ("UNKNOWN", .secondary)
                }
            }()
        Text(label)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
            .fixedSize()
    }

    private func severityColor(_ sev: String) -> Color {
        switch sev {
        case "CRITICAL", "HIGH": return .red
        case "MEDIUM": return .orange
        case "LOW": return .cyan
        default: return .secondary
        }
    }
}

// MARK: - Deep Forensic Inspect View

struct InspectVisualView: View {
    let report: InspectReport
    let onKill: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Port \(report.port)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        if let svc = report.service {
                            Text(svc)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.cyan.opacity(0.15), in: Capsule())
                                .foregroundStyle(.cyan)
                        }
                    }
                    Text("\(report.sockets.count) binding(s) · \(report.activePeers) active peer connection(s)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !report.sockets.isEmpty {
                    Button(role: .destructive) {
                        onKill(report.port)
                    } label: {
                        Label("Kill Port", systemImage: "xmark.octagon")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let probe = report.probe {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Label(probe.open ? "OPEN" : "CLOSED", systemImage: probe.open ? "bolt.circle.fill" : "bolt.slash.circle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(probe.open ? .green : .red)
                        Text(String(format: "%.2f ms", probe.latencyMs))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if let proto = probe.detectedProtocol {
                            Text(proto)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }
                    if let banner = probe.banner {
                        Text(banner)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .textSelection(.enabled)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            if !report.ancestry.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROCESS ANCESTRY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(report.ancestry.enumerated()), id: \.offset) { idx, node in
                            HStack(spacing: 6) {
                                if idx > 0 {
                                    Text(String(repeating: "  ", count: min(idx, 5)) + "└─")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                } else {
                                    Circle()
                                        .fill(.cyan)
                                        .frame(width: 7, height: 7)
                                }
                                Text(node.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("PID \(node.pid)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                                if let user = node.user {
                                    Text("(\(user))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            if !report.sockets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("BINDINGS (\(report.sockets.count))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Click to expand")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 8) {
                        ForEach(Array(report.sockets.enumerated()), id: \.offset) { _, sock in
                            BindingCardView(sock: sock)
                        }
                    }
                }
            }
        }
    }
}

struct BindingCardView: View {
    let sock: InspectSocket
    @State private var isExpanded: Bool = false
    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clickable Header
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)

                    Text(sock.protocolName)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .fixedSize()

                    Text(sock.local)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 4)

                    ScopeBadge(scope: sock.scope)
                }

                HStack(spacing: 8) {
                    StateBadge(state: sock.state)
                    if let pid = sock.pid {
                        Text("PID \(pid)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    Spacer(minLength: 4)
                    if let user = sock.user {
                        Text(user)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if sock.memoryKb != nil {
                        Text(sock.memoryHuman)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }

                if !isExpanded, let cmd = sock.cmdline {
                    Text(cmd)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                Divider().opacity(0.35)

                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Local", sock.local)
                    detailRow("Remote", sock.remote)
                    if let proc = sock.process {
                        detailRow("Process", proc)
                    }
                    if let pid = sock.pid {
                        detailRow("PID", "\(pid)")
                    }
                    if let user = sock.user {
                        detailRow("User", user)
                    }
                    if sock.memoryKb != nil {
                        detailRow("Memory", sock.memoryHuman)
                    }

                    if let cmd = sock.cmdline {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("COMMAND")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(cmd, forType: .string)
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        copied = false
                                    }
                                } label: {
                                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.borderless)
                            }
                            Text(cmd)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(SierraTheme.codeWell, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(SierraTheme.borderSubtle, lineWidth: 1))
                        }
                    }
                }
                .padding(10)
                .transition(.opacity)
            }
        }
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(isExpanded ? Color.cyan.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Probe Check Results View

struct ProbeResultsVisualView: View {
    let results: [ProbeResult]

    var body: some View {
        let openCount = results.filter(\.open).count
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Label("\(openCount) Open", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(results.count - openCount) Closed", systemImage: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12, weight: .semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 8)], spacing: 8) {
                ForEach(results) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(":\(r.port)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(r.open ? .green : .secondary)
                            if let svc = r.detectedProtocol ?? r.service {
                                Text(svc)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.primary.opacity(0.08), in: Capsule())
                            }
                            Spacer()
                            Text(String(format: "%.1fms", r.latencyMs))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        if let banner = r.banner {
                            Text(banner)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .lineLimit(1)
                        }
                    }
                    .padding(10)
                    .background(
                        (r.open ? Color.green.opacity(0.08) : Color.primary.opacity(0.03)),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(r.open ? Color.green.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
        }
    }
}

// MARK: - Dynamic Native Swift Charts Analytics View

struct ChartDatum: Identifiable {
    let label: String
    let value: Int
    var id: String { label }
}

struct StatsVisualView: View {
    let stats: StatsReport
    var history: [TickHistoryPoint] = []
    var onSelectProcess: ((String) -> Void)? = nil

    @State private var hoveredProc: String? = nil

    private var protoData: [ChartDatum] {
        stats.byProtocol.map { ChartDatum(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    private var stateData: [ChartDatum] {
        stats.byState.map { ChartDatum(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    private var scopeData: [ChartDatum] {
        stats.listeningByScope.map { ChartDatum(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    private var totalListening: Int {
        scopeData.reduce(0) { $0 + $1.value }
    }

    private var exposedCount: Int {
        (stats.listeningByScope["ALL(*)"] ?? 0) + (stats.listeningByScope["PUBLIC"] ?? 0)
    }

    private var exposurePercent: Int {
        guard totalListening > 0 else { return 0 }
        return Int((Double(exposedCount) / Double(totalListening)) * 100.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Dynamic KPI Strip
            HStack(spacing: 10) {
                KpiPill(title: "Total Sockets", value: "\(stats.total)", tint: .primary, icon: "network")
                KpiPill(title: "Listening", value: "\(totalListening)", tint: .green, icon: "ear")
                KpiPill(title: "Exposure Ratio", value: "\(exposurePercent)%", tint: exposurePercent > 50 ? .orange : .cyan, icon: "globe")
                KpiPill(title: "Top Processes", value: "\(stats.topProcesses.count)", tint: .purple, icon: "cpu")
            }

            // Live Activity Sparkline (if stream history is provided)
            if !history.isEmpty {
                LiveSparklineView(history: history, height: 110)
            }

            // Two-Column Rich Dynamic Charts
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                // 1. Donut Chart for Bind Exposure
                exposureDonutCard

                // 2. Protocol Breakdown with Animated Ratio Bars
                protocolBreakdownCard

                // 3. Socket State Bar Chart
                stateChartCard

                // 4. Interactive Top Processes Leaderboard
                topProcessesCard
            }
        }
    }

    private var exposureDonutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Listening Bind Exposure", systemImage: "shield.lefthalf.filled")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(totalListening) total")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if scopeData.isEmpty {
                Text("No listening sockets.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
            } else {
                HStack(spacing: 18) {
                    ZStack {
                        Chart(scopeData) { item in
                            SectorMark(
                                angle: .value("Count", item.value),
                                innerRadius: .ratio(0.62),
                                angularInset: 2
                            )
                            .cornerRadius(4)
                            .foregroundStyle(scopeColor(item.label).gradient)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 130, height: 130)

                        VStack(spacing: 1) {
                            Text("\(exposedCount)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(exposedCount > 0 ? .orange : .green)
                                .contentTransition(.numericText())
                            Text("EXPOSED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(scopeData) { item in
                            let pct = totalListening > 0 ? Int(round(Double(item.value) / Double(totalListening) * 100)) : 0
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(scopeColor(item.label))
                                    .frame(width: 8, height: 8)
                                Text(item.label)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                Spacer()
                                Text("\(item.value)")
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                Text("(\(pct)%)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
    }

    private var protocolBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Protocol Distribution", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(protoData.count) types")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            let maxVal = max(protoData.first?.value ?? 1, 1)
            VStack(spacing: 10) {
                ForEach(protoData) { item in
                    let pct = stats.total > 0 ? Int(round(Double(item.value) / Double(stats.total) * 100)) : 0
                    let ratio = CGFloat(item.value) / CGFloat(maxVal)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.label)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Spacer()
                            Text("\(item.value) sockets · \(pct)%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.primary.opacity(0.08))
                                Capsule()
                                    .fill(protoColor(item.label).gradient)
                                    .frame(width: max(6, geo.size.width * ratio))
                                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: item.value)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
    }

    private var stateChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Socket Lifecycle States", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))

            if stateData.isEmpty {
                Text("No state data").font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                let maxStateVal = max(stateData.map(\.value).max() ?? 1, 1)
                let xUpper = maxStateVal + max(2, maxStateVal / 4)

                Chart(stateData) { item in
                    BarMark(
                        x: .value("Count", item.value),
                        y: .value("State", item.label)
                    )
                    .foregroundStyle(stateColor(item.label).gradient)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text("\(item.value)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXScale(domain: 0...xUpper)
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .frame(height: max(120, CGFloat(stateData.count) * 28))
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
    }

    private var topProcessesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Top Processes by Sockets", systemImage: "bolt.horizontal.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if onSelectProcess != nil {
                    Text("Click to filter")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            let maxProc = max(stats.topProcesses.first?.count ?? 1, 1)
            VStack(spacing: 6) {
                ForEach(stats.topProcesses.prefix(8)) { proc in
                    let ratio = CGFloat(proc.count) / CGFloat(maxProc)
                    let isHov = hoveredProc == proc.name
                    Button {
                        onSelectProcess?(proc.name)
                    } label: {
                        HStack(spacing: 10) {
                            Text(proc.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(width: 110, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.primary.opacity(0.07))
                                    Capsule()
                                        .fill(Color.purple.gradient)
                                        .frame(width: max(6, geo.size.width * ratio))
                                }
                            }
                            .frame(height: 8)

                            Text("\(proc.count)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isHov ? Color.purple.opacity(0.12) : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveredProc = $0 ? proc.name : nil }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(SierraTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(SierraTheme.border, lineWidth: 1)
        )
    }

    private func scopeColor(_ s: String) -> Color {
        switch s {
        case "LOCAL": return .green
        case "LAN": return .cyan
        case "ALL(*)": return .orange
        case "PUBLIC": return .red
        default: return .secondary
        }
    }

    private func protoColor(_ p: String) -> Color {
        switch p {
        case "TCP": return .cyan
        case "TCP6": return .blue
        case "UDP": return .teal
        case "UDP6": return .indigo
        default: return .secondary
        }
    }

    private func stateColor(_ s: String) -> Color {
        switch s {
        case "LISTEN": return .green
        case "ESTABLISHED": return .cyan
        case "TIME_WAIT", "CLOSE_WAIT": return .orange
        default: return .secondary
        }
    }
}

// MARK: - Baseline Drift Diff View

struct DiffVisualView: View {
    let diff: DiffReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !diff.hasDrift {
                Label("No drift detected (\(diff.unchangedCount) port(s) unchanged)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13, weight: .medium))
            } else {
                HStack(spacing: 12) {
                    Text("+\(diff.added.count) added").foregroundStyle(.green)
                    Text("-\(diff.removed.count) removed").foregroundStyle(.red)
                    Text("~\(diff.changed.count) changed").foregroundStyle(.orange)
                    Text("\(diff.unchangedCount) unchanged").foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))

                ForEach(diff.added) { e in
                    HStack {
                        Text("+ ADDED").foregroundStyle(.green).font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("\(e.protocolName) \(e.localAddr):\(e.localPort)").font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Text(e.process ?? "-").foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                ForEach(diff.removed) { e in
                    HStack {
                        Text("- REMOVED").foregroundStyle(.red).font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("\(e.protocolName) \(e.localAddr):\(e.localPort)").font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Text(e.process ?? "-").foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                ForEach(diff.changed) { c in
                    HStack {
                        Text("~ CHANGED").foregroundStyle(.orange).font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("\(c.protocolName) :\(c.localPort)").font(.system(size: 12, design: .monospaced))
                        Text(c.changes).font(.system(size: 12)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(8)
                    .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

// MARK: - Free Ports View

struct FreePortsVisualView: View {
    let result: FreePortsResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available TCP Ports on \(result.host)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(result.freePorts, id: \.self) { port in
                    Text("\(port)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.green)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
