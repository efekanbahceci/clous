use std::collections::{BTreeMap, HashMap, HashSet};
use std::io::{Read, Write};
use std::net::{Shutdown, TcpListener, TcpStream, ToSocketAddrs};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::thread;
use std::time::{Duration, Instant};

use crate::cli::GlobalOptions;
use crate::display::{Theme, json_escape};
use crate::models::{BindScope, FilterOptions, PortEntry, SocketState, well_known_service};
use crate::scanner;

// ============================================================================
// 1. `clous project` — Project & Git-Aware Port Mapping
// ============================================================================

#[derive(Debug, Clone)]
pub struct ProjectGroup {
    pub project_name: String,
    pub root_path: Option<String>,
    pub git_branch: Option<String>,
    pub total_memory_kb: u64,
    pub exposed_count: usize,
    pub ports: Vec<PortEntry>,
}

/// Batch-resolve working directories (`cwd`) for unique PIDs using a single native OS call.
pub fn resolve_pid_cwds(pids: &[u32]) -> HashMap<u32, String> {
    let mut map = HashMap::new();
    if pids.is_empty() {
        return map;
    }

    #[cfg(target_os = "linux")]
    {
        for &pid in pids {
            if let Ok(path) = std::fs::read_link(format!("/proc/{pid}/cwd")) {
                if let Some(s) = path.to_str() {
                    map.insert(pid, s.to_string());
                }
            }
        }
    }

    #[cfg(target_os = "macos")]
    {
        let pid_arg = pids
            .iter()
            .map(u32::to_string)
            .collect::<Vec<_>>()
            .join(",");
        let out = std::process::Command::new("/usr/sbin/lsof")
            .args(["-a", "-d", "cwd", "-Fn", "-p", &pid_arg])
            .output();
        if let Ok(o) = out {
            let text = String::from_utf8_lossy(&o.stdout);
            let mut current_pid: Option<u32> = None;
            for line in text.lines() {
                if let Some(rest) = line.strip_prefix('p') {
                    current_pid = rest.trim().parse::<u32>().ok();
                } else if let Some(rest) = line.strip_prefix('n')
                    && let Some(pid) = current_pid
                {
                    let trimmed = rest.trim();
                    if !trimmed.is_empty() && trimmed != "/" {
                        map.insert(pid, trimmed.to_string());
                    }
                }
            }
        }
    }

    map
}

/// Walk up to 6 parent directories from `cwd` to locate `.git/HEAD` without spawning `git`.
pub fn detect_git_project(cwd: &str) -> (String, String, Option<String>) {
    let start = PathBuf::from(cwd);
    let mut cursor: Option<&Path> = Some(start.as_path());
    let mut depth = 0;

    while let Some(dir) = cursor {
        if depth > 6 {
            break;
        }
        let git_head = dir.join(".git").join("HEAD");
        if git_head.is_file() {
            let branch = std::fs::read_to_string(&git_head).ok().and_then(|raw| {
                let line = raw.lines().next()?.trim();
                if let Some(ref_name) = line.strip_prefix("ref: refs/heads/") {
                    Some(ref_name.to_string())
                } else if line.len() >= 7 {
                    Some(line[..7].to_string())
                } else {
                    None
                }
            });
            let name = dir
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("project")
                .to_string();
            return (name, dir.to_string_lossy().to_string(), branch);
        }
        cursor = dir.parent();
        depth += 1;
    }

    let fallback_name = start
        .file_name()
        .and_then(|n| n.to_str())
        .filter(|s| !s.is_empty())
        .unwrap_or("System / Background")
        .to_string();
    (fallback_name, cwd.to_string(), None)
}

pub fn build_project_groups(entries: &[PortEntry]) -> Vec<ProjectGroup> {
    let unique_pids: Vec<u32> = entries
        .iter()
        .filter_map(|e| e.pid)
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    let cwd_map = resolve_pid_cwds(&unique_pids);

    let mut grouped: BTreeMap<String, ProjectGroup> = BTreeMap::new();
    let mut seen_mem_pids: HashMap<String, HashSet<u32>> = HashMap::new();

    for entry in entries {
        let (proj_name, root_path, branch) = match entry.pid.and_then(|p| cwd_map.get(&p)) {
            Some(cwd) => {
                let (n, r, b) = detect_git_project(cwd);
                (n, Some(r), b)
            }
            None => ("System / Background".to_string(), None, None),
        };

        let key = format!(
            "{}::{}",
            proj_name,
            root_path.as_deref().unwrap_or("system")
        );
        let group = grouped.entry(key.clone()).or_insert_with(|| ProjectGroup {
            project_name: proj_name,
            root_path,
            git_branch: branch,
            total_memory_kb: 0,
            exposed_count: 0,
            ports: Vec::new(),
        });

        if entry.bind_scope().is_exposed() {
            group.exposed_count += 1;
        }
        if let (Some(pid), Some(mem)) = (entry.pid, entry.memory_kb)
            && seen_mem_pids.entry(key).or_default().insert(pid)
        {
            group.total_memory_kb += mem;
        }
        group.ports.push(entry.clone());
    }

    let mut groups: Vec<ProjectGroup> = grouped.into_values().collect();
    groups.sort_by(|a, b| {
        let a_sys = a.root_path.is_none();
        let b_sys = b.root_path.is_none();
        a_sys
            .cmp(&b_sys)
            .then_with(|| b.ports.len().cmp(&a.ports.len()))
            .then_with(|| a.project_name.cmp(&b.project_name))
    });
    groups
}

pub fn run_project(filter: &FilterOptions, global: &GlobalOptions) -> Result<(), String> {
    let raw = scanner::scan_ports()?;
    let mut filtered: Vec<PortEntry> = raw.into_iter().filter(|e| filter.matches(e)).collect();
    filter.sort_entries(&mut filtered);
    let groups = build_project_groups(&filtered);

    if global.is_json() {
        print_project_json(&groups);
        return Ok(());
    }

    let theme = Theme::new(global.no_color);
    println!();
    println!(
        "{}",
        theme.bold("Clous — Project & Git Repository Port Map")
    );
    println!("{}", theme.dim("────────────────────────────────────────────────────────────────"));

    if groups.is_empty() {
        println!("{}", theme.dim("No active listening ports found."));
        return Ok(());
    }

    for g in &groups {
        let branch_str = g
            .git_branch
            .as_deref()
            .map(|b| format!(" {}", theme.cyan(&format!("[{b}]"))))
            .unwrap_or_default();
        let mem_mb = g.total_memory_kb / 1024;
        println!(
            "\n{} {}{}  {}",
            theme.bold("▸"),
            theme.bold(&g.project_name),
            branch_str,
            theme.dim(&format!(
                "({} ports · {} MB · {} exposed)",
                g.ports.len(),
                mem_mb,
                g.exposed_count
            ))
        );
        if let Some(path) = &g.root_path {
            println!("  {}", theme.dim(path));
        }
        for p in &g.ports {
            let proc_name = p.process_name.as_deref().unwrap_or("-");
            let pid_str = p.pid.map(|x| x.to_string()).unwrap_or_else(|| "-".into());
            let scope = p.bind_scope();
            let scope_badge = if scope.is_exposed() {
                theme.yellow(scope.as_str())
            } else {
                theme.green(scope.as_str())
            };
            println!(
                "    :{:<6} {:<5} {:<10} PID {:<7} {}",
                p.local_port,
                p.protocol.as_str(),
                scope_badge,
                pid_str,
                proc_name
            );
        }
    }
    println!();
    Ok(())
}

fn print_project_json(groups: &[ProjectGroup]) {
    println!("{{");
    println!("  \"project_count\": {},", groups.len());
    println!("  \"groups\": [");
    for (gi, g) in groups.iter().enumerate() {
        let g_comma = if gi + 1 < groups.len() { "," } else { "" };
        let root_json = g
            .root_path
            .as_deref()
            .map(|s| format!("\"{}\"", json_escape(s)))
            .unwrap_or_else(|| "null".to_string());
        let branch_json = g
            .git_branch
            .as_deref()
            .map(|s| format!("\"{}\"", json_escape(s)))
            .unwrap_or_else(|| "null".to_string());
        println!("    {{");
        println!("      \"project_name\": \"{}\",", json_escape(&g.project_name));
        println!("      \"root_path\": {root_json},");
        println!("      \"git_branch\": {branch_json},");
        println!("      \"total_memory_kb\": {},", g.total_memory_kb);
        println!("      \"exposed_count\": {},", g.exposed_count);
        println!("      \"ports\": [");
        for (pi, p) in g.ports.iter().enumerate() {
            let p_comma = if pi + 1 < g.ports.len() { "," } else { "" };
            let pid_json = p.pid.map(|x| x.to_string()).unwrap_or_else(|| "null".into());
            let proc_json = p
                .process_name
                .as_deref()
                .map(|s| format!("\"{}\"", json_escape(s)))
                .unwrap_or_else(|| "null".into());
            let svc_json = well_known_service(p.local_port)
                .map(|s| format!("\"{}\"", json_escape(s)))
                .unwrap_or_else(|| "null".into());
            println!(
                "        {{\"port\":{},\"protocol\":\"{}\",\"bind_scope\":\"{}\",\"local_addr\":\"{}\",\"pid\":{},\"process\":{},\"service\":{}}}{p_comma}",
                p.local_port,
                json_escape(p.protocol.as_str()),
                json_escape(p.bind_scope().as_str()),
                json_escape(&p.local_addr),
                pid_json,
                proc_json,
                svc_json
            );
        }
        println!("      ]");
        println!("    }}{g_comma}");
    }
    println!("  ]");
    println!("}}");
}

// ============================================================================
// 2. `clous doctor` — Developer Environment & Zombie Process Doctor
// ============================================================================

#[derive(Debug, Clone)]
pub struct DoctorIssue {
    pub severity: String, // CRITICAL, HIGH, MEDIUM, INFO
    pub category: String,
    pub title: String,
    pub detail: String,
    pub port: Option<u16>,
    pub pid: Option<u32>,
    pub process: Option<String>,
    pub fix_cmd: Option<String>,
}

#[derive(Debug, Clone)]
pub struct DoctorReport {
    pub score: u32,
    pub status: String,
    pub total_listening: usize,
    pub close_wait_count: usize,
    pub time_wait_count: usize,
    pub dev_ports_active: usize,
    pub issues: Vec<DoctorIssue>,
}

pub fn analyze_doctor(all_entries: &[PortEntry]) -> DoctorReport {
    let mut issues: Vec<DoctorIssue> = Vec::new();
    let mut penalty: u32 = 0;

    let listeners: Vec<&PortEntry> = all_entries
        .iter()
        .filter(|e| e.state == SocketState::Listen || e.protocol.is_udp())
        .collect();

    let close_wait: Vec<&PortEntry> = all_entries
        .iter()
        .filter(|e| e.state == SocketState::CloseWait)
        .collect();
    let time_wait_count = all_entries
        .iter()
        .filter(|e| e.state == SocketState::TimeWait)
        .count();

    let established_pids: HashSet<u32> = all_entries
        .iter()
        .filter(|e| e.state == SocketState::Established)
        .filter_map(|e| e.pid)
        .collect();

    // 1. Check exposed local databases
    let db_ports: &[(u16, &str)] = &[
        (5432, "PostgreSQL"),
        (3306, "MySQL"),
        (6379, "Redis"),
        (27017, "MongoDB"),
        (9200, "Elasticsearch"),
        (5984, "CouchDB"),
    ];
    for e in &listeners {
        let scope = e.bind_scope();
        if let Some((_, db_name)) = db_ports.iter().find(|(p, _)| *p == e.local_port)
            && scope.is_exposed()
        {
            penalty += 20;
            issues.push(DoctorIssue {
                severity: "CRITICAL".into(),
                category: "EXPOSED_DATABASE".into(),
                title: format!("{db_name} exposed on {} (:{})", scope.as_str(), e.local_port),
                detail: "Database port is reachable outside localhost. Bind to 127.0.0.1 unless intentionally networked.".into(),
                port: Some(e.local_port),
                pid: e.pid,
                process: e.process_name.clone(),
                fix_cmd: Some(format!("clous inspect {} --probe", e.local_port)),
            });
        }
    }

    // 2. Check suspicious execution paths (/tmp, /var/tmp, /Downloads)
    for e in &listeners {
        if let Some(cmd) = e.cmdline.as_deref() {
            let lower = cmd.to_lowercase();
            if lower.contains("/tmp/") || lower.contains("/var/tmp/") || lower.contains("/downloads/") {
                penalty += 18;
                issues.push(DoctorIssue {
                    severity: "HIGH".into(),
                    category: "SUSPICIOUS_PATH".into(),
                    title: format!(
                        "Listener running from temporary/download directory on :{}",
                        e.local_port
                    ),
                    detail: format!("Process '{}' is executing from a volatile path.", e.process_name.as_deref().unwrap_or("-")),
                    port: Some(e.local_port),
                    pid: e.pid,
                    process: e.process_name.clone(),
                    fix_cmd: Some(format!("clous kill {} --wait", e.local_port)),
                });
            }
        }
    }

    // 3. Check CLOSE_WAIT socket leaks per PID
    let mut cw_by_pid: HashMap<u32, (usize, Option<String>)> = HashMap::new();
    for e in &close_wait {
        if let Some(pid) = e.pid {
            let entry = cw_by_pid.entry(pid).or_insert((0, e.process_name.clone()));
            entry.0 += 1;
        }
    }
    for (pid, (cnt, proc_name)) in cw_by_pid {
        if cnt >= 10 {
            penalty += 12;
            issues.push(DoctorIssue {
                severity: "HIGH".into(),
                category: "SOCKET_LEAK".into(),
                title: format!(
                    "CLOSE_WAIT socket leak ({cnt} stuck sockets) in {}",
                    proc_name.as_deref().unwrap_or("process")
                ),
                detail: "Unclosed peer connections are piling up in CLOSE_WAIT state.".into(),
                port: None,
                pid: Some(pid),
                process: proc_name,
                fix_cmd: Some("clous list --all --state CLOSE_WAIT".into()),
            });
        }
    }

    if time_wait_count >= 100 {
        penalty += 8;
        issues.push(DoctorIssue {
            severity: "MEDIUM".into(),
            category: "TIME_WAIT_SPIKE".into(),
            title: format!("High TIME_WAIT socket count ({time_wait_count})"),
            detail: "Frequent short-lived TCP connections without keep-alive pooling.".into(),
            port: None,
            pid: None,
            process: None,
            fix_cmd: Some("clous list --all --state TIME_WAIT".into()),
        });
    }

    // 4. Idle high-memory dev listeners (> 512 MB RAM and 0 active ESTABLISHED peers)
    let mut checked_heavy_pids = HashSet::new();
    for e in &listeners {
        if let (Some(pid), Some(mem_kb)) = (e.pid, e.memory_kb)
            && mem_kb > 512 * 1024
            && !established_pids.contains(&pid)
            && checked_heavy_pids.insert(pid)
        {
            let proc_lower = e.process_name.as_deref().unwrap_or("").to_lowercase();
            let is_dev_runtime = ["node", "python", "ruby", "java", "bun", "deno", "go", "cargo"]
                .iter()
                .any(|r| proc_lower.contains(r));
            if is_dev_runtime {
                penalty += 8;
                issues.push(DoctorIssue {
                    severity: "MEDIUM".into(),
                    category: "IDLE_HEAVY_DEV".into(),
                    title: format!(
                        "Idle high-memory dev server '{}' ({} MB) on :{}",
                        e.process_name.as_deref().unwrap_or("-"),
                        mem_kb / 1024,
                        e.local_port
                    ),
                    detail: "No active ESTABLISHED connections detected — possible forgotten dev server.".into(),
                    port: Some(e.local_port),
                    pid: Some(pid),
                    process: e.process_name.clone(),
                    fix_cmd: Some(format!("clous kill {} --wait", e.local_port)),
                });
            }
        }
    }

    // 5. Common dev ports inventory
    let common_dev_ports: HashSet<u16> = [3000, 3001, 4200, 5173, 5432, 6379, 8000, 8080, 8888, 27017]
        .into_iter()
        .collect();
    let mut active_dev_ports = HashSet::new();
    for e in &listeners {
        if common_dev_ports.contains(&e.local_port) && active_dev_ports.insert(e.local_port) {
            issues.push(DoctorIssue {
                severity: "INFO".into(),
                category: "DEV_PORT_ACTIVE".into(),
                title: format!(
                    "Dev port :{} occupied by '{}'",
                    e.local_port,
                    e.process_name.as_deref().unwrap_or("-")
                ),
                detail: format!(
                    "Listening on {} ({}). Use kill if experiencing EADDRINUSE.",
                    e.local_addr,
                    e.bind_scope().as_str()
                ),
                port: Some(e.local_port),
                pid: e.pid,
                process: e.process_name.clone(),
                fix_cmd: Some(format!("clous kill {} --wait", e.local_port)),
            });
        }
    }

    let score = 100u32.saturating_sub(penalty.min(100));
    let status = if score >= 85 {
        "HEALTHY"
    } else if score >= 60 {
        "ATTENTION"
    } else {
        "DEGRADED"
    }
    .to_string();

    DoctorReport {
        score,
        status,
        total_listening: listeners.len(),
        close_wait_count: close_wait.len(),
        time_wait_count,
        dev_ports_active: active_dev_ports.len(),
        issues,
    }
}

pub fn run_doctor(global: &GlobalOptions) -> Result<(), String> {
    let all = scanner::scan_ports()?;
    let report = analyze_doctor(&all);

    if global.is_json() {
        print_doctor_json(&report);
        return Ok(());
    }

    let theme = Theme::new(global.no_color);
    println!();
    println!("{}", theme.bold("Clous — Developer Environment Doctor"));
    println!("{}", theme.dim("────────────────────────────────────────────────────────────────"));
    println!(
        "Health Score: {}/100 ({})  |  Listening: {}  |  CLOSE_WAIT: {}  |  TIME_WAIT: {}",
        report.score,
        report.status,
        report.total_listening,
        report.close_wait_count,
        report.time_wait_count
    );

    if report.issues.is_empty() {
        println!("\n{}", theme.green("✓ Environment looks clean — no zombie servers, leaks, or exposed DBs."));
    } else {
        println!();
        for issue in &report.issues {
            let sev_colored = match issue.severity.as_str() {
                "CRITICAL" | "HIGH" => theme.red(&format!("[{}]", issue.severity)),
                "MEDIUM" => theme.yellow(&format!("[{}]", issue.severity)),
                _ => theme.cyan(&format!("[{}]", issue.severity)),
            };
            println!("{sev_colored} {}", theme.bold(&issue.title));
            println!("  {}", theme.dim(&issue.detail));
            if let Some(fix) = &issue.fix_cmd {
                println!("  Fix: {}", theme.cyan(fix));
            }
        }
    }
    println!();
    Ok(())
}

fn print_doctor_json(r: &DoctorReport) {
    println!("{{");
    println!("  \"score\": {},", r.score);
    println!("  \"status\": \"{}\",", json_escape(&r.status));
    println!("  \"total_listening\": {},", r.total_listening);
    println!("  \"close_wait_count\": {},", r.close_wait_count);
    println!("  \"time_wait_count\": {},", r.time_wait_count);
    println!("  \"dev_ports_active\": {},", r.dev_ports_active);
    println!("  \"issues\": [");
    for (i, item) in r.issues.iter().enumerate() {
        let comma = if i + 1 < r.issues.len() { "," } else { "" };
        let port_j = item.port.map(|x| x.to_string()).unwrap_or_else(|| "null".into());
        let pid_j = item.pid.map(|x| x.to_string()).unwrap_or_else(|| "null".into());
        let proc_j = item
            .process
            .as_deref()
            .map(|s| format!("\"{}\"", json_escape(s)))
            .unwrap_or_else(|| "null".into());
        let fix_j = item
            .fix_cmd
            .as_deref()
            .map(|s| format!("\"{}\"", json_escape(s)))
            .unwrap_or_else(|| "null".into());
        println!(
            "    {{\"severity\":\"{}\",\"category\":\"{}\",\"title\":\"{}\",\"detail\":\"{}\",\"port\":{port_j},\"pid\":{pid_j},\"process\":{proc_j},\"fix_cmd\":{fix_j}}}{comma}",
            json_escape(&item.severity),
            json_escape(&item.category),
            json_escape(&item.title),
            json_escape(&item.detail)
        );
    }
    println!("  ]");
    println!("}}");
}

// ============================================================================
// 3. `clous http <port> [path]` — Local HTTP Health, TTFB & Security Headers
// ============================================================================

#[derive(Debug, Clone)]
pub struct HttpCheckReport {
    pub host: String,
    pub port: u16,
    pub path: String,
    pub reachable: bool,
    pub status_code: Option<u16>,
    pub status_text: Option<String>,
    pub connect_ms: u64,
    pub ttfb_ms: u64,
    pub server_header: Option<String>,
    pub content_type: Option<String>,
    pub powered_by: Option<String>,
    pub cors_allow_origin: Option<String>,
    pub cors_wildcard: bool,
    pub has_hsts: bool,
    pub has_csp: bool,
    pub has_xfo: bool,
    pub has_xcto: bool,
    pub error: Option<String>,
}

pub fn probe_http(host: &str, port: u16, path: &str, timeout_ms: u64) -> HttpCheckReport {
    let clean_path = if path.starts_with('/') {
        path.to_string()
    } else {
        format!("/{path}")
    };
    let safe_path: String = clean_path
        .chars()
        .filter(|c| !matches!(c, '\r' | '\n' | '\0' | ' '))
        .take(256)
        .collect();
    let safe_host: String = host
        .chars()
        .filter(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | ':' | '[' | ']'))
        .collect();

    let mut report = HttpCheckReport {
        host: safe_host.clone(),
        port,
        path: safe_path.clone(),
        reachable: false,
        status_code: None,
        status_text: None,
        connect_ms: 0,
        ttfb_ms: 0,
        server_header: None,
        content_type: None,
        powered_by: None,
        cors_allow_origin: None,
        cors_wildcard: false,
        has_hsts: false,
        has_csp: false,
        has_xfo: false,
        has_xcto: false,
        error: None,
    };

    let timeout = Duration::from_millis(timeout_ms.clamp(200, 10_000));
    let addr = match format!("{safe_host}:{port}")
        .to_socket_addrs()
        .ok()
        .and_then(|mut it| it.next())
    {
        Some(a) => a,
        None => {
            report.error = Some(format!("Could not resolve host '{safe_host}'"));
            return report;
        }
    };

    let t0 = Instant::now();
    let mut stream = match TcpStream::connect_timeout(&addr, timeout) {
        Ok(s) => s,
        Err(e) => {
            report.error = Some(format!("TCP connect failed: {e}"));
            return report;
        }
    };
    report.connect_ms = t0.elapsed().as_millis() as u64;
    report.reachable = true;

    let _ = stream.set_read_timeout(Some(timeout));
    let _ = stream.set_write_timeout(Some(timeout));

    let req = format!(
        "GET {safe_path} HTTP/1.1\r\nHost: {safe_host}:{port}\r\nUser-Agent: Clous\r\nAccept: */*\r\nConnection: close\r\n\r\n"
    );
    if let Err(e) = stream.write_all(req.as_bytes()) {
        report.error = Some(format!("HTTP write failed: {e}"));
        return report;
    }

    // Read up to 32 KiB (header cap to prevent memory abuse)
    let mut buf = Vec::with_capacity(4096);
    let mut chunk = [0u8; 2048];
    let mut first_byte_seen = false;
    while buf.len() < 32_768 {
        match stream.read(&mut chunk) {
            Ok(0) => break,
            Ok(n) => {
                if !first_byte_seen {
                    report.ttfb_ms = t0.elapsed().as_millis() as u64;
                    first_byte_seen = true;
                }
                buf.extend_from_slice(&chunk[..n]);
                if buf.windows(4).any(|w| w == b"\r\n\r\n") {
                    break;
                }
            }
            Err(_) => break,
        }
    }

    let raw = String::from_utf8_lossy(&buf);
    let header_block = raw.split("\r\n\r\n").next().unwrap_or(&raw);
    let mut lines = header_block.lines();
    if let Some(status_line) = lines.next() {
        let parts: Vec<&str> = status_line.splitn(3, ' ').collect();
        if parts.len() >= 2 && parts[0].starts_with("HTTP/") {
            report.status_code = parts[1].parse::<u16>().ok();
            report.status_text = Some(status_line.trim().to_string());
        } else {
            report.error = Some("Port responded with non-HTTP protocol data".into());
        }
    } else {
        report.error = Some("Empty response from server".into());
    }

    for line in lines {
        if let Some((k, v)) = line.split_once(':') {
            let key = k.trim().to_lowercase();
            let val = v.trim().to_string();
            match key.as_str() {
                "server" => report.server_header = Some(val),
                "content-type" => report.content_type = Some(val),
                "x-powered-by" => report.powered_by = Some(val),
                "access-control-allow-origin" => {
                    report.cors_wildcard = val == "*";
                    report.cors_allow_origin = Some(val);
                }
                "strict-transport-security" => report.has_hsts = true,
                "content-security-policy" => report.has_csp = true,
                "x-frame-options" => report.has_xfo = true,
                "x-content-type-options" => report.has_xcto = true,
                _ => {}
            }
        }
    }

    report
}

pub fn run_http(host: &str, port: u16, path: &str, timeout_ms: u64, global: &GlobalOptions) -> Result<(), String> {
    let report = probe_http(host, port, path, timeout_ms);
    if global.is_json() {
        print_http_json(&report);
        return Ok(());
    }

    let theme = Theme::new(global.no_color);
    println!();
    println!(
        "{}",
        theme.bold(&format!("Clous HTTP Health — http://{}:{}{}", report.host, report.port, report.path))
    );
    println!("{}", theme.dim("────────────────────────────────────────────────────────────────"));
    if let Some(err) = &report.error {
        println!("{}", theme.red(&format!("✗ {err}")));
    } else if let Some(code) = report.status_code {
        let badge = if (200..300).contains(&code) {
            theme.green(&format!("HTTP {code}"))
        } else if (300..400).contains(&code) {
            theme.cyan(&format!("HTTP {code}"))
        } else {
            theme.red(&format!("HTTP {code}"))
        };
        println!(
            "Status: {badge}  |  Connect: {}ms  |  TTFB: {}ms",
            report.connect_ms, report.ttfb_ms
        );
        if let Some(s) = &report.server_header {
            println!("Server: {s}");
        }
        if let Some(ct) = &report.content_type {
            println!("Content-Type: {ct}");
        }
        if let Some(cors) = &report.cors_allow_origin {
            let warn = if report.cors_wildcard { " (WILDCARD *)" } else { "" };
            println!("CORS: {cors}{warn}");
        }
        println!(
            "Security Headers: HSTS={}  CSP={}  X-Frame-Options={}  X-Content-Type-Options={}",
            if report.has_hsts { "YES" } else { "NO" },
            if report.has_csp { "YES" } else { "NO" },
            if report.has_xfo { "YES" } else { "NO" },
            if report.has_xcto { "YES" } else { "NO" }
        );
    }
    println!();
    Ok(())
}

fn opt_str_json(v: Option<&str>) -> String {
    v.map(|s| format!("\"{}\"", json_escape(s)))
        .unwrap_or_else(|| "null".to_string())
}

fn print_http_json(r: &HttpCheckReport) {
    let code_j = r.status_code.map(|c| c.to_string()).unwrap_or_else(|| "null".into());
    println!("{{");
    println!("  \"host\": \"{}\",", json_escape(&r.host));
    println!("  \"port\": {},", r.port);
    println!("  \"path\": \"{}\",", json_escape(&r.path));
    println!("  \"reachable\": {},", r.reachable);
    println!("  \"status_code\": {code_j},");
    println!("  \"status_text\": {},", opt_str_json(r.status_text.as_deref()));
    println!("  \"connect_ms\": {},", r.connect_ms);
    println!("  \"ttfb_ms\": {},", r.ttfb_ms);
    println!("  \"server_header\": {},", opt_str_json(r.server_header.as_deref()));
    println!("  \"content_type\": {},", opt_str_json(r.content_type.as_deref()));
    println!("  \"powered_by\": {},", opt_str_json(r.powered_by.as_deref()));
    println!("  \"cors_allow_origin\": {},", opt_str_json(r.cors_allow_origin.as_deref()));
    println!("  \"cors_wildcard\": {},", r.cors_wildcard);
    println!("  \"has_hsts\": {},", r.has_hsts);
    println!("  \"has_csp\": {},", r.has_csp);
    println!("  \"has_xfo\": {},", r.has_xfo);
    println!("  \"has_xcto\": {},", r.has_xcto);
    println!("  \"error\": {}", opt_str_json(r.error.as_deref()));
    println!("}}");
}

// ============================================================================
// 4. `clous forward <listen_port> <target_host:port>` — Zero-Dep TCP Forwarder
// ============================================================================

pub fn run_forward(listen_port: u16, target: &str, public_bind: bool) -> Result<(), String> {
    let bind_ip = if public_bind { "0.0.0.0" } else { "127.0.0.1" };
    let bind_addr = format!("{bind_ip}:{listen_port}");
    let target_resolved = target
        .to_socket_addrs()
        .map_err(|e| format!("Invalid target '{target}': {e}"))?
        .next()
        .ok_or_else(|| format!("Could not resolve target '{target}'"))?;

    let listener = TcpListener::bind(&bind_addr)
        .map_err(|e| format!("Failed to bind {bind_addr}: {e}"))?;

    println!("Clous TCP Forwarder active: {bind_addr} -> {target} ({target_resolved})");
    println!("Press Ctrl+C to stop.");

    let active_conns = Arc::new(AtomicUsize::new(0));
    let bytes_up = Arc::new(AtomicU64::new(0));
    let bytes_down = Arc::new(AtomicU64::new(0));

    for incoming in listener.incoming() {
        let client = match incoming {
            Ok(s) => s,
            Err(e) => {
                eprintln!("Accept error: {e}");
                continue;
            }
        };

        let active = Arc::clone(&active_conns);
        let up = Arc::clone(&bytes_up);
        let down = Arc::clone(&bytes_down);

        thread::spawn(move || {
            let upstream = match TcpStream::connect_timeout(&target_resolved, Duration::from_secs(5)) {
                Ok(s) => s,
                Err(_) => return,
            };

            let curr = active.fetch_add(1, Ordering::Relaxed) + 1;
            let _ = curr;

            if let (Ok(mut c_read), Ok(mut c_write), Ok(mut u_read), Ok(mut u_write)) = (
                client.try_clone(),
                client.try_clone(),
                upstream.try_clone(),
                upstream.try_clone(),
            ) {
                let up_clone = Arc::clone(&up);
                let h = thread::spawn(move || {
                    if let Ok(n) = std::io::copy(&mut c_read, &mut u_write) {
                        up_clone.fetch_add(n, Ordering::Relaxed);
                    }
                    let _ = u_write.shutdown(Shutdown::Write);
                });

                if let Ok(n) = std::io::copy(&mut u_read, &mut c_write) {
                    down.fetch_add(n, Ordering::Relaxed);
                }
                let _ = c_write.shutdown(Shutdown::Write);
                let _ = h.join();
            }

            active.fetch_sub(1, Ordering::Relaxed);
        });
    }

    Ok(())
}

#[allow(dead_code)]
fn _unused_bind_scope_guard(_: BindScope) {}

// ============================================================================
// 5. `clous open <port> [--public]` — Lightweight Local HTTP/TCP Port Listener
// ============================================================================

pub fn run_open(port: u16, public_bind: bool) -> Result<(), String> {
    if port == 0 {
        return Err("Port must be between 1 and 65535.".to_string());
    }
    let bind_ip = if public_bind { "0.0.0.0" } else { "127.0.0.1" };
    let bind_addr = format!("{bind_ip}:{port}");
    let listener = TcpListener::bind(&bind_addr)
        .map_err(|e| format!("Failed to open port {port} on {bind_ip}: {e}"))?;

    println!(
        "Clous listener active on http://{bind_addr} (PID {})",
        std::process::id()
    );
    let _ = std::io::stdout().flush();

    let body = format!(
        "{{\"status\":\"ok\",\"service\":\"clous-open\",\"port\":{port},\"bind\":\"{bind_ip}\"}}"
    );
    let response = format!(
        "HTTP/1.1 200 OK\r\nServer: Clous\r\nContent-Type: application/json\r\nX-Content-Type-Options: nosniff\r\nX-Frame-Options: DENY\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        body
    );

    for incoming in listener.incoming() {
        let mut stream = match incoming {
            Ok(s) => s,
            Err(_) => continue,
        };
        let resp = response.clone();
        thread::spawn(move || {
            let _ = stream.set_read_timeout(Some(Duration::from_millis(500)));
            let mut req_buf = [0u8; 1024];
            let _ = stream.read(&mut req_buf);
            let _ = stream.write_all(resp.as_bytes());
            let _ = stream.flush();
            let _ = stream.shutdown(Shutdown::Both);
        });
    }

    Ok(())
}
