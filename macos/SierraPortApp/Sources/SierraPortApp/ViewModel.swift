import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PrivilegedActionRequest: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let commandPreview: String
    let targetSummary: String?
    let detail: String
    let perform: @MainActor () -> Void

    static func == (lhs: PrivilegedActionRequest, rhs: PrivilegedActionRequest) -> Bool {
        lhs.id == rhs.id
    }
}

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
    private var openedPortProcesses: [Int: Process] = [:]

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

    // Privileged process-control permission gate (kill / terminate)
    @Published var pendingPrivilegedAction: PrivilegedActionRequest? = nil
    @Published var privilegedControlAuthorized: Bool = UserDefaults.standard.bool(forKey: "clous_privileged_control_authorized") {
        didSet {
            UserDefaults.standard.set(privilegedControlAuthorized, forKey: "clous_privileged_control_authorized")
        }
    }

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
                self?.stopAllOpenedPorts()
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
            inputError = L(
                "No matching Clous command or permission for \"\(cmd)\" — press Tab / ↓ and Enter to run an available command",
                "\"\(cmd)\" için eşleşen bir Clous komutu veya yetki bulunamadı — mevcut komut örneklerinden birini seçmek için Tab / ↓ ve Enter'a bas"
            )
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
            inputError = L(
                "No matching Clous command or permission for \"\(trimmedInput)\" — choose an available command below",
                "\"\(trimmedInput)\" için eşleşen bir Clous komutu veya yetki bulunamadı — aşağıdan mevcut bir komut örneği seç"
            )
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

        if subcmd == "history" || subcmd == "hist" {
            let portArg = tokens.dropFirst().first.flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: ":"))) }
            let records = PortHistoryStore.shared.query(port: portArg)
            let rawText = records.map { "\($0.timeLabel) \($0.kind) \($0.protocolName) \($0.endpoint) [\($0.scope)] \($0.process)" }.joined(separator: "\n")
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 1, payload: .history(records, portArg), raw: rawText.isEmpty ? "No events recorded in last 24h" : rawText)
            return
        }

        if subcmd == "guard" {
            let arg = tokens.dropFirst().first?.lowercased()
            if arg == "off" || arg == "stop" || arg == "disable" {
                PortGuardManager.shared.isEnabled = false
            } else if arg == "on" || arg == "start" || arg == "enable" {
                PortGuardManager.shared.isEnabled = true
            } else {
                PortGuardManager.shared.isEnabled.toggle()
            }
            let enabled = PortGuardManager.shared.isEnabled
            let msg = enabled
                ? L("Clous Port Guard enabled — macOS alerts active for new exposed listeners.", "Clous Port Bekçisi aktif — yeni dışa açık portlarda macOS bildirimi gönderilecek.")
                : L("Clous Port Guard paused.", "Clous Port Bekçisi durduruldu.")
            showToast(msg)
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 1, payload: .text(msg), raw: msg)
            return
        }

        if subcmd == "open" || subcmd == "listen" || subcmd == "serve" {
            let portArg = tokens.dropFirst().first(where: { !$0.hasPrefix("-") })
                .flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: ":"))) }
            let isPublic = tokens.contains("--public") || tokens.contains("--exposed")
            guard let port = portArg, port >= 1 && port <= 65535 else {
                let err = L("Usage: open <port> [--public]", "Kullanım: open <port> [--public]")
                appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 0, payload: .error(err), raw: err)
                return
            }

            if isPublic && !privilegedControlAuthorized {
                requestPrivilegedAction(
                    title: L("Expose Port :\(port) on All Interfaces?", ":\(port) Portu Dışa Açık Başlatılsın mı?"),
                    commandPreview: "clous open \(port) --public",
                    targetSummary: "0.0.0.0:\(port)",
                    detail: L(
                        "Binding to 0.0.0.0 makes port :\(port) reachable from your local network. Confirm to open this externally reachable listener.",
                        "0.0.0.0 üzerinde dinleme yapmak :\(port) portunu yerel ağdan erişilebilir kılar. Dışa açık port açmak için onay verin."
                    )
                ) { [weak self] in
                    guard let self else { return }
                    Task {
                        await self.launchManagedPortListener(port: port, isPublic: true, cleaned: cleaned, displayOrigin: displayOrigin)
                    }
                }
                return
            }

            await launchManagedPortListener(port: port, isPublic: isPublic, cleaned: cleaned, displayOrigin: displayOrigin)
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
            "diff", "free", "available",
            "project", "projects", "proj",
            "doctor", "diag", "health",
            "http", "curl"
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
            case "project", "projects", "proj":
                if let proj = try? decoder.decode(ProjectMapReport.self, from: data) {
                    payload = .projects(proj)
                } else {
                    payload = .text(rawText)
                }
            case "doctor", "diag", "health":
                if let doc = try? decoder.decode(DoctorReport.self, from: data) {
                    payload = .doctor(doc)
                } else {
                    payload = .text(rawText)
                }
            case "http", "curl":
                if let http = try? decoder.decode(HttpHealthReport.self, from: data) {
                    payload = .httpHealth(http)
                } else {
                    payload = .text(rawText)
                }
            default:
                payload = .text(rawText)
            }

            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: jRes.durationMs, payload: payload, raw: rawText)
        } else {
            if subcmd == "kill" && !privilegedControlAuthorized {
                let targetDesc = tokens.dropFirst().joined(separator: " ")
                let matchingPort = Int(tokens.dropFirst().first ?? "")
                let liveMatch = matchingPort.flatMap { port in
                    latestTick?.entries.first(where: { $0.localPort == port })
                }
                let summary: String? = liveMatch.map { entry in
                    let proc = entry.process ?? "Unknown process"
                    let pidText = entry.pid.map { "PID \($0)" } ?? "PID —"
                    return "\(proc) · \(pidText) · Port :\(entry.localPort)"
                }

                requestPrivilegedAction(
                    title: L("Permission Required to Terminate Process", "Süreci Sonlandırmak İçin İzin Gerekli"),
                    commandPreview: "clous \(cleaned)",
                    targetSummary: summary ?? (targetDesc.isEmpty ? nil : L("Target: \(targetDesc)", "Hedef: \(targetDesc)")),
                    detail: L(
                        "Terminating a running process can stop active services or cause unsaved work to be lost. Grant permission to allow Clous to run process termination commands.",
                        "Çalışan bir süreci sonlandırmak aktif servisleri durdurabilir veya kaydedilmemiş verilerin kaybolmasına yol açabilir. Clous'un süreç sonlandırma komutlarını çalıştırması için onay verin."
                    )
                ) { [weak self] in
                    guard let self else { return }
                    Task {
                        await self.runPrivilegedKillTokens(tokens, cleaned: cleaned, displayOrigin: displayOrigin)
                    }
                }
                return
            }

            await runPrivilegedKillTokens(tokens, cleaned: cleaned, displayOrigin: displayOrigin)
        }
    }

    private func runPrivilegedKillTokens(_ tokens: [String], cleaned: String, displayOrigin: String?) async {
        let subcmd = tokens.first?.lowercased() ?? ""
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

    /// Bilingual Natural-Language & CLI Intent Resolver (English + Turkish sentences -> Clous CLI).
    /// Understands both English and Turkish plain sentences regardless of active UI language,
    /// extracts ports/ranges/counts/protocols/profiles/states, and refuses unsupported or unauthorized
    /// system actions cleanly so the UI lists available English CLI command examples.
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
            "project", "projects", "proj",
            "doctor", "diag", "health",
            "http", "curl", "history", "hist", "guard", "forward", "proxy", "fwd",
            "open", "listen", "serve",
            "help", "version", "--help", "-h", "--version", "-v",
            "clear", "cls"
        ]
        if knownCommands.contains(first) || first.hasPrefix("-") {
            return (stripped, false)
        }

        let lower = Self.normalizeIntentText(stripped)

        // 1. Reject out-of-scope / unauthorized OS actions immediately so available Clous commands are suggested
        let unsupportedPhrases = [
            "shutdown", "reboot", "restart computer", "restart mac", "format disk", "delete file",
            "rm -rf", "wifi password", "block ip", "firewall rule", "install ", "uninstall ", "sudo ",
            "bilgisayari kapat", "bilgisayari yeniden baslat", "sistemi kapat", "dosya sil",
            "wifi sifresi", "sifre goster", "ag sifresi", "ip engelle", "kural ekle", "program yukle"
        ]
        if unsupportedPhrases.contains(where: { lower.contains($0) }) {
            return nil
        }

        // Helper for phrase matching
        func hasAny(_ phrases: [String]) -> Bool {
            phrases.contains { lower.contains($0) }
        }

        // Extract valid port numbers from text (handles "3000", ":3000", "3000'i", "3000.", etc.)
        let extractedPorts: [Int] = tokens.compactMap { raw in
            let digits = raw
                .trimmingCharacters(in: CharacterSet(charactersIn: ":,.;?!()[]\"'"))
                .split(separator: "'").first.map(String.init) ?? ""
            guard let n = Int(digits), n >= 1 && n <= 65535 else { return nil }
            return n
        }

        // Extract explicit port range (e.g. "8000-8999" or "8000 ile 8999" or "between 8000 and 8999")
        let extractedRange: String? = {
            if let rangeTok = tokens.first(where: { tok in
                let parts = tok.split(separator: "-")
                guard parts.count == 2, let a = Int(parts[0]), let b = Int(parts[1]) else { return false }
                return a >= 1 && b <= 65535 && a < b
            }) {
                return rangeTok
            }
            if extractedPorts.count >= 2 && (lower.contains("ile") || lower.contains("arasi") || lower.contains("between") || lower.contains("to")) {
                let lo = min(extractedPorts[0], extractedPorts[1])
                let hi = max(extractedPorts[0], extractedPorts[1])
                if hi - lo >= 2 && lo >= 1000 {
                    return "\(lo)-\(hi)"
                }
            }
            return nil
        }()

        // Optional flags detected from natural language
        let protoFlag: String = {
            if lower.contains("tcp") && !lower.contains("udp") { return " --tcp" }
            if lower.contains("udp") && !lower.contains("tcp") { return " --udp" }
            return ""
        }()
        let ipFlag: String = {
            if lower.contains("ipv4") { return " -4" }
            if lower.contains("ipv6") { return " -6" }
            return ""
        }()
        let forceFlag = hasAny(["force", "zorla", "hemen", "acilen"]) ? " -f" : ""

        // 2. Clear screen
        if hasAny(["ekrani temizle", "temizle", "clear screen", "clear deck"]) && extractedPorts.isEmpty {
            return ("clear", true)
        }

        // 3. Bare port number (e.g. "5000", ":3000", "port 5432", "5432 portu")
        if extractedPorts.count == 1 && (tokens.count == 1 || (tokens.count == 2 && hasAny(["port", "portu", "portunu"]))) {
            return ("inspect \(extractedPorts[0]) --probe", true)
        }

        // 4. Kill / Terminate process on port (TR + EN) — triggers Permission Sheet automatically!
        if hasAny(["close", "stop", "terminate", "end", "shut down", "kapat", "durdur", "sonlandir", "oldur", "kes"]) {
            if let port = extractedPorts.first {
                return ("kill \(port)\(forceFlag) --wait", true)
            }
            return nil
        }

        // 4b. Open / Start listener on port (TR + EN: "3000 portunu aç", "open port 3000", "dışa açık 9000 portu aç")
        if let port = extractedPorts.first,
           !hasAny(["goster", "listele", "show", "list", "hangi", "kim", "incele", "detay"]),
           hasAny(["portunu ac", "portu ac", "port ac", "'u ac", "'i ac", " ac", "baslat", "dinle", "open port", "open ", "start port", "listen on", "listen "]) {
            let publicFlag = hasAny(["public", "exposed", "disa acik", "disariya acik", "herkese acik", "0.0.0.0"]) ? " --public" : ""
            return ("open \(port)\(publicFlag)", true)
        }

        // 5. Who / Owner lookup (TR + EN)
        if hasAny(["who", "owner", "which process", "what is using", "what runs on", "kim kullaniyor", "kim", "hangi surec", "hangi uygulama", "sahibi"]) {
            if let port = extractedPorts.first {
                return ("who \(port)", true)
            }
        }

        // 6. Deep Inspect / Process Ancestry / Banner (TR + EN)
        if hasAny(["inspect", "detail", "ancestry", "trace", "banner", "incele", "detay", "soyagaci", "soy agaci", "baslik", "bak"]) {
            if let port = extractedPorts.first {
                return ("inspect \(port) --probe", true)
            }
        }

        // 7. Security Audit (TR + EN, supports strict & zero-trust profiles)
        if hasAny(["security", "audit", "firewall", "signature", "trust", "risk", "vulnerability", "guvenlik", "denetim", "imza", "guvenlik duvari", "tarama"]) {
            if hasAny(["zero trust", "zero-trust", "sifir guven"]) {
                return ("audit --profile zero-trust --deep", true)
            }
            if hasAny(["strict", "siki", "kati"]) {
                return ("audit --profile strict --deep", true)
            }
            return ("audit --deep", true)
        }

        // 8. Free / Available Ports (TR + EN, supports custom range & count)
        if hasAny(["free port", "available port", "unused port", "empty port", "bos port", "musait port", "kullanilmayan port", "uygun port"]) {
            let range = extractedRange ?? "8000-8999"
            let smallCount = extractedPorts.first(where: { $0 >= 1 && $0 <= 20 }) ?? 3
            return ("free --range \(range) --count \(smallCount)", true)
        }

        // 9. Snapshot Save / Baseline Diff (TR + EN)
        if hasAny(["snapshot", "baseline", "anlik goruntu", "yedek al", "temel kaydet", "kaydet"]) && hasAny(["port", "snapshot", "baseline", "goruntu", "yedek", "temel"]) {
            return ("snapshot save ~/clous_base.json", true)
        }
        if hasAny(["diff", "drift", "compare", "fark", "sapma", "karsilastir", "degisiklik"]) {
            return ("diff ~/clous_base.json", true)
        }

        // 10. Probe / Check specific ports (TR + EN)
        if hasAny(["check", "probe", "scan", "ping", "test", "tara", "kontrol et", "kontrol"]) && !extractedPorts.isEmpty {
            let portList = extractedPorts.map(String.init).joined(separator: ",")
            return ("check \(portList) 127.0.0.1 --banner", true)
        }

        // 11. Externally Exposed Ports (TR + EN)
        if hasAny(["exposed", "external", "public", "0.0.0.0", "disa acik", "disariya acik", "herkese acik"]) {
            return ("list --exposed\(protoFlag)\(ipFlag)", true)
        }

        // 12. Memory / RAM heavy consumers (TR + EN)
        if hasAny(["memory", "ram", "heaviest", "bellek", "hafiza", "en cok bellek", "en fazla ram"]) {
            return ("list --wide --sort mem --desc", true)
        }

        // 13. Stats / Charts / Analytics (TR + EN)
        if hasAny(["stats", "statistics", "analytics", "chart", "graph", "summary", "overview", "istatistik", "grafik", "ozet", "analiz"]) {
            return ("stats", true)
        }

        // 13b. Project / Git Repo Port Map (TR + EN)
        if hasAny(["project", "git", "repo", "proje", "projeler", "klasore gore", "projeye gore"]) {
            return ("project", true)
        }

        // 13c. Environment Doctor / Zombie Processes (TR + EN)
        if hasAny(["doctor", "health", "zombie", "leak", "doktor", "zombi", "saglik", "ortam kontrol", "sistemi kontrol"]) {
            return ("doctor", true)
        }

        // 13d. Local HTTP Health / TTFB / CORS (TR + EN)
        if hasAny(["http", "cors", "ttfb", "header", "yanit suresi", "saglik testi"]) && !extractedPorts.isEmpty {
            return ("http \(extractedPorts[0])", true)
        }

        // 13e. Forensic Port History (TR + EN)
        if hasAny(["history", "past", "earlier", "gecmis", "az once", "eskiden", "zaman cizelgesi"]) {
            if let port = extractedPorts.first {
                return ("history \(port)", true)
            }
            return ("history", true)
        }

        // 13f. Port Guard Watchdog (TR + EN)
        if hasAny(["guard", "watchdog", "alert", "bekci", "nobet", "bildirim"]) {
            if hasAny(["off", "stop", "kapat", "durdur"]) {
                return ("guard off", true)
            }
            return ("guard on", true)
        }

        // 14. Live Watch / Stream (TR + EN)
        if hasAny(["live", "watch", "stream", "monitor", "canli", "izle", "takip"]) {
            return ("watch", true)
        }

        // 15. General Port Listing / Connections / States (TR + EN)
        if hasAny(["close_wait", "close wait"]) {
            return ("list --all --state CLOSE_WAIT", true)
        }
        if hasAny(["established", "aktif baglanti", "kurulu baglanti"]) {
            return ("list --all --state ESTABLISHED", true)
        }
        if hasAny(["all connections", "all sockets", "all ports", "tum baglanti", "tum port", "butun port", "hepsini goster", "hepsini listele"]) {
            return ("list --all\(protoFlag)\(ipFlag)", true)
        }
        if hasAny(["tcp", "udp", "ipv4", "ipv6"]) && tokens.count <= 3 {
            return ("list\(protoFlag)\(ipFlag)", true)
        }
        if hasAny(["show ports", "active ports", "listening", "open ports", "portlari goster", "acik port", "aktif port", "dinleyen", "listele"]) {
            return ("list --wide\(protoFlag)\(ipFlag)", true)
        }

        return nil
    }

    private static func normalizeIntentText(_ text: String) -> String {
        text
            .lowercased(with: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
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
                    PortHistoryStore.shared.record(events: tick.events)
                    PortGuardManager.shared.inspectNewEvents(tick.events)
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
        let liveMatch = latestTick?.entries.first(where: { $0.localPort == port })
        let summary: String = {
            if let entry = liveMatch {
                let proc = entry.process ?? "Unknown process"
                let pidText = entry.pid.map { "PID \($0)" } ?? "PID —"
                return "\(proc) · \(pidText) · Port :\(port)"
            }
            return "Port :\(port)"
        }()
        let preview = force ? "clous kill \(port) -f --wait" : "clous kill \(port) --wait"

        requestPrivilegedAction(
            title: L("Terminate Process on Port :\(port)?", ":\(port) Portundaki Süreç Sonlandırılsın mı?"),
            commandPreview: preview,
            targetSummary: summary,
            detail: L(
                "Stopping a process occupying a port requires your permission. You can allow this action once or remember your permission for future process controls.",
                "Bir portu kullanan süreci durdurmak için onayınız gerekir. Bu işleme tek seferlik izin verebilir veya sonraki süreç kontrolleri için izninizi hatırlatabilirsiniz."
            )
        ) { [weak self] in
            guard let self else { return }
            Task {
                var args = ["kill", "\(port)", "-y", "--wait", "--no-color"]
                if force { args.append("-f") }
                let res = await self.bridge.run(arguments: args)
                if res.exitCode == 0 {
                    self.showToast(L("Terminated process on port \(port)", "\(port) portundaki süreç sonlandırıldı"))
                    if self.inspectedReport?.port == port {
                        self.showingInspector = false
                    }
                } else {
                    self.showToast(L("Kill failed: \(res.stderr.trimmingCharacters(in: .whitespacesAndNewlines))", "Sonlandırma başarısız: \(res.stderr.trimmingCharacters(in: .whitespacesAndNewlines))"))
                }
            }
        }
    }

    func requestPrivilegedAction(
        title: String,
        commandPreview: String,
        targetSummary: String?,
        detail: String,
        perform: @escaping @MainActor () -> Void
    ) {
        if privilegedControlAuthorized {
            perform()
            return
        }
        pendingPrivilegedAction = PrivilegedActionRequest(
            title: title,
            commandPreview: commandPreview,
            targetSummary: targetSummary,
            detail: detail,
            perform: perform
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    func approvePendingPrivilegedAction(rememberPermission: Bool) {
        guard let req = pendingPrivilegedAction else { return }
        if rememberPermission {
            privilegedControlAuthorized = true
        }
        pendingPrivilegedAction = nil
        req.perform()
    }

    func cancelPendingPrivilegedAction() {
        pendingPrivilegedAction = nil
        showToast(L("Action cancelled — permission not granted", "İşlem iptal edildi — izin verilmedi"))
    }

    func revokePrivilegedPermission() {
        privilegedControlAuthorized = false
        showToast(L("Process termination permission revoked", "Süreç sonlandırma izni geri alındı"))
    }

    private func launchManagedPortListener(port: Int, isPublic: Bool, cleaned: String, displayOrigin: String?) async {
        guard let bin = bridge.binaryPath else {
            let err = L("Clous core binary not found.", "Clous çekirdek ikilisi bulunamadı.")
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 0, payload: .error(err), raw: err)
            return
        }

        if let existing = openedPortProcesses[port], existing.isRunning {
            let msg = L(
                "Port :\(port) is already open and managed by Clous (PID \(existing.processIdentifier)).",
                ":\(port) portu zaten Clous tarafından açık tutuluyor (PID \(existing.processIdentifier))."
            )
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 1, payload: .text(msg), raw: msg)
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = isPublic ? ["open", "\(port)", "--public"] : ["open", "\(port)"]
        let errPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            let err = L("Failed to open port :\(port): \(error.localizedDescription)", ":\(port) portu açılamadı: \(error.localizedDescription)")
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 0, payload: .error(err), raw: err)
            return
        }

        // Wait briefly to confirm TCP bind succeeded cleanly
        try? await Task.sleep(for: .milliseconds(140))

        if !proc.isRunning {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let msg = errText.isEmpty
                ? L("Port :\(port) could not be opened (already in use or permission denied).", ":\(port) portu açılamadı (zaten kullanımda veya yetki reddedildi).")
                : errText
            appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 140, payload: .error(msg), raw: msg)
            return
        }

        openedPortProcesses[port] = proc
        let bindHost = isPublic ? "0.0.0.0" : "127.0.0.1"
        let msg = L(
            "✓ Opened HTTP/TCP listener on http://\(bindHost):\(port) (PID \(proc.processIdentifier)). Run `kill \(port)` anytime to close it.",
            "✓ http://\(bindHost):\(port) üzerinde HTTP/TCP dinleyici açıldı (PID \(proc.processIdentifier)). Kapatmak için `\(port) portunu kapat` veya `kill \(port)` yazabilirsiniz."
        )
        showToast(L("Opened port :\(port) (\(bindHost))", ":\(port) portu açıldı (\(bindHost))"))
        appendBlock(cmd: cleaned, origin: displayOrigin, durationMs: 140, payload: .text(msg), raw: msg)
    }

    private func stopAllOpenedPorts() {
        for (_, proc) in openedPortProcesses where proc.isRunning {
            proc.terminate()
        }
        openedPortProcesses.removeAll()
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
