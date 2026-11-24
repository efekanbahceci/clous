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

    // Input validation, shake & keyboard-first navigation
    @Published var inputError: String? = nil
    @Published var inputShakeTrigger: CGFloat = 0
    @Published var relatedSuggestions: [String] = []
    @Published var selectedSuggestionIndex: Int? = nil
    @Published var focusedResultIndex: Int? = nil
    @Published var focusedResultBlockId: UUID? = nil

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
    @Published var auditProfile: AuditProfileOption = .developer {
        didSet {
            UserDefaults.standard.set(auditProfile.rawValue, forKey: "sierraport_audit_profile")
        }
    }
    @Published var auditDeepScan: Bool = false
    @Published var allowlistedKeys: Set<String> = []
    @Published var statsReport: StatsReport? = nil
    @Published var isLoadingAudit: Bool = false
    @Published var isLoadingStats: Bool = false
    @Published var liveAnalyticsEnabled: Bool = true
    private var terminationObserver: NSObjectProtocol? = nil

    // Slide-over Forensic Inspector
    @Published var selectedPort: Int? = nil
    @Published var selectedRowKey: String? = nil
    @Published var inspectedReport: InspectReport? = nil
    @Published var isInspecting: Bool = false
    @Published var showingInspector: Bool = false

    // Quick status toast
    @Published var statusMessage: String? = nil

    var binaryStatus: String {
        bridge.binaryPath ?? "Not found (run cargo build --release)"
    }

    init() {
        if let savedProfile = UserDefaults.standard.string(forKey: "sierraport_audit_profile"),
           let parsedProfile = AuditProfileOption(rawValue: savedProfile) {
            self.auditProfile = parsedProfile
        }
        if let saved = UserDefaults.standard.stringArray(forKey: "sierraport_audit_allowlist") {
            self.allowlistedKeys = Set(saved)
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stopLiveStream()
            }
        }
        startLiveStream()
        Task {
            await refreshAudit()
            await refreshStats()
        }
    }

    deinit {
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        streamProcess?.terminate()
    }

    // MARK: - Smart Bilingual Autocomplete & Related Suggestions

    var autocompleteSuggestions: [String] {
        if !relatedSuggestions.isEmpty {
            return relatedSuggestions
        }

        let trimmed = commandInput.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return [
                "list --wide --sort mem --desc",
                "list --exposed",
                "audit --deep",
                "inspect 5000 --probe",
                "check 80,443,3000,5000,5432 127.0.0.1 --banner",
                "stats",
                "free --range 8000-8999 --count 3"
            ]
        }

        return suggestRelatedCommands(for: trimmed)
    }

    /// Suggests relevant English SierraPort CLI commands for both English & Turkish queries or typos.
    func suggestRelatedCommands(for query: String) -> [String] {
        let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty { return [] }

        let tokens = tokenize(lower)
        let extractedPort = tokens.compactMap { tok -> Int? in
            let c = tok.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            if let n = Int(c), n >= 1 && n <= 65535 { return n }
            return nil
        }.first
        let portNum = extractedPort ?? 3000

        var matches: [String] = []

        func add(_ cmd: String) {
            if !matches.contains(cmd) { matches.append(cmd) }
        }

        // Semantic keyword map (English + Turkish intents -> English CLI commands)
        let intentRules: [([String], [String])] = [
            (["close", "stop", "kill", "end", "terminate", "kapat", "durdur", "sonlandır", "sonlandir", "öldür", "oldur"],
             ["kill \(portNum) -y --wait", "kill \(portNum) -f -y", "who \(portNum)"]),
            (["security", "audit", "firewall", "sign", "trust", "risk", "safe", "güvenlik", "guvenlik", "denetim", "imza", "koruma"],
             ["audit --deep", "audit --profile strict --deep", "audit --profile zero-trust --deep"]),
            (["exposed", "external", "public", "open", "dışa", "disa", "dışarı", "açık", "acik", "port"],
             ["list --exposed", "list --wide", "list --all"]),
            (["mem", "ram", "memory", "heavy", "bellek", "hafıza", "hafiza"],
             ["list --wide --sort mem --desc", "stats"]),
            (["free", "available", "empty", "unused", "boş", "bos", "müsait", "musait"],
             ["free --range 8000-8999 --count 3", "free --range 3000-3999 --count 5"]),
            (["inspect", "detail", "tree", "banner", "incele", "detay", "bak", "soyağacı", "soyagaci"],
             ["inspect \(portNum) --probe", "who \(portNum)", "check \(portNum) 127.0.0.1 --banner"]),
            (["who", "owner", "pid", "kim", "hangi", "sahip", "süreç", "surec"],
             ["who \(portNum)", "inspect \(portNum) --probe", "list --wide"]),
            (["check", "probe", "ping", "scan", "test", "tara", "kontrol"],
             ["check 80,443,3000,5000 127.0.0.1 --banner", "check \(portNum) 127.0.0.1 --banner", "audit --deep"]),
            (["watch", "live", "stream", "monitor", "canlı", "canli", "izle", "takip"],
             ["watch -i 500", "list --all"]),
            (["stat", "chart", "graph", "summary", "analytic", "istatistik", "grafik", "özet", "ozet", "analiz"],
             ["stats", "list --wide --sort mem --desc"]),
            (["diff", "snap", "baseline", "drift", "fark", "karşılaştır", "karsilastir", "yedek"],
             ["snapshot save ~/clous_base.json", "diff ~/clous_base.json"]),
            (["all", "conn", "socket", "tüm", "tum", "hepsi", "bütün", "bağlantı", "baglanti"],
             ["list --all", "list --all --state ESTABLISHED", "list --all --state CLOSE_WAIT"]),
            (["tcp", "udp", "ipv4", "ipv6"],
             ["list --tcp", "list --udp", "list --all --tcp"]),
            (["list", "ls", "show", "listele", "göster", "goster"],
             ["list", "list --wide", "list --exposed", "list --all"])
        ]

        for (keywords, cmds) in intentRules {
            if keywords.contains(where: { lower.contains($0) || $0.hasPrefix(lower) }) {
                for c in cmds { add(c) }
            }
        }

        // Prefix & substring match against catalog commands
        let catalog = [
            "list",
            "list --wide",
            "list --exposed",
            "list --all",
            "list --wide --sort mem --desc",
            "list --all --state CLOSE_WAIT",
            "audit --deep",
            "audit --profile strict --deep",
            "audit --profile zero-trust --deep",
            "inspect \(portNum) --probe",
            "who \(portNum)",
            "kill \(portNum) -y --wait",
            "check 80,443,3000,5000 127.0.0.1 --banner",
            "stats",
            "watch -i 500",
            "free --range 8000-8999 --count 3",
            "snapshot save ~/clous_base.json",
            "diff ~/clous_base.json",
            "help",
            "clear"
        ]

        for item in catalog where item.lowercased().hasPrefix(lower) || item.lowercased().contains(lower) {
            add(item)
        }

        // Dynamic live port suggestions when typing inspect / who / kill / close
        if lower.hasPrefix("inspect") || lower.hasPrefix("who") || lower.hasPrefix("kill") || lower.hasPrefix("close") {
            let verb = lower.hasPrefix("close") ? "kill" : (tokens.first ?? "inspect")
            let ports = Array(Set((latestTick?.entries ?? []).map(\.localPort))).sorted().prefix(5)
            for p in ports {
                let candidate = verb == "inspect" ? "inspect \(p) --probe" : (verb == "kill" ? "kill \(p) -y --wait" : "\(verb) \(p)")
                add(candidate)
            }
        }

        // Fuzzy edit-distance fallback on command verbs if still empty (catches typos like "audt", "lsit", "stts")
        if matches.isEmpty, let firstTok = tokens.first {
            let verbMap: [(String, String)] = [
                ("list", "list --wide"),
                ("audit", "audit --deep"),
                ("inspect", "inspect 5000 --probe"),
                ("check", "check 80,443,3000,5000 127.0.0.1 --banner"),
                ("kill", "kill 3000 -y --wait"),
                ("who", "who 5000"),
                ("stats", "stats"),
                ("watch", "watch -i 500"),
                ("free", "free --range 8000-8999 --count 3"),
                ("diff", "diff ~/clous_base.json"),
                ("help", "help")
            ]
            let close = verbMap
                .map { ($0.1, levenshtein(firstTok, $0.0)) }
                .filter { $0.1 <= 2 }
                .sorted { $0.1 < $1.1 }
            for (cmd, _) in close { add(cmd) }
        }

        // Always offer helpful process filter option if user typed a single word that might be a process
        if matches.isEmpty {
            add("list --all --proc \(query.trimmingCharacters(in: .whitespaces))")
            add("list --wide")
            add("audit --deep")
            add("help")
        }

        return Array(matches.prefix(6))
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }
        var dist = Array(repeating: Array(repeating: 0, count: bChars.count + 1), count: aChars.count + 1)
        for i in 0...aChars.count { dist[i][0] = i }
        for j in 0...bChars.count { dist[0][j] = j }
        for i in 1...aChars.count {
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                dist[i][j] = min(dist[i - 1][j] + 1, dist[i][j - 1] + 1, dist[i - 1][j - 1] + cost)
            }
        }
        return dist[aChars.count][bChars.count]
    }

    func clearInputError() {
        if inputError != nil || !relatedSuggestions.isEmpty {
            inputError = nil
            relatedSuggestions = []
        }
        selectedSuggestionIndex = nil
        focusedResultIndex = nil
        focusedResultBlockId = nil
    }

    /// Returns the first expanded block that contains navigable items (ports or audit findings with ports).
    var activeNavigableBlock: CommandBlock? {
        blocks.first { block in
            guard block.isExpanded && !block.showRaw else { return false }
            switch block.payload {
            case .ports(let entries): return !entries.isEmpty
            case .audit(let report): return !report.findings.filter { !allowlistedKeys.contains($0.allowlistKey) && $0.port != nil }.isEmpty
            default: return false
            }
        }
    }

    var activeResultCount: Int {
        guard let block = activeNavigableBlock else { return 0 }
        switch block.payload {
        case .ports(let entries): return min(entries.count, 200)
        case .audit(let report):
            return report.findings.filter { !allowlistedKeys.contains($0.allowlistKey) && $0.port != nil }.count
        default: return 0
        }
    }

    var shouldNavigateResultsOnTab: Bool {
        commandInput.trimmingCharacters(in: .whitespaces).isEmpty
            && inputError == nil
            && relatedSuggestions.isEmpty
            && selectedSuggestionIndex == nil
            && activeResultCount > 0
    }

    // MARK: - Keyboard-First Navigation (Tab / Shift+Tab / Arrow Keys / Esc)

    func selectNextTarget() {
        if focusedResultIndex != nil || shouldNavigateResultsOnTab {
            guard let block = activeNavigableBlock, activeResultCount > 0 else { return }
            focusedResultBlockId = block.id
            if let cur = focusedResultIndex {
                focusedResultIndex = (cur + 1) % activeResultCount
            } else {
                focusedResultIndex = 0
            }
            return
        }
        selectNextSuggestion()
    }

    func selectPreviousTarget() {
        if let cur = focusedResultIndex, activeResultCount > 0 {
            if cur > 0 {
                focusedResultIndex = cur - 1
            } else {
                focusedResultIndex = nil
                focusedResultBlockId = nil
            }
            return
        }
        selectPreviousSuggestion()
    }

    func selectNextSuggestion() {
        let count = autocompleteSuggestions.count
        guard count > 0 else { return }
        if let current = selectedSuggestionIndex {
            selectedSuggestionIndex = (current + 1) % count
        } else {
            selectedSuggestionIndex = 0
        }
    }

    func selectPreviousSuggestion() {
        let count = autocompleteSuggestions.count
        guard count > 0 else { return }
        if let current = selectedSuggestionIndex {
            selectedSuggestionIndex = current == 0 ? (count - 1) : (current - 1)
        } else {
            selectedSuggestionIndex = count - 1
        }
    }

    func handleUpArrow() {
        if let cur = focusedResultIndex {
            if cur > 0 {
                focusedResultIndex = cur - 1
            } else {
                focusedResultIndex = nil
                focusedResultBlockId = nil
            }
            return
        }
        if let current = selectedSuggestionIndex {
            if current > 0 {
                selectedSuggestionIndex = current - 1
            } else {
                selectedSuggestionIndex = nil
            }
        } else {
            historyUp()
        }
    }

    func handleDownArrow() {
        if focusedResultIndex != nil || shouldNavigateResultsOnTab {
            selectNextTarget()
            return
        }
        let count = autocompleteSuggestions.count
        if count > 0 {
            selectNextSuggestion()
        } else {
            historyDown()
        }
    }

    func handleEscape() {
        if showingInspector {
            showingInspector = false
            selectedPort = nil
            selectedRowKey = nil
        } else if focusedResultIndex != nil {
            focusedResultIndex = nil
            focusedResultBlockId = nil
        } else if selectedSuggestionIndex != nil {
            selectedSuggestionIndex = nil
        } else if inputError != nil || !relatedSuggestions.isEmpty {
            clearInputError()
        } else if !commandInput.isEmpty {
            commandInput = ""
        }
    }

    private func activateFocusedResult() -> Bool {
        guard let rowIdx = focusedResultIndex, let block = activeNavigableBlock else { return false }
        switch block.payload {
        case .ports(let entries):
            let sorted = entries.sorted { a, b in
                a.localPort == b.localPort ? a.protocolName < b.protocolName : a.localPort < b.localPort
            }
            guard rowIdx >= 0 && rowIdx < sorted.count else { return false }
            inspectPort(sorted[rowIdx].localPort, rowKey: "\(block.id.uuidString)-\(rowIdx)")
            return true
        case .audit(let report):
            let withPorts = report.findings.filter { !allowlistedKeys.contains($0.allowlistKey) && $0.port != nil }
            guard rowIdx >= 0 && rowIdx < withPorts.count, let port = withPorts[rowIdx].port else { return false }
            inspectPort(port)
            return true
        default:
            return false
        }
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
        // 1. If a result row inside an expanded block is focused via Tab / ↓, inspect it immediately!
        if activateFocusedResult() {
            return
        }

        // 2. If a suggestion chip is focused via Tab / ↓, run it immediately!
        let suggestions = autocompleteSuggestions
        if let idx = selectedSuggestionIndex, idx >= 0 && idx < suggestions.count {
            let chosen = suggestions[idx]
            selectedSuggestionIndex = nil
            runSuggestion(chosen)
            return
        }

        let cmd = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }

        guard let resolved = resolveStrictCommand(cmd) else {
            // Invalid command or Turkish phrase: shake input, show error, list related commands & pre-focus first suggestion!
            inputError = "Unknown command: \"\(cmd)\" — press Tab / ↓ and Enter to run a suggestion"
            relatedSuggestions = suggestRelatedCommands(for: cmd)
            selectedSuggestionIndex = nil
            withAnimation(.default) {
                inputShakeTrigger += 1
            }
            return
        }

        clearInputError()
        commandInput = ""
        historyIndex = nil
        if history.last != cmd {
            history.append(cmd)
        }
        Task {
            await executeResolvedCommand(resolved.command, origin: resolved.wasTranslated ? cmd : nil)
        }
    }

    func executeCommand(_ rawInput: String) async {
        let trimmedInput = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedInput.isEmpty { return }

        guard let resolved = resolveStrictCommand(trimmedInput) else {
            inputError = "Unknown command: \"\(trimmedInput)\" — select a related command below"
            relatedSuggestions = suggestRelatedCommands(for: trimmedInput)
            withAnimation(.default) {
                inputShakeTrigger += 1
            }
            return
        }

        clearInputError()
        await executeResolvedCommand(resolved.command, origin: resolved.wasTranslated ? trimmedInput : nil)
    }

    private func executeResolvedCommand(_ cleaned: String, origin displayOrigin: String?) async {
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
                let errMsg = jRes.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                inputError = errMsg.isEmpty ? "Invalid command syntax" : errMsg
                relatedSuggestions = suggestRelatedCommands(for: cleaned)
                withAnimation(.default) { inputShakeTrigger += 1 }
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

            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: jRes.durationMs, payload: payload, raw: rawText)
        } else {
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
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: res.durationMs, payload: payload, raw: output)
        }
    }

    /// Accepts valid English CLI commands and clean English shorthands only.
    /// Returns `nil` for unknown commands, typos, or Turkish phrases so the UI shakes and suggests matches.
    private func resolveStrictCommand(_ input: String) -> (command: String, wasTranslated: Bool)? {
        let stripped = input
            .replacingOccurrences(of: "^(clous|sierraport|sp)\\s+", with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = tokenize(stripped)
        guard let first = tokens.first?.lowercased() else { return nil }

        let knownCommands: Set<String> = [
            "list", "ls", "watch", "monitor", "w",
            "audit", "sec", "security",
            "inspect", "info", "deep",
            "check", "probe", "ping",
            "who", "find", "pid",
            "kill", "stats", "summary",
            "snapshot", "snap", "diff",
            "free", "available", "wait",
            "help", "version", "--help", "-h", "--version", "-v",
            "clear", "cls"
        ]
        if knownCommands.contains(first) || first.hasPrefix("-") {
            return (stripped, false)
        }

        let lower = stripped.lowercased()

        // Bare port number (e.g. "5000" or ":3000" or "port 5432")
        if tokens.count == 1, let p = Int(first.trimmingCharacters(in: CharacterSet(charactersIn: ":"))), p >= 1 && p <= 65535 {
            return ("inspect \(p) --probe", true)
        }
        if tokens.count == 2 && first == "port", let p = Int(tokens[1]), p >= 1 && p <= 65535 {
            return ("inspect \(p) --probe", true)
        }

        // Clean English shorthands: "close 3000", "stop 3000", "terminate 3000"
        if tokens.count == 2 && ["close", "stop", "terminate"].contains(first),
           let p = Int(tokens[1]), p >= 1 && p <= 65535 {
            return ("kill \(p) -y --wait", true)
        }

        // Single-word English shorthands
        switch lower {
        case "exposed": return ("list --exposed", true)
        case "memory", "ram": return ("list --wide --sort mem --desc", true)
        case "tcp": return ("list --tcp", true)
        case "udp": return ("list --udp", true)
        case "all", "all connections": return ("list --all", true)
        case "live": return ("watch", true)
        case "analytics": return ("stats", true)
        case "free port", "free ports": return ("free --range 8000-8999 --count 3", true)
        case "security scan", "deep audit": return ("audit --deep", true)
        case "strict audit": return ("audit --profile strict --deep", true)
        case "zero trust", "zero-trust": return ("audit --profile zero-trust --deep", true)
        default: return nil
        }
    }

    func runSuggestion(_ cmd: String) {
        clearInputError()
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

    private func appendBlock(cmd: String, origin: String? = nil, durationMs: Int, payload: BlockPayload, raw: String) {
        for idx in blocks.indices {
            blocks[idx].isExpanded = false
        }
        let block = CommandBlock(
            command: cmd,
            originalInput: origin,
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

    private var historySeq: Int = 0
    private var streamGeneration: Int = 0

    func startLiveStream(resetHistory: Bool = false) {
        stopLiveStream()
        streamGeneration += 1
        let gen = streamGeneration
        if resetHistory {
            tickHistory.removeAll()
        }
        let extra = streamAllStates ? ["--all"] : []
        streamProcess = bridge.startStream(intervalMs: streamIntervalMs, extraArgs: extra) { [weak self] tick in
            Task { @MainActor [weak self] in
                guard let self, self.streamGeneration == gen else { return }
                self.latestTick = tick
                self.historySeq += 1
                self.tickHistory.append(
                    TickHistoryPoint(
                        tick: self.historySeq,
                        time: tick.timestampUtc,
                        active: tick.active,
                        exposed: tick.exposed,
                        scanMs: tick.scanMs
                    )
                )
                if self.tickHistory.count > 45 {
                    self.tickHistory.removeFirst(self.tickHistory.count - 45)
                }
                if !tick.events.isEmpty {
                    self.recentEvents.insert(contentsOf: tick.events.reversed(), at: 0)
                    if self.recentEvents.count > 60 {
                        self.recentEvents.removeLast(self.recentEvents.count - 60)
                    }
                }
                // Periodically refresh full Analytics when user is viewing Analytics tab
                if self.selectedTab == .stats && self.liveAnalyticsEnabled && tick.tick % 2 == 0 {
                    Task { await self.refreshStats() }
                }
            }
        }
        isStreaming = streamProcess != nil
    }

    func stopLiveStream() {
        streamGeneration += 1
        streamProcess?.terminate()
        streamProcess = nil
        isStreaming = false
    }

    func restartStreamWithSettings(resetHistory: Bool = false) {
        if isStreaming {
            startLiveStream(resetHistory: resetHistory)
        } else if resetHistory {
            tickHistory.removeAll()
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
        panel.title = "Export Clous Security Audit Report"
        panel.nameFieldStringValue = "clous-security-audit.md"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let activeFindings = report.findings.filter { !allowlistedKeys.contains($0.allowlistKey) }
        let penalty = activeFindings.reduce(0) { $0 + $1.penalty }
        let effectiveScore = max(0, 100 - penalty)

        var md = "# Clous Security & Binary Trust Audit Report\n\n"
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

        let sanitizeMd: (String) -> String = { raw in
            raw.replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "|", with: "\\|")
                .replacingOccurrences(of: "`", with: "'")
        }

        md += "\n## Active Findings (\(activeFindings.count))\n\n"
        if activeFindings.isEmpty {
            md += "No active security findings.\n"
        } else {
            for f in activeFindings {
                md += "### [\(f.severity)] `\(sanitizeMd(f.code))` — \(sanitizeMd(f.title))\n"
                md += "- **Recommendation:** \(sanitizeMd(f.recommendation))\n"
                if let cmd = f.remediationCmd {
                    md += "- **Remediation:** `\(sanitizeMd(cmd))`\n"
                }
                md += "\n"
            }
        }

        if let trusts = report.binaryTrusts, !trusts.isEmpty {
            md += "## Listening Binary Code-Signature Trust (\(trusts.count))\n\n"
            md += "| Process | Trust | Authority | Ports | Path |\n|---|---|---|---|---|\n"
            for b in trusts {
                let portsStr = b.ports.map(String.init).joined(separator: ", ")
                md += "| `\(sanitizeMd(b.process))` | `\(sanitizeMd(b.trust))` | \(sanitizeMd(b.authority ?? "-")) | `\(portsStr)` | `\(sanitizeMd(b.path))` |\n"
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

    func inspectPort(_ port: Int, rowKey: String? = nil, probe: Bool = true) {
        selectedPort = port
        selectedRowKey = rowKey
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
