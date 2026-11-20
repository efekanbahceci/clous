use std::collections::HashSet;

use crate::models::{PortEntry, SocketState, well_known_service};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Severity {
    Critical,
    High,
    Medium,
    Low,
    Info,
}

impl Severity {
    pub fn as_str(self) -> &'static str {
        match self {
            Severity::Critical => "CRITICAL",
            Severity::High => "HIGH",
            Severity::Medium => "MEDIUM",
            Severity::Low => "LOW",
            Severity::Info => "INFO",
        }
    }

    pub fn penalty(self) -> u8 {
        match self {
            Severity::Critical => 25,
            Severity::High => 15,
            Severity::Medium => 7,
            Severity::Low => 3,
            Severity::Info => 0,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AuditFinding {
    pub severity: Severity,
    pub code: &'static str,
    pub port: Option<u16>,
    pub process: Option<String>,
    pub endpoint: Option<String>,
    pub title: String,
    pub recommendation: String,
}

#[derive(Debug, Clone)]
pub struct AuditReport {
    pub total_sockets: usize,
    pub listening_count: usize,
    pub exposed_count: usize,
    pub score: u8,
    pub grade: &'static str,
    pub findings: Vec<AuditFinding>,
}

impl AuditReport {
    pub fn has_high_or_critical(&self) -> bool {
        self.findings
            .iter()
            .any(|f| matches!(f.severity, Severity::Critical | Severity::High))
    }
}

const CRITICAL_EXPOSED_PORTS: &[u16] = &[23, 2375, 2379, 6379, 9200, 11211, 27017];
const HIGH_EXPOSED_PORTS: &[u16] = &[
    445, 1433, 1521, 2049, 2181, 3306, 3389, 5432, 5672, 5900, 6443, 8888, 9042, 9092,
];
const DEV_EXPOSED_PORTS: &[u16] = &[3000, 3001, 4000, 4200, 5000, 5173, 8000, 8080];
const PLAINTEXT_LEGACY_PORTS: &[u16] = &[21, 23, 389];

/// Run a comprehensive security and socket health audit against discovered port entries.
pub fn run_audit_analysis(entries: &[PortEntry]) -> AuditReport {
    let mut findings = Vec::new();
    let mut seen_port_rules: HashSet<(&'static str, u16)> = HashSet::new();

    let mut listening_count = 0usize;
    let mut exposed_count = 0usize;
    let mut close_wait_count = 0usize;
    let mut time_wait_count = 0usize;
    let mut hidden_privileged = 0usize;

    for e in entries {
        if e.state == SocketState::CloseWait {
            close_wait_count += 1;
        }
        if e.state == SocketState::TimeWait {
            time_wait_count += 1;
        }

        let is_listening = e.state.is_listening() || (e.protocol.is_udp() && e.local_port > 0);
        if !is_listening {
            continue;
        }
        listening_count += 1;

        let scope = e.bind_scope();
        let is_exposed = scope.is_exposed();
        if is_exposed {
            exposed_count += 1;
        }

        let svc = well_known_service(e.local_port).unwrap_or("Unknown");
        let proc_label = e.process_name.clone();
        let endpoint = Some(e.local_endpoint());

        if is_exposed && CRITICAL_EXPOSED_PORTS.contains(&e.local_port) {
            if seen_port_rules.insert(("EXP-CRIT", e.local_port)) {
                findings.push(AuditFinding {
                    severity: Severity::Critical,
                    code: "EXP-CRIT",
                    port: Some(e.local_port),
                    process: proc_label.clone(),
                    endpoint: endpoint.clone(),
                    title: format!(
                        "{svc} (port {}) is exposed on {} ({})",
                        e.local_port,
                        e.local_addr,
                        scope.as_str()
                    ),
                    recommendation: format!(
                        "Bind {svc} to 127.0.0.1 or enforce TLS + authentication and firewall port {}.",
                        e.local_port
                    ),
                });
            }
        } else if is_exposed && HIGH_EXPOSED_PORTS.contains(&e.local_port) {
            if seen_port_rules.insert(("EXP-HIGH", e.local_port)) {
                findings.push(AuditFinding {
                    severity: Severity::High,
                    code: "EXP-HIGH",
                    port: Some(e.local_port),
                    process: proc_label.clone(),
                    endpoint: endpoint.clone(),
                    title: format!(
                        "Sensitive service {svc} (port {}) listening on all/public interfaces ({})",
                        e.local_port, e.local_addr
                    ),
                    recommendation: format!(
                        "Restrict port {} to loopback (127.0.0.1) or an isolated private subnet/VPC.",
                        e.local_port
                    ),
                });
            }
        } else if is_exposed && DEV_EXPOSED_PORTS.contains(&e.local_port) {
            if seen_port_rules.insert(("EXP-DEV", e.local_port)) {
                findings.push(AuditFinding {
                    severity: Severity::Low,
                    code: "EXP-DEV",
                    port: Some(e.local_port),
                    process: proc_label.clone(),
                    endpoint: endpoint.clone(),
                    title: format!(
                        "Development/HTTP port {} ({svc}) bound to {}",
                        e.local_port, e.local_addr
                    ),
                    recommendation: "Bind local development servers to 127.0.0.1 unless LAN access is intentional.".to_string(),
                });
            }
        }

        if PLAINTEXT_LEGACY_PORTS.contains(&e.local_port)
            && seen_port_rules.insert(("PROTO-PLAIN", e.local_port))
        {
            findings.push(AuditFinding {
                severity: Severity::Medium,
                code: "PROTO-PLAIN",
                port: Some(e.local_port),
                process: proc_label.clone(),
                endpoint: endpoint.clone(),
                title: format!(
                    "Unencrypted legacy protocol {svc} listening on port {}",
                    e.local_port
                ),
                recommendation: "Replace with an encrypted alternative (SFTP/SSH/LDAPS) or disable the service.".to_string(),
            });
        }

        if e.local_port < 1024 && e.pid.is_none() {
            hidden_privileged += 1;
        }
    }

    if close_wait_count >= 20 {
        findings.push(AuditFinding {
            severity: Severity::Medium,
            code: "SOCK-CLOSEWAIT",
            port: None,
            process: None,
            endpoint: None,
            title: format!(
                "High CLOSE_WAIT socket count ({close_wait_count}) — possible connection leak"
            ),
            recommendation: "Inspect processes with `sierraport list --all --state CLOSE_WAIT` and verify sockets are properly closed.".to_string(),
        });
    }

    if time_wait_count >= 100 {
        findings.push(AuditFinding {
            severity: Severity::Low,
            code: "SOCK-TIMEWAIT",
            port: None,
            process: None,
            endpoint: None,
            title: format!(
                "Elevated TIME_WAIT socket count ({time_wait_count}) — high connection churn"
            ),
            recommendation: "Consider HTTP keep-alive / connection pooling to reduce ephemeral port pressure.".to_string(),
        });
    }

    if hidden_privileged > 0 {
        findings.push(AuditFinding {
            severity: Severity::Info,
            code: "PRIV-HIDDEN",
            port: None,
            process: None,
            endpoint: None,
            title: format!(
                "{hidden_privileged} privileged listening socket(s) (<1024) have hidden PID/process metadata"
            ),
            recommendation: "Run SierraPort with elevated privileges (sudo / Administrator) for complete visibility.".to_string(),
        });
    }

    // Sort findings by severity (Critical -> Info), then port.
    findings.sort_by(|a, b| a.severity.cmp(&b.severity).then_with(|| a.port.cmp(&b.port)));

    let total_penalty: u16 = findings.iter().map(|f| f.severity.penalty() as u16).sum();
    let score = 100u16.saturating_sub(total_penalty) as u8;
    let grade = match score {
        90..=100 => "A",
        80..=89 => "B",
        70..=79 => "C",
        55..=69 => "D",
        _ => "F",
    };

    AuditReport {
        total_sockets: entries.len(),
        listening_count,
        exposed_count,
        score,
        grade,
        findings,
    }
}
