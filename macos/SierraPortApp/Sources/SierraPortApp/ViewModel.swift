import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class SierraPortViewModel: ObservableObject {
    let bridge = SierraPortBridge()

    @Published var selectedTab: AppTab = .terminal
    @Published var commandInput: String = ""
    @Published var blocks: [CommandBlock] = []
    @Published var isExecuting: Bool = false
    @Published var activeChipCommand: String? = nil
    @Published var highlightedBlockId: UUID? = nil

    // Command history
    @Published var history: [String] = []
    private var historyIndex: Int? = nil

    // Live Watch stream state
    @Published var isStreaming: Bool = false
    @Published var streamIntervalMs: Int = 1000
    @Published var streamAllStates: Bool = false
    @Published var latestTick: StreamTick? = nil
    @Published var tickHistory: [TickHistoryPoint] = []
    @Published var recentEvents: [StreamEvent] = []
    @Published var watchSearch: String = ""
    private var streamProcess: Process? = nil

    // Dedicated tabs state
    @Published var auditReport: AuditReport? = nil
    @Published var auditProfile: AuditProfileOption = .developer
    @Published var auditDeepScan: Bool = false
    @Published var allowlistedKeys: Set<String> = []
    @Published var statsReport: StatsReport? = nil
    @Published var isLoadingAudit: Bool = false
    @Published var isLoadingStats: Bool = false
    @Published var liveAnalyticsEnabled: Bool = true

    // Slide-over Forensic Inspector
    @Published var selectedPort: Int? = nil
    @Published var inspectedReport: InspectReport? = nil
    @Published var isInspecting: Bool = false
    @Published var showingInspector: Bool = false

    // Quick status toast
    @Published var statusMessage: String? = nil

    var binaryStatus: String {
        bridge.binaryPath ?? "Not found (run cargo build --release)"
    }

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "sierraport_audit_allowlist") {
            self.allowlistedKeys = Set(saved)
        }
        startLiveStream()
        Task {
            await refreshAudit()
            await refreshStats()
        }
    }

    deinit {
        streamProcess?.terminate()
    }

    // MARK: - Smart Autocomplete

    var autocompleteSuggestions: [String] {
        let trimmed = commandInput.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return [
                "list --wide --sort mem --desc",
                "list --exposed",
                "audit",
                "inspect 5000 --probe",
                "check 80,443,3000,5000,5432 127.0.0.1 --banner",
                "stats",
                "free --range 8000-8999 --count 3"
            ]
        }

        let lower = trimmed.lowercased()
        let baseCommands = [
            "list",
            "list --wide",
            "list --exposed",
            "list --all",
            "list --tcp --sort mem --desc",
            "list --all --state CLOSE_WAIT",
            "audit",
            "audit --strict",
            "stats",
            "watch -i 500",
            "free --range 8000-8999 --count 3",
            "check 80,443,3000,5000 127.0.0.1 --banner",
            "snapshot save /tmp/sierraport_base.json",
            "diff /tmp/sierraport_base.json",
            "clear",
            "help"
        ]

        var results = baseCommands.filter { $0.lowercased().hasPrefix(lower) && $0.lowercased() != lower }

        // Dynamic live port suggestions for inspect / who / kill
        if lower.hasPrefix("inspect") || lower.hasPrefix("who") || lower.hasPrefix("kill") {
            let verb = trimmed.split(separator: " ").first.map(String.init) ?? "inspect"
            let ports = Array(Set((latestTick?.entries ?? []).map(\.localPort))).sorted().prefix(6)
            for p in ports {
                let candidate = verb == "inspect" ? "inspect \(p) --probe" : "\(verb) \(p)"
                if candidate.lowercased().hasPrefix(lower) {
                    results.insert(candidate, at: 0)
                }
            }
        }

        return Array(results.prefix(6))
    }

    // MARK: - History Navigation

    func historyUp() {
        guard !history.isEmpty else { return }
        if let idx = historyIndex {
            historyIndex = max(0, idx - 1)
        } else {
            historyIndex = history.count - 1
        }
        if let idx = historyIndex {
            commandInput = history[idx]
        }
    }

    func historyDown() {
        guard let idx = historyIndex else { return }
        if idx + 1 < history.count {
            historyIndex = idx + 1
            commandInput = history[idx + 1]
        } else {
            historyIndex = nil
            commandInput = ""
        }
    }

    // MARK: - Command Execution

    func submitCommand() {
        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        commandInput = ""
        historyIndex = nil
        if history.last != cmd {
            history.append(cmd)
        }
        Task {
            await executeCommand(cmd)
        }
    }

    func executeCommand(_ rawInput: String) async {
        let cleaned = rawInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^sierraport\\s+", with: "", options: .regularExpression)

        if cleaned.isEmpty { return }

        if cleaned == "clear" || cleaned == "cls" {
            blocks.removeAll()
            return
        }

        let tokens = tokenize(cleaned)
        guard let subcmd = tokens.first?.lowercased() else { return }

        if subcmd == "watch" || subcmd == "monitor" || subcmd == "w" {
            selectedTab = .watch
            if !isStreaming { startLiveStream() }
            return
        }

        isExecuting = true
        defer { isExecuting = false }

        let decoder = JSONDecoder()

        // Determine if this subcommand supports structured JSON visualization
        let supportsJson = [
            "list", "ls", "who", "find", "pid",
            "audit", "sec", "security",
            "inspect", "info", "deep",
            "check", "probe", "ping",
            "stats", "summary",
            "diff", "free", "available"
        ].contains(subcmd) || (subcmd == "snapshot" && tokens.dropFirst().first == "diff")

        if supportsJson {
            let jsonArgs = tokens.filter { $0 != "--json" && $0 != "--no-color" } + ["--json"]
            let rawArgs = tokens.filter { $0 != "--no-color" } + ["--no-color"]

            async let jsonExec = bridge.run(arguments: jsonArgs)
            async let rawExec = bridge.run(arguments: rawArgs)

            let (jRes, rRes) = await (jsonExec, rawExec)
            let rawText = rRes.stdout.isEmpty ? rRes.stderr : rRes.stdout

            if jRes.exitCode != 0 && jRes.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendBlock(cmd: cleaned, durationMs: jRes.durationMs, payload: .error(jRes.stderr.trimmingCharacters(in: .whitespacesAndNewlines)), raw: rawText)
                return
            }

            let data = Data(jRes.stdout.utf8)
            let payload: BlockPayload
            switch subcmd {
            case "list", "ls", "who", "find", "pid":
                if let entries = try? decoder.decode([PortEntry].self, from: data) {
                    payload = .ports(entries)
                } else {
                    payload = .text(rawText)
                }
            case "audit", "sec", "security":
                if let report = try? decoder.decode(AuditReport.self, from: data) {
                    self.auditReport = report
                    payload = .audit(report)
                } else {
                    payload = .text(rawText)
                }
            case "inspect", "info", "deep":
                if let report = try? decoder.decode(InspectReport.self, from: data) {
                    payload = .inspect(report)
                } else {
                    payload = .text(rawText)
                }
            case "check", "probe", "ping":
                if let probes = try? decoder.decode([ProbeResult].self, from: data) {
                    payload = .probe(probes)
                } else {
                    payload = .text(rawText)
                }
            case "stats", "summary":
                if let stats = try? decoder.decode(StatsReport.self, from: data) {
                    self.statsReport = stats
                    payload = .stats(stats)
                } else {
                    payload = .text(rawText)
                }
            case "diff", "snapshot":
                if let diff = try? decoder.decode(DiffReport.self, from: data) {
                    payload = .diff(diff)
                } else {
                    payload = .text(rawText)
                }
            case "free", "available":
                if let free = try? decoder.decode(FreePortsResult.self, from: data) {
                    payload = .freePorts(free)
                } else {
                    payload = .text(rawText)
                }
            default:
                payload = .text(rawText)
            }

            appendBlock(cmd: cleaned, durationMs: jRes.durationMs, payload: payload, raw: rawText)
        } else {
            // Plain execution (kill, help, version, snapshot save, wait, etc.)
            var args = tokens
            if subcmd == "kill" && !args.contains("-y") && !args.contains("--yes") {
                args.append("-y")
            }
            if !args.contains("--no-color") && subcmd != "help" && subcmd != "version" && subcmd != "--help" && subcmd != "--version" {
                args.append("--no-color")
            }

            let res = await bridge.run(arguments: args)
            let output = res.stdout.isEmpty ? res.stderr : res.stdout
            let payload: BlockPayload = res.exitCode == 0 ? .text(output) : .error(output)
            appendBlock(cmd: cleaned, durationMs: res.durationMs, payload: payload, raw: output)
        }
    }

    func runSuggestion(_ cmd: String) {
        activeChipCommand = cmd
        commandInput = ""
        historyIndex = nil
        if history.last != cmd {
            history.append(cmd)
        }
        Task {
            await executeCommand(cmd)
            if activeChipCommand == cmd {
                activeChipCommand = nil
            }
        }
    }

    private func appendBlock(cmd: String, durationMs: Int, payload: BlockPayload, raw: String) {
        // Collapse older blocks so the newly executed command opens cleanly with zero collision
        for idx in blocks.indices {
            blocks[idx].isExpanded = false
        }
        let block = CommandBlock(
            command: cmd,
            timestamp: Date(),
            durationMs: durationMs,
            payload: payload,
            rawOutput: raw,
            showRaw: false,
            isExpanded: true
        )
        blocks.insert(block, at: 0)
        highlightedBlockId = block.id
        if blocks.count > 40 {
            blocks.removeLast()
        }
        let targetId = block.id
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if highlightedBlockId == targetId {
                highlightedBlockId = nil
            }
        }
    }

    func toggleRaw(for blockId: UUID) {
        if let idx = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[idx].showRaw.toggle()
        }
    }

    func toggleExpand(for blockId: UUID) {
        if let idx = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[idx].isExpanded.toggle()
        }
    }

    func collapseAllBlocks() {
        for idx in blocks.indices {
            blocks[idx].isExpanded = false
        }
    }

    func expandAllBlocks() {
        for idx in blocks.indices {
            blocks[idx].isExpanded = true
        }
    }

    func removeBlock(for blockId: UUID) {
        blocks.removeAll { $0.id == blockId }
    }

    // MARK: - Live Stream

    func startLiveStream() {
        stopLiveStream()
        let extra = streamAllStates ? ["--all"] : []
        streamProcess = bridge.startStream(intervalMs: streamIntervalMs, extraArgs: extra) { [weak self] tick in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestTick = tick
                self.tickHistory.append(
                    TickHistoryPoint(
                        tick: tick.tick,
                        time: tick.timestampUtc,
                        active: tick.active,
                        exposed: tick.exposed,
                        scanMs: tick.scanMs
                    )
                )
                if self.tickHistory.count > 36 {
                    self.tickHistory.removeFirst(self.tickHistory.count - 36)
                }
                if !tick.events.isEmpty {
                    self.recentEvents.insert(contentsOf: tick.events.reversed(), at: 0)
                    if self.recentEvents.count > 60 {
                        self.recentEvents.removeLast(self.recentEvents.count - 60)
                    }
                }
                // Periodically refresh full Analytics when user is viewing Analytics tab
                if self.selectedTab == .stats && self.liveAnalyticsEnabled && tick.tick % 3 == 0 {
                    Task { await self.refreshStats() }
                }
            }
        }
        isStreaming = streamProcess != nil
    }

    func stopLiveStream() {
        streamProcess?.terminate()
        streamProcess = nil
        isStreaming = false
    }

    func restartStreamWithSettings() {
        if isStreaming {
            startLiveStream()
        }
    }

    // MARK: - Dedicated Refresh & Quick Actions

    func refreshAudit() async {
        isLoadingAudit = true
        defer { isLoadingAudit = false }
        var args = ["audit", "--profile", auditProfile.rawValue, "--json"]
        if auditDeepScan {
            args.append("--deep")
        }
        let res = await bridge.run(arguments: args)
        if let data = res.stdout.data(using: .utf8),
           let report = try? JSONDecoder().decode(AuditReport.self, from: data) {
            self.auditReport = report
        }
    }

    func allowlistFinding(_ finding: AuditFinding) {
        allowlistedKeys.insert(finding.allowlistKey)
        persistAllowlist()
        showToast("Accepted risk for \(finding.code)")
    }

    func restoreAllowlistedKey(_ key: String) {
        allowlistedKeys.remove(key)
        persistAllowlist()
        showToast("Restored finding to active audit")
    }

    private func persistAllowlist() {
        UserDefaults.standard.set(Array(allowlistedKeys), forKey: "sierraport_audit_allowlist")
    }

    func exportAuditMarkdown() {
        guard let report = auditReport else { return }
        let panel = NSSavePanel()
        panel.title = "Export SierraPort Security Audit Report"
        panel.nameFieldStringValue = "sierraport-security-audit.md"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let activeFindings = report.findings.filter { !allowlistedKeys.contains($0.allowlistKey) }
        let penalty = activeFindings.reduce(0) { $0 + $1.penalty }
        let effectiveScore = max(0, 100 - penalty)

        var md = "# SierraPort Security & Binary Trust Audit Report\n\n"
        md += "- **Generated:** \(ISO8601DateFormatter().string(from: Date()))\n"
        md += "- **Profile:** `\(report.profile ?? auditProfile.rawValue)`\n"
        md += "- **Deep Active Probe:** `\(report.deepScan == true ? "Enabled" : "Disabled")`\n"
        md += "- **Effective Score:** **\(effectiveScore)/100**\n"
        md += "- **Sockets:** \(report.totalSockets) total · \(report.listeningCount) listening · \(report.exposedCount) exposed\n"

        if let p = report.posture {
            let fw = p.firewallEnabled == true ? "ON" : (p.firewallEnabled == false ? "OFF" : "N/A")
            let st = p.stealthMode == true ? "ON" : (p.stealthMode == false ? "OFF" : "N/A")
            md += "- **Host Posture:** Firewall `\(fw)` · Stealth Mode `\(st)` · Verified Binaries `\(p.verifiedBinaries)` · Unsigned `\(p.unsignedBinaries)`\n"
        }

        md += "\n## Active Findings (\(activeFindings.count))\n\n"
        if activeFindings.isEmpty {
            md += "No active security findings.\n"
        } else {
            for f in activeFindings {
                md += "### [\(f.severity)] `\(f.code)` — \(f.title)\n"
                md += "- **Recommendation:** \(f.recommendation)\n"
                if let cmd = f.remediationCmd {
                    md += "- **Remediation:** `\(cmd)`\n"
                }
                md += "\n"
            }
        }

        if let trusts = report.binaryTrusts, !trusts.isEmpty {
            md += "## Listening Binary Code-Signature Trust (\(trusts.count))\n\n"
            md += "| Process | Trust | Authority | Ports | Path |\n|---|---|---|---|---|\n"
            for b in trusts {
                let portsStr = b.ports.map(String.init).joined(separator: ", ")
                md += "| `\(b.process)` | `\(b.trust)` | \(b.authority ?? "-") | `\(portsStr)` | `\(b.path)` |\n"
            }
        }

        do {
            try md.write(to: url, atomically: true, encoding: .utf8)
            showToast("Exported report to \(url.lastPathComponent)")
        } catch {
            showToast("Export failed: \(error.localizedDescription)")
        }
    }

    func refreshStats() async {
        isLoadingStats = true
        defer { isLoadingStats = false }
        let res = await bridge.run(arguments: ["stats", "--json"])
        if let data = res.stdout.data(using: .utf8),
           let report = try? JSONDecoder().decode(StatsReport.self, from: data) {
            self.statsReport = report
        }
    }

    func inspectPort(_ port: Int, probe: Bool = true) {
        selectedPort = port
        showingInspector = true
        isInspecting = true
        Task {
            defer { isInspecting = false }
            var args = ["inspect", "\(port)", "--json"]
            if probe { args.append("--probe") }
            let res = await bridge.run(arguments: args)
            if let data = res.stdout.data(using: .utf8),
               let report = try? JSONDecoder().decode(InspectReport.self, from: data) {
                self.inspectedReport = report
            }
        }
    }

    func killPort(_ port: Int, force: Bool = false) {
        Task {
            var args = ["kill", "\(port)", "-y", "--wait", "--no-color"]
            if force { args.append("-f") }
            let res = await bridge.run(arguments: args)
            if res.exitCode == 0 {
                showToast("Terminated process on port \(port)")
                if inspectedReport?.port == port {
                    showingInspector = false
                }
            } else {
                showToast("Kill failed: \(res.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }

    private func showToast(_ msg: String) {
        statusMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if statusMessage == msg {
                statusMessage = nil
            }
        }
    }

    private func tokenize(_ input: String) -> [String] {
        input.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}
