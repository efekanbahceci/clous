import SwiftUI
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
        }
    }
}

struct KpiPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Interactive Port Table

struct PortTableView: View {
    let entries: [PortEntry]
    let onInspect: (Int) -> Void
    let onKill: (Int) -> Void
    @State private var filterText: String = ""

    var filtered: [PortEntry] {
        let q = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return entries }
        return entries.filter { e in
            "\(e.localPort)".contains(q)
                || e.protocolName.lowercased().contains(q)
                || e.bindScope.lowercased().contains(q)
                || (e.process?.lowercased().contains(q) ?? false)
                || (e.service?.lowercased().contains(q) ?? false)
                || (e.user?.lowercased().contains(q) ?? false)
                || (e.cmdline?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if entries.count > 8 {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Filter ports, processes, users...", text: $filterText)
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
                    Text("\(filtered.count) / \(entries.count)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            }

            if filtered.isEmpty {
                Text("No matching sockets.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                // Header
                HStack(spacing: 10) {
                    Text("PROTO").frame(width: 44, alignment: .leading)
                    Text("PORT").frame(width: 56, alignment: .leading)
                    Text("SCOPE").frame(width: 64, alignment: .leading)
                    Text("LOCAL").frame(width: 148, alignment: .leading)
                    Text("STATE").frame(width: 98, alignment: .leading)
                    Text("PID").frame(width: 54, alignment: .leading)
                    Text("MEM").frame(width: 56, alignment: .trailing)
                    Text("PROCESS").frame(maxWidth: .infinity, alignment: .leading)
                    Text("ACTIONS").frame(width: 64, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

                Divider().opacity(0.4)

                LazyVStack(spacing: 2) {
                    ForEach(filtered.prefix(200)) { entry in
                        PortRowView(entry: entry, onInspect: onInspect, onKill: onKill)
                    }
                }
            }
        }
    }
}

struct PortRowView: View {
    let entry: PortEntry
    let onInspect: (Int) -> Void
    let onKill: (Int) -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.protocolName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            Text("\(entry.localPort)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan)
                .frame(width: 56, alignment: .leading)

            ScopeBadge(scope: entry.bindScope)
                .frame(width: 64, alignment: .leading)

            Text(entry.localEndpoint)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 148, alignment: .leading)

            StateBadge(state: entry.state)
                .frame(width: 98, alignment: .leading)

            Text(entry.pid.map(String.init) ?? "-")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Text(entry.memoryHuman)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)

            HStack(spacing: 6) {
                Text(entry.process ?? "-")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if let svc = entry.service {
                    Text(svc)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let tag = entry.runtime {
                    Text(tag)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .foregroundStyle(.purple)
                        .background(.purple.opacity(0.14), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button {
                    onInspect(entry.localPort)
                } label: {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 12))
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
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onInspect(entry.localPort) }
    }
}

// MARK: - Security Audit Score Card

struct AuditVisualView: View {
    let report: AuditReport
    let onInspectPort: (Int) -> Void

    var scoreColor: Color {
        switch report.score {
        case 90...100: return .green
        case 70...89: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                // Apple-style Score Ring
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.18), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(report.score) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(report.score)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Grade \(report.grade)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(scoreColor)
                    }
                }
                .frame(width: 82, height: 82)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Security & Socket Health")
                        .font(.system(size: 16, weight: .semibold))
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

            if report.findings.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text("No security or socket health issues detected.")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 8) {
                    ForEach(report.findings) { finding in
                        let sevColor = severityColor(finding.severity)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(finding.severity)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(sevColor)
                                    .background(sevColor.opacity(0.16), in: Capsule())

                                Text(finding.code)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)

                                Text(finding.title)
                                    .font(.system(size: 13, weight: .semibold))

                                Spacer()

                                if let port = finding.port {
                                    Button("Inspect :\(port)") {
                                        onInspectPort(port)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            Text(finding.recommendation)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(sevColor.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
            }
        }
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

            // Live Probe Card
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

            // Process Ancestry Chain
            if !report.ancestry.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PROCESS ANCESTRY")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(report.ancestry.enumerated()), id: \.element.id) { idx, node in
                            HStack(spacing: 8) {
                                if idx > 0 {
                                    Text(String(repeating: "  ", count: idx) + "└─")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                } else {
                                    Circle()
                                        .fill(.cyan)
                                        .frame(width: 7, height: 7)
                                }
                                Text(node.name)
                                    .font(.system(size: 12, weight: .semibold))
                                Text("PID \(node.pid)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                if let user = node.user {
                                    Text("(\(user))")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            // Socket Bindings
            if !report.sockets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BINDINGS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(report.sockets) { sock in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(sock.protocolName)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                Text(sock.local)
                                    .font(.system(size: 12, design: .monospaced))
                                ScopeBadge(scope: sock.scope)
                                StateBadge(state: sock.state)
                                Spacer()
                                if let user = sock.user {
                                    Text(user)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let cmd = sock.cmdline {
                                Text(cmd)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(10)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
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

// MARK: - Native Swift Charts Stats View

struct ChartDatum: Identifiable {
    let label: String
    let value: Int
    var id: String { label }
}

struct StatsVisualView: View {
    let stats: StatsReport

    var protoData: [ChartDatum] {
        stats.byProtocol.map { ChartDatum(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    var stateData: [ChartDatum] {
        stats.byState.map { ChartDatum(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    var scopeData: [ChartDatum] {
        stats.listeningByScope.map { ChartDatum(label: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                chartCard(title: "By Protocol", data: protoData, tint: .cyan)
                chartCard(title: "By Socket State", data: stateData, tint: .green)
                chartCard(title: "Listening Bind Exposure", data: scopeData, tint: .orange)
                chartCard(
                    title: "Top Processes",
                    data: stats.topProcesses.prefix(8).map { ChartDatum(label: $0.name, value: $0.count) },
                    tint: .purple
                )
            }
        }
    }

    @ViewBuilder
    private func chartCard(title: String, data: [ChartDatum], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            if data.isEmpty {
                Text("No data")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 140)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Count", item.value),
                        y: .value("Category", item.label)
                    )
                    .foregroundStyle(tint.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(item.value)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: max(120, CGFloat(data.count) * 26))
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
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
