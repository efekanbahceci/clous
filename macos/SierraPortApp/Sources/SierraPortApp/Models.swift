import Foundation

// MARK: - Core Port Entry

struct PortEntry: Codable, Identifiable, Hashable {
    let protocolName: String
    let localAddr: String
    let localPort: Int
    let remoteAddr: String
    let remotePort: Int
    let state: String
    let bindScope: String
    let pid: Int?
    let ppid: Int?
    let user: String?
    let memoryKb: Int?
    let process: String?
    let runtime: String?
    let service: String?
    let cmdline: String?

    var id: String {
        "\(protocolName)-\(localAddr)-\(localPort)-\(remoteAddr)-\(remotePort)-\(pid ?? -1)-\(state)"
    }

    var localEndpoint: String {
        localAddr.contains(":") && !localAddr.hasPrefix("[")
            ? "[\(localAddr)]:\(localPort)"
            : "\(localAddr):\(localPort)"
    }

    var remoteEndpoint: String {
        if remotePort == 0 && (remoteAddr == "*" || remoteAddr == "0.0.0.0" || remoteAddr == "::") {
            return "*:*"
        }
        return "\(remoteAddr):\(remotePort)"
    }

    var memoryHuman: String {
        guard let kb = memoryKb else { return "-" }
        if kb >= 1024 * 1024 {
            return String(format: "%.1fG", Double(kb) / (1024.0 * 1024.0))
        } else if kb >= 1024 {
            return String(format: "%.1fM", Double(kb) / 1024.0)
        } else {
            return "\(kb)K"
        }
    }

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case localAddr = "local_addr"
        case localPort = "local_port"
        case remoteAddr = "remote_addr"
        case remotePort = "remote_port"
        case state
        case bindScope = "bind_scope"
        case pid, ppid, user
        case memoryKb = "memory_kb"
        case process, runtime, service, cmdline
    }
}

// MARK: - Live Stream (NDJSON)

struct StreamEvent: Codable, Identifiable, Hashable {
    let time: String
    let kind: String
    let protocolName: String
    let port: Int
    let endpoint: String
    let scope: String
    let pid: Int?
    let process: String

    var id: String { "\(time)-\(kind)-\(protocolName)-\(endpoint)-\(pid ?? -1)" }

    enum CodingKeys: String, CodingKey {
        case time, kind, port, endpoint, scope, pid, process
        case protocolName = "protocol"
    }
}

struct StreamTick: Codable {
    let tick: Int
    let timestampUtc: String
    let scanMs: Int
    let active: Int
    let tcp: Int
    let udp: Int
    let exposed: Int
    let openedTotal: Int
    let closedTotal: Int
    let events: [StreamEvent]
    let entries: [PortEntry]

    enum CodingKeys: String, CodingKey {
        case tick, active, tcp, udp, exposed, events, entries
        case timestampUtc = "timestamp_utc"
        case scanMs = "scan_ms"
        case openedTotal = "opened_total"
        case closedTotal = "closed_total"
    }
}

// MARK: - Audit Report

struct AuditFinding: Codable, Identifiable, Hashable {
    let severity: String
    let code: String
    let port: Int?
    let process: String?
    let endpoint: String?
    let title: String
    let recommendation: String

    var id: String { "\(code)-\(port ?? -1)-\(title)" }
}

struct AuditReport: Codable {
    let score: Int
    let grade: String
    let totalSockets: Int
    let listeningCount: Int
    let exposedCount: Int
    let findings: [AuditFinding]

    enum CodingKeys: String, CodingKey {
        case score, grade, findings
        case totalSockets = "total_sockets"
        case listeningCount = "listening_count"
        case exposedCount = "exposed_count"
    }
}

// MARK: - Deep Inspect Report

struct InspectSocket: Codable, Identifiable {
    let protocolName: String
    let local: String
    let remote: String
    let state: String
    let scope: String
    let pid: Int?
    let user: String?
    let memoryKb: Int?
    let process: String?
    let cmdline: String?

    var id: String { "\(protocolName)-\(local)-\(remote)-\(pid ?? -1)-\(state)" }

    var memoryHuman: String {
        guard let kb = memoryKb else { return "-" }
        if kb >= 1024 * 1024 {
            return String(format: "%.1fG", Double(kb) / (1024.0 * 1024.0))
        } else if kb >= 1024 {
            return String(format: "%.1fM", Double(kb) / 1024.0)
        } else {
            return "\(kb)K"
        }
    }

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case local, remote, state, scope, pid, user, process, cmdline
        case memoryKb = "memory_kb"
    }
}

struct ProcessAncestor: Codable, Identifiable {
    let pid: Int
    let ppid: Int?
    let user: String?
    let name: String
    let memoryKb: Int?
    let cmdline: String?

    var id: Int { pid }

    enum CodingKeys: String, CodingKey {
        case pid, ppid, user, name, cmdline
        case memoryKb = "memory_kb"
    }
}

struct InspectProbe: Codable {
    let open: Bool
    let latencyMs: Double
    let detectedProtocol: String?
    let banner: String?

    enum CodingKeys: String, CodingKey {
        case open, banner
        case latencyMs = "latency_ms"
        case detectedProtocol = "detected_protocol"
    }
}

struct InspectReport: Codable {
    let port: Int
    let service: String?
    let sockets: [InspectSocket]
    let ancestry: [ProcessAncestor]
    let activePeers: Int
    let probe: InspectProbe?

    enum CodingKeys: String, CodingKey {
        case port, service, sockets, ancestry, probe
        case activePeers = "active_peers"
    }
}

// MARK: - Probe Check Results

struct ProbeResult: Codable, Identifiable {
    let host: String
    let port: Int
    let open: Bool
    let latencyMs: Double
    let service: String?
    let detectedProtocol: String?
    let banner: String?

    var id: String { "\(host):\(port)" }

    enum CodingKeys: String, CodingKey {
        case host, port, open, service, banner
        case latencyMs = "latency_ms"
        case detectedProtocol = "detected_protocol"
    }
}

// MARK: - Stats Report

struct TopProcessStat: Codable, Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct StatsReport: Codable {
    let total: Int
    let byProtocol: [String: Int]
    let byState: [String: Int]
    let listeningByScope: [String: Int]
    let topProcesses: [TopProcessStat]

    enum CodingKeys: String, CodingKey {
        case total
        case byProtocol = "by_protocol"
        case byState = "by_state"
        case listeningByScope = "listening_by_scope"
        case topProcesses = "top_processes"
    }
}

// MARK: - Diff Report

struct DiffEntry: Codable, Identifiable {
    let protocolName: String
    let localAddr: String
    let localPort: Int
    let pid: Int?
    let process: String?

    var id: String { "\(protocolName)-\(localAddr)-\(localPort)" }

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case localAddr = "local_addr"
        case localPort = "local_port"
        case pid, process
    }
}

struct DiffChange: Codable, Identifiable {
    let protocolName: String
    let localPort: Int
    let beforeProcess: String?
    let afterProcess: String?
    let changes: String

    var id: String { "\(protocolName)-\(localPort)-\(changes)" }

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case localPort = "local_port"
        case beforeProcess = "before_process"
        case afterProcess = "after_process"
        case changes
    }
}

struct DiffReport: Codable {
    let baselineCreatedUnix: Int
    let hasDrift: Bool
    let unchangedCount: Int
    let added: [DiffEntry]
    let removed: [DiffEntry]
    let changed: [DiffChange]

    enum CodingKeys: String, CodingKey {
        case added, removed, changed
        case baselineCreatedUnix = "baseline_created_unix"
        case hasDrift = "has_drift"
        case unchangedCount = "unchanged_count"
    }
}

// MARK: - Free Ports Result

struct FreePortsResult: Codable {
    let host: String
    let freePorts: [Int]

    enum CodingKeys: String, CodingKey {
        case host
        case freePorts = "free_ports"
    }
}

// MARK: - Command Block Payload

enum BlockPayload {
    case ports([PortEntry])
    case audit(AuditReport)
    case inspect(InspectReport)
    case probe([ProbeResult])
    case stats(StatsReport)
    case diff(DiffReport)
    case freePorts(FreePortsResult)
    case text(String)
    case error(String)
}

struct TickHistoryPoint: Identifiable {
    let id = UUID()
    let tick: Int
    let time: String
    let active: Int
    let exposed: Int
    let scanMs: Int
}

struct CommandBlock: Identifiable {
    let id = UUID()
    let command: String
    let timestamp: Date
    let durationMs: Int
    let payload: BlockPayload
    let rawOutput: String
    var showRaw: Bool = false
    var isExpanded: Bool = true

    var summaryLabel: String {
        switch payload {
        case .ports(let entries):
            return "\(entries.count) socket\(entries.count == 1 ? "" : "s")"
        case .audit(let report):
            return "Score \(report.score)/100 (\(report.grade))"
        case .inspect(let report):
            return "Port \(report.port) · \(report.sockets.count) bind"
        case .probe(let results):
            let open = results.filter(\.open).count
            return "\(open)/\(results.count) open"
        case .stats(let stats):
            return "\(stats.total) total sockets"
        case .diff(let diff):
            return diff.hasDrift ? "+\(diff.added.count) -\(diff.removed.count) ~\(diff.changed.count)" : "No drift"
        case .freePorts(let free):
            return "\(free.freePorts.count) free port\(free.freePorts.count == 1 ? "" : "s")"
        case .text:
            return "Output"
        case .error:
            return "Error"
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case terminal = "Terminal Deck"
    case watch = "Live Watch"
    case audit = "Security Audit"
    case stats = "Analytics"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .terminal: return "terminal"
        case .watch: return "waveform.path.ecg"
        case .audit: return "shield.lefthalf.filled"
        case .stats: return "chart.bar.xaxis"
        }
    }
}
