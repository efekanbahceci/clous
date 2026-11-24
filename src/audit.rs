use std::collections::{HashMap, HashSet};
use std::process::Command;

use crate::models::{BindScope, PortEntry, SocketState, well_known_service};
use crate::scanner::probe_ports;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum AuditProfile {
    #[default]
    Developer,
    Strict,
    ZeroTrust,
}

impl AuditProfile {
    pub fn parse(s: &str) -> Result<Self, String> {
        match s.to_ascii_lowercase().as_str() {
            "dev" | "developer" => Ok(AuditProfile::Developer),
            "strict" | "prod" | "production" => Ok(AuditProfile::Strict),
            "zero-trust" | "zerotrust" | "paranoid" => Ok(AuditProfile::ZeroTrust),
            other => Err(format!(
                "Invalid audit profile '{other}'. Expected: developer, strict, zero-trust"
            )),
        }
    }

    pub fn as_str(self) -> &'static str {
        match self {
            AuditProfile::Developer => "developer",
            AuditProfile::Strict => "strict",
            AuditProfile::ZeroTrust => "zero-trust",
        }
    }
}

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinaryTrustLevel {
    AppleSigned,
    DeveloperSigned,
    AdHoc,
    Unsigned,
    Unknown,
}

impl BinaryTrustLevel {
    pub fn as_str(self) -> &'static str {
        match self {
            BinaryTrustLevel::AppleSigned => "APPLE_SIGNED",
            BinaryTrustLevel::DeveloperSigned => "DEVELOPER_SIGNED",
            BinaryTrustLevel::AdHoc => "AD_HOC",
            BinaryTrustLevel::Unsigned => "UNSIGNED",
            BinaryTrustLevel::Unknown => "UNKNOWN",
        }
    }
}

#[derive(Debug, Clone)]
pub struct BinaryTrustInfo {
    pub process: String,
    pub path: String,
    pub trust: BinaryTrustLevel,
    pub authority: Option<String>,
    pub suspicious_path: bool,
    pub ports: Vec<u16>,
}

#[derive(Debug, Clone, Default)]
pub struct HostPosture {
    pub firewall_enabled: Option<bool>,
    pub stealth_mode: Option<bool>,
    pub verified_binaries: usize,
    pub unsigned_binaries: usize,
    pub suspicious_path_binaries: usize,
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
    pub remediation_cmd: Option<String>,
}

#[derive(Debug, Clone)]
pub struct AuditReport {
    pub profile: AuditProfile,
    pub deep_scan: bool,
    pub total_sockets: usize,
    pub listening_count: usize,
    pub exposed_count: usize,
    pub score: u8,
    pub grade: &'static str,
    pub posture: HostPosture,
    pub binary_trusts: Vec<BinaryTrustInfo>,
    pub findings: Vec<AuditFinding>,
}

impl AuditReport {
    pub fn has_high_or_critical(&self) -> bool {
        self.findings
            .iter()
            .any(|f| matches!(f.severity, Severity::Critical | Severity::High))
    }
}

#[derive(Debug, Clone, Copy)]
pub struct AuditOptions {
    pub profile: AuditProfile,
    pub deep_scan: bool,
    pub check_host: bool,
}

impl Default for AuditOptions {
    fn default() -> Self {
        Self {
            profile: AuditProfile::Developer,
            deep_scan: false,
            check_host: true,
        }
    }
}

const CRITICAL_EXPOSED_PORTS: &[u16] = &[23, 2375, 2379, 6379, 9200, 11211, 27017];
const HIGH_EXPOSED_PORTS: &[u16] = &[
    445, 1433, 1521, 2049, 2181, 3306, 3389, 5432, 5672, 5900, 6443, 8888, 9042, 9092,
];
const DEV_EXPOSED_PORTS: &[u16] = &[3000, 3001, 4000, 4200, 5000, 5173, 8000, 8080];
const PLAINTEXT_LEGACY_PORTS: &[u16] = &[21, 23, 389];

/// Run a comprehensive security, binary trust, firewall posture, and optional deep active probe audit.
#[allow(dead_code)]
pub fn run_audit_analysis(entries: &[PortEntry]) -> AuditReport {
    run_audit_with_options(
        entries,
        AuditOptions {
            profile: AuditProfile::Strict,
            deep_scan: false,
            check_host: false,
        },
    )
}

pub fn run_audit_with_options(entries: &[PortEntry], opts: AuditOptions) -> AuditReport {
    let mut findings = Vec::new();
    let mut seen_port_rules: HashSet<(&'static str, u16)> = HashSet::new();

    let mut listening_count = 0usize;
    let mut exposed_count = 0usize;
    let mut close_wait_count = 0usize;
    let mut time_wait_count = 0usize;
    let mut hidden_privileged = 0usize;

    let mut exposed_tcp_ports: Vec<u16> = Vec::new();
    let mut binary_ports: HashMap<String, (String, Vec<u16>, bool)> = HashMap::new();

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
            if e.protocol.is_tcp() && !exposed_tcp_ports.contains(&e.local_port) {
                exposed_tcp_ports.push(e.local_port);
            }
        }

        // Collect unique executable paths for binary trust verification
        if let Some(exec_path) = extract_executable_path(e) {
            let pname = e
                .process_name
                .clone()
                .unwrap_or_else(|| "unknown".to_string());
            let entry_rec = binary_ports
                .entry(exec_path)
                .or_insert_with(|| (pname, Vec::new(), false));
            if !entry_rec.1.contains(&e.local_port) {
                entry_rec.1.push(e.local_port);
            }
            if is_exposed {
                entry_rec.2 = true;
            }
        }

        let svc = well_known_service(e.local_port).unwrap_or("Unknown");
        let proc_label = e.process_name.clone();
        let endpoint = Some(e.local_endpoint());

        let is_apple_airplay = (e.local_port == 5000 || e.local_port == 7000)
            && e.process_name
                .as_deref()
                .is_some_and(|p| p.starts_with("ControlCe"))
            && extract_executable_path(e).is_some_and(|p| {
                p.starts_with("/System/Library/CoreServices/ControlCenter.app/")
            });

        let is_non_loopback = scope != BindScope::Loopback;
        let effective_exposed =
            is_exposed || (scope == BindScope::Lan && opts.profile != AuditProfile::Developer);

        if effective_exposed && CRITICAL_EXPOSED_PORTS.contains(&e.local_port) {
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
                    remediation_cmd: Some(remediation_for_port(e.local_port)),
                });
            }
        } else if effective_exposed && HIGH_EXPOSED_PORTS.contains(&e.local_port) {
            if seen_port_rules.insert(("EXP-HIGH", e.local_port)) {
                findings.push(AuditFinding {
                    severity: Severity::High,
                    code: "EXP-HIGH",
                    port: Some(e.local_port),
                    process: proc_label.clone(),
                    endpoint: endpoint.clone(),
                    title: format!(
                        "Sensitive service {svc} (port {}) listening on non-loopback interface ({})",
                        e.local_port, e.local_addr
                    ),
                    recommendation: format!(
                        "Restrict port {} to loopback (127.0.0.1) or an isolated private subnet/VPC.",
                        e.local_port
                    ),
                    remediation_cmd: Some(remediation_for_port(e.local_port)),
                });
            }
        } else if effective_exposed && DEV_EXPOSED_PORTS.contains(&e.local_port) {
            let skip_in_dev = opts.profile == AuditProfile::Developer && is_apple_airplay;
            if !skip_in_dev && seen_port_rules.insert(("EXP-DEV", e.local_port)) {
                let sev = match opts.profile {
                    AuditProfile::Developer => Severity::Low,
                    AuditProfile::Strict => Severity::Medium,
                    AuditProfile::ZeroTrust => Severity::High,
                };
                findings.push(AuditFinding {
                    severity: sev,
                    code: "EXP-DEV",
                    port: Some(e.local_port),
                    process: proc_label.clone(),
                    endpoint: endpoint.clone(),
                    title: format!(
                        "Development/HTTP port {} ({svc}) bound to {}",
                        e.local_port, e.local_addr
                    ),
                    recommendation: "Bind local development servers to 127.0.0.1 unless LAN access is intentional.".to_string(),
                    remediation_cmd: Some(format!("clous kill {} -y --wait", e.local_port)),
                });
            }
        } else if is_non_loopback
            && opts.profile == AuditProfile::ZeroTrust
            && seen_port_rules.insert(("ZT-EXPOSED", e.local_port))
        {
            findings.push(AuditFinding {
                severity: Severity::Medium,
                code: "ZT-EXPOSED",
                port: Some(e.local_port),
                process: proc_label.clone(),
                endpoint: endpoint.clone(),
                title: format!(
                    "Zero-Trust violation: non-loopback listener on port {} ({})",
                    e.local_port, e.local_addr
                ),
                recommendation: "Under Zero-Trust policy, bind services to 127.0.0.1 or place behind an authenticated proxy.".to_string(),
                remediation_cmd: Some(remediation_for_port(e.local_port)),
            });
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
                remediation_cmd: Some(format!("clous kill {} -y --wait", e.local_port)),
            });
        }

        if e.local_port < 1024 && e.pid.is_none() {
            hidden_privileged += 1;
        }
    }

    // Host Defense Posture & Binary Code-Signature Verification
    let mut posture = HostPosture::default();
    let mut binary_trusts = Vec::new();

    if opts.check_host {
        let (fw, stealth) = inspect_host_firewall();
        posture.firewall_enabled = fw;
        posture.stealth_mode = stealth;

        if fw == Some(false) {
            let sev = match opts.profile {
                AuditProfile::Developer => Severity::Medium,
                AuditProfile::Strict => Severity::High,
                AuditProfile::ZeroTrust => Severity::Critical,
            };
            findings.push(AuditFinding {
                severity: sev,
                code: "FW-DISABLED",
                port: None,
                process: None,
                endpoint: None,
                title: "macOS Application Firewall is disabled".to_string(),
                recommendation: "Enable the macOS Application Firewall to block unsolicited inbound connections to exposed ports.".to_string(),
                remediation_cmd: Some("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on".to_string()),
            });
        }

        if stealth == Some(false) && opts.profile != AuditProfile::Developer {
            findings.push(AuditFinding {
                severity: Severity::Low,
                code: "FW-NO-STEALTH",
                port: None,
                process: None,
                endpoint: None,
                title: "macOS Firewall Stealth Mode is disabled".to_string(),
                recommendation: "Enable Stealth Mode so the host does not respond to unsolicited ICMP/port probes.".to_string(),
                remediation_cmd: Some("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on".to_string()),
            });
        }

        for (path, (proc_name, mut ports, has_exposed)) in binary_ports {
            ports.sort_unstable();
            let susp = is_suspicious_path(&path);
            let (trust, authority) = verify_binary_signature(&path);

            match trust {
                BinaryTrustLevel::AppleSigned | BinaryTrustLevel::DeveloperSigned => {
                    posture.verified_binaries += 1;
                }
                BinaryTrustLevel::Unsigned => {
                    posture.unsigned_binaries += 1;
                }
                _ => {}
            }
            if susp {
                posture.suspicious_path_binaries += 1;
                findings.push(AuditFinding {
                    severity: Severity::Critical,
                    code: "TRUST-SUSP-PATH",
                    port: ports.first().copied(),
                    process: Some(proc_name.clone()),
                    endpoint: Some(path.clone()),
                    title: format!(
                        "Listening binary '{}' is executing from a temporary/untrusted path",
                        proc_name
                    ),
                    recommendation: format!(
                        "Verify why '{}' is running from '{}' and terminate if unauthorized.",
                        proc_name, path
                    ),
                    remediation_cmd: ports.first().map(|p| format!("clous kill {p} -f -y --wait")),
                });
            }

            if trust == BinaryTrustLevel::Unsigned
                && (has_exposed || opts.profile != AuditProfile::Developer)
            {
                let sev = if has_exposed || opts.profile == AuditProfile::ZeroTrust {
                    Severity::High
                } else {
                    Severity::Low
                };
                findings.push(AuditFinding {
                    severity: sev,
                    code: "TRUST-UNSIGNED",
                    port: ports.first().copied(),
                    process: Some(proc_name.clone()),
                    endpoint: Some(path.clone()),
                    title: format!(
                        "Unsigned binary '{}' is listening on port(s) {:?}",
                        proc_name, ports
                    ),
                    recommendation: "Confirm this binary is an expected local build; code-sign production services.".to_string(),
                    remediation_cmd: Some(format!(
                        "codesign --verify --strict --verbose=2 {}",
                        shell_single_quote(&path)
                    )),
                });
            }

            binary_trusts.push(BinaryTrustInfo {
                process: proc_name,
                path,
                trust,
                authority,
                suspicious_path: susp,
                ports,
            });
        }
        binary_trusts.sort_by(|a, b| a.process.cmp(&b.process));
    }

    // Optional Deep Active Security Probe (unauthenticated Redis, plaintext HTTP, banner leakage)
    if opts.deep_scan && !exposed_tcp_ports.is_empty() {
        let probe_targets: Vec<u16> = exposed_tcp_ports.iter().copied().take(32).collect();
        if let Ok(probes) = probe_ports("127.0.0.1", &probe_targets, 400, true, 16) {
            for p in probes {
                if !p.open {
                    continue;
                }
                if let Some(ref banner) = p.banner {
                    if banner.starts_with("+PONG") {
                        findings.push(AuditFinding {
                            severity: Severity::Critical,
                            code: "AUTH-NONE",
                            port: Some(p.port),
                            process: None,
                            endpoint: Some(format!("127.0.0.1:{}", p.port)),
                            title: format!(
                                "Unauthenticated Redis instance responded +PONG on exposed port {}",
                                p.port
                            ),
                            recommendation: "Require authentication (requirepass) and bind Redis strictly to 127.0.0.1.".to_string(),
                            remediation_cmd: Some("redis-cli CONFIG SET bind 127.0.0.1".to_string()),
                        });
                    } else if p.detected_protocol.as_deref() == Some("HTTP")
                        && !banner.contains("301")
                        && !banner.contains("302")
                        && !banner.contains("308")
                    {
                        findings.push(AuditFinding {
                            severity: Severity::Info,
                            code: "INFO-BANNER",
                            port: Some(p.port),
                            process: None,
                            endpoint: Some(format!("127.0.0.1:{}", p.port)),
                            title: format!(
                                "Active HTTP banner exposed on port {}: {}",
                                p.port, banner
                            ),
                            recommendation: "Minimize Server header version disclosure and prefer TLS/HTTPS for exposed endpoints.".to_string(),
                            remediation_cmd: Some(format!("clous inspect {} --probe", p.port)),
                        });
                    }
                }
            }
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
            recommendation: "Inspect processes with `clous list --all --state CLOSE_WAIT` and verify sockets are properly closed.".to_string(),
            remediation_cmd: Some("clous list --all --state CLOSE_WAIT --sort process".to_string()),
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
            remediation_cmd: Some("clous list --all --state TIME_WAIT".to_string()),
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
            recommendation: "Run Clous with elevated privileges (sudo / Administrator) for complete visibility.".to_string(),
            remediation_cmd: Some("sudo clous audit --deep".to_string()),
        });
    }

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
        profile: opts.profile,
        deep_scan: opts.deep_scan,
        total_sockets: entries.len(),
        listening_count,
        exposed_count,
        score,
        grade,
        posture,
        binary_trusts,
        findings,
    }
}

fn extract_executable_path(entry: &PortEntry) -> Option<String> {
    let cmd = entry.cmdline.as_deref()?.trim();
    if cmd.is_empty() {
        return None;
    }
    let first = cmd.split_whitespace().next()?;
    if first.starts_with('/') {
        Some(first.to_string())
    } else {
        None
    }
}

fn shell_single_quote(s: &str) -> String {
    let cleaned: String = s.chars().filter(|c| !c.is_control()).collect();
    format!("'{}'", cleaned.replace('\'', "'\"'\"'"))
}

fn is_suspicious_path(path: &str) -> bool {
    let resolved = std::fs::canonicalize(path)
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_else(|_| path.to_string());
    let lower = resolved.to_ascii_lowercase();
    lower.starts_with("/tmp/")
        || lower.starts_with("/private/tmp/")
        || lower.starts_with("/var/tmp/")
        || lower.starts_with("/private/var/tmp/")
        || lower.contains("/downloads/")
        || lower.contains("/desktop/")
        || lower.starts_with("/dev/shm/")
}

fn remediation_for_port(port: u16) -> String {
    match port {
        6379 => "redis-cli CONFIG SET bind 127.0.0.1".to_string(),
        5432 => "Set listen_addresses = 'localhost' in postgresql.conf and restart PostgreSQL".to_string(),
        3306 => "Set bind-address = 127.0.0.1 in my.cnf and restart MySQL".to_string(),
        27017 => "Set net.bindIp: 127.0.0.1 in mongod.conf and restart MongoDB".to_string(),
        _ => format!("echo 'block drop in proto tcp to any port {port}' | sudo pfctl -ef -"),
    }
}

fn inspect_host_firewall() -> (Option<bool>, Option<bool>) {
    #[cfg(target_os = "macos")]
    {
        let fw = Command::new("/usr/libexec/ApplicationFirewall/socketfilterfw")
            .arg("--getglobalstate")
            .output()
            .ok()
            .map(|o| {
                let s = String::from_utf8_lossy(&o.stdout).to_ascii_lowercase();
                s.contains("enabled")
            });

        let stealth = Command::new("/usr/libexec/ApplicationFirewall/socketfilterfw")
            .arg("--getstealthmode")
            .output()
            .ok()
            .map(|o| {
                let s = String::from_utf8_lossy(&o.stdout).to_ascii_lowercase();
                s.contains("enabled")
            });

        (fw, stealth)
    }
    #[cfg(not(target_os = "macos"))]
    {
        (None, None)
    }
}

fn verify_binary_signature(path: &str) -> (BinaryTrustLevel, Option<String>) {
    #[cfg(target_os = "macos")]
    {
        if !std::path::Path::new(path).is_file() {
            return (BinaryTrustLevel::Unknown, None);
        }

        // First cryptographically verify the Mach-O signature (exit status checked)
        let Ok(verify_out) = Command::new("/usr/bin/codesign")
            .args(["--verify", "--strict", path])
            .output()
        else {
            return (BinaryTrustLevel::Unknown, None);
        };

        if !verify_out.status.success() {
            let err_lower = String::from_utf8_lossy(&verify_out.stderr).to_ascii_lowercase();
            if err_lower.contains("code object is not signed at all")
                || err_lower.contains("invalid signature")
                || err_lower.contains("modified")
            {
                return (BinaryTrustLevel::Unsigned, None);
            }
            return (BinaryTrustLevel::Unknown, None);
        }

        let Ok(output) = Command::new("/usr/bin/codesign")
            .args(["-dv", "--verbose=2", path])
            .output()
        else {
            return (BinaryTrustLevel::Unknown, None);
        };

        if !output.status.success() {
            return (BinaryTrustLevel::Unknown, None);
        }

        // codesign writes signature details to stderr
        let combined = format!(
            "{}\n{}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
        let lower = combined.to_ascii_lowercase();

        if lower.contains("signature=adhoc") {
            return (BinaryTrustLevel::AdHoc, Some("Ad-Hoc".to_string()));
        }

        let authority = combined
            .lines()
            .find_map(|l| l.strip_prefix("Authority="))
            .map(|s| s.trim().to_string());

        if authority
            .as_deref()
            .is_some_and(|a| a == "Software Signing" || a.starts_with("Apple "))
        {
            return (BinaryTrustLevel::AppleSigned, authority);
        }

        if authority.is_some() {
            return (BinaryTrustLevel::DeveloperSigned, authority);
        }

        (BinaryTrustLevel::Unknown, None)
    }
    #[cfg(not(target_os = "macos"))]
    {
        let _ = path;
        (BinaryTrustLevel::Unknown, None)
    }
}
