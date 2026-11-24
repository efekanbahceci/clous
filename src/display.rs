use std::collections::BTreeMap;

use crate::audit::{AuditReport, Severity};
use crate::models::{
    BindScope, PortEntry, ProbeResult, ProcessAncestor, SocketState, well_known_service,
};
use crate::snapshot::DiffReport;

pub struct Theme {
    color: bool,
}

impl Theme {
    pub fn new(no_color: bool) -> Self {
        Self { color: !no_color }
    }

    pub fn bold(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[1m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn dim(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[2m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn green(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[32m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn red(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[31m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn bold_red(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[1;31m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn yellow(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[33m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn cyan(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[36m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn magenta(&self, s: &str) -> String {
        if self.color {
            format!("\x1b[35m{s}\x1b[0m")
        } else {
            s.to_string()
        }
    }

    pub fn color_state(&self, state: &SocketState, padded: &str) -> String {
        match state {
            SocketState::Listen => self.green(padded),
            SocketState::Established => self.cyan(padded),
            SocketState::TimeWait | SocketState::CloseWait => self.yellow(padded),
            SocketState::Close => self.dim(padded),
            _ => padded.to_string(),
        }
    }

    pub fn color_scope(&self, scope: BindScope, padded: &str) -> String {
        match scope {
            BindScope::Loopback => self.green(padded),
            BindScope::Lan => self.cyan(padded),
            BindScope::AllInterfaces => self.yellow(padded),
            BindScope::Public => self.red(padded),
            BindScope::Unknown => self.dim(padded),
        }
    }

    pub fn color_severity(&self, sev: Severity, padded: &str) -> String {
        match sev {
            Severity::Critical => self.bold_red(padded),
            Severity::High => self.red(padded),
            Severity::Medium => self.yellow(padded),
            Severity::Low => self.cyan(padded),
            Severity::Info => self.dim(padded),
        }
    }
}

pub fn print_ports_table(entries: &[PortEntry], theme: &Theme, wide: bool) {
    print!("{}", render_ports_table(entries, theme, wide));
}

pub fn render_ports_table(entries: &[PortEntry], theme: &Theme, wide: bool) -> String {
    use std::fmt::Write as _;
    let mut out = String::new();

    if entries.is_empty() {
        let _ = writeln!(out, "{}", theme.dim("No matching ports found."));
        return out;
    }

    let proto_w = 5;
    let port_w = 6;
    let scope_w = 7;
    let local_w = entries
        .iter()
        .map(|e| e.local_endpoint().len())
        .max()
        .unwrap_or(13)
        .clamp(13, 28);
    let remote_w = entries
        .iter()
        .map(|e| e.remote_endpoint().len())
        .max()
        .unwrap_or(14)
        .clamp(14, 28);
    let state_w = 11;
    let pid_w = 7;
    let user_w = 10;
    let mem_w = 7;
    let service_w = 12;

    if wide {
        let header = format!(
            "{:<proto_w$} {:<port_w$} {:<scope_w$} {:<local_w$} {:<remote_w$} {:<state_w$} {:<pid_w$} {:<user_w$} {:<mem_w$} {:<service_w$} {:<18} {}",
            "PROTO",
            "PORT",
            "SCOPE",
            "LOCAL",
            "REMOTE",
            "STATE",
            "PID",
            "USER",
            "MEM",
            "SERVICE",
            "PROCESS",
            "COMMAND"
        );
        let _ = writeln!(out, "{}", theme.bold(&header));
        let sep_len = proto_w
            + port_w
            + scope_w
            + local_w
            + remote_w
            + state_w
            + pid_w
            + user_w
            + mem_w
            + service_w
            + 38;
        let _ = writeln!(out, "{}", theme.dim(&"─".repeat(sep_len)));
    } else {
        let header = format!(
            "{:<proto_w$} {:<port_w$} {:<scope_w$} {:<local_w$} {:<remote_w$} {:<state_w$} {:<pid_w$} {:<service_w$} {}",
            "PROTO", "PORT", "SCOPE", "LOCAL", "REMOTE", "STATE", "PID", "SERVICE", "PROCESS"
        );
        let _ = writeln!(out, "{}", theme.bold(&header));
        let sep_len = proto_w
            + port_w
            + scope_w
            + local_w
            + remote_w
            + state_w
            + pid_w
            + service_w
            + 20;
        let _ = writeln!(out, "{}", theme.dim(&"─".repeat(sep_len)));
    }

    for e in entries {
        let local = truncate_str(&e.local_endpoint(), local_w);
        let remote = truncate_str(&e.remote_endpoint(), remote_w);
        let scope = e.bind_scope();
        let scope_colored = theme.color_scope(scope, &format!("{:<scope_w$}", scope.as_str()));
        let state_colored = theme.color_state(&e.state, &format!("{:<state_w$}", e.state.as_str()));
        let pid_str = e
            .pid
            .map(|p| p.to_string())
            .unwrap_or_else(|| "-".to_string());
        let service = well_known_service(e.local_port).unwrap_or("-");
        let proc_name = e.process_name.as_deref().unwrap_or("-");

        if wide {
            let user = truncate_str(e.user.as_deref().unwrap_or("-"), user_w);
            let mem = e.memory_human();
            let cmd = truncate_str(e.cmdline.as_deref().unwrap_or("-"), 56);
            let _ = writeln!(
                out,
                "{:<proto_w$} {} {} {:<local_w$} {:<remote_w$} {} {:<pid_w$} {:<user_w$} {:<mem_w$} {} {:<18} {}",
                e.protocol.as_str(),
                theme.cyan(&format!("{:<port_w$}", e.local_port)),
                scope_colored,
                local,
                remote,
                state_colored,
                pid_str,
                user,
                mem,
                theme.dim(&format!("{:<service_w$}", service)),
                truncate_str(proc_name, 18),
                theme.dim(&cmd)
            );
        } else {
            let tag_suffix = match e.runtime_tag() {
                Some(t) => format!(" {}", theme.magenta(&format!("[{t}]"))),
                None => String::new(),
            };
            let _ = writeln!(
                out,
                "{:<proto_w$} {} {} {:<local_w$} {:<remote_w$} {} {:<pid_w$} {} {}{}",
                e.protocol.as_str(),
                theme.cyan(&format!("{:<port_w$}", e.local_port)),
                scope_colored,
                local,
                remote,
                state_colored,
                pid_str,
                theme.dim(&format!("{:<service_w$}", service)),
                proc_name,
                tag_suffix
            );
        }
    }

    let exposed = entries
        .iter()
        .filter(|e| e.state.is_listening() && e.bind_scope().is_exposed())
        .count();
    let _ = writeln!(
        out,
        "\n{}",
        theme.dim(&format!(
            "Total: {} socket(s) | Exposed listeners: {}",
            entries.len(),
            exposed
        ))
    );
    out
}

pub fn print_ports_compact(entries: &[PortEntry], theme: &Theme) {
    print!("{}", render_ports_compact(entries, theme));
}

pub fn render_ports_compact(entries: &[PortEntry], theme: &Theme) -> String {
    use std::fmt::Write as _;
    let mut out = String::new();
    if entries.is_empty() {
        let _ = writeln!(out, "{}", theme.dim("No matching ports found."));
        return out;
    }
    for e in entries {
        let scope = e.bind_scope();
        let pid_part = e
            .pid
            .map(|p| format!("pid:{p}"))
            .unwrap_or_else(|| "pid:-".to_string());
        let proc_name = e.process_name.as_deref().unwrap_or("-");
        let _ = writeln!(
            out,
            "{:<4} {:>5} {} {:<11} {} ({})",
            e.protocol.as_str(),
            theme.cyan(&format!("{:>5}", e.local_port)),
            theme.color_scope(scope, &format!("[{:^6}]", scope.as_str())),
            e.state.as_str(),
            proc_name,
            theme.dim(&pid_part)
        );
    }
    out
}

pub fn print_ports_csv(entries: &[PortEntry]) {
    println!("protocol,local_addr,local_port,remote_addr,remote_port,state,scope,pid,ppid,user,memory_kb,service,process,cmdline");
    for e in entries {
        println!(
            "{},{},{},{},{},{},{},{},{},{},{},{},{},{}",
            e.protocol.as_str(),
            csv_escape(&e.local_addr),
            e.local_port,
            csv_escape(&e.remote_addr),
            e.remote_port,
            csv_escape(e.state.as_str()),
            e.bind_scope().as_str(),
            e.pid.map(|v| v.to_string()).unwrap_or_default(),
            e.ppid.map(|v| v.to_string()).unwrap_or_default(),
            csv_escape(e.user.as_deref().unwrap_or("")),
            e.memory_kb.map(|v| v.to_string()).unwrap_or_default(),
            csv_escape(well_known_service(e.local_port).unwrap_or("")),
            csv_escape(e.process_name.as_deref().unwrap_or("")),
            csv_escape(e.cmdline.as_deref().unwrap_or("")),
        );
    }
}

pub fn port_entry_to_json(e: &PortEntry) -> String {
    let pid_json = opt_u64_json(e.pid.map(u64::from));
    let ppid_json = opt_u64_json(e.ppid.map(u64::from));
    let mem_json = opt_u64_json(e.memory_kb);
    let user_json = opt_str_json(e.user.as_deref());
    let proc_json = opt_str_json(e.process_name.as_deref());
    let cmd_json = opt_str_json(e.cmdline.as_deref());
    let svc_json = opt_str_json(well_known_service(e.local_port));
    let tag_json = opt_str_json(e.runtime_tag());

    format!(
        "{{\"protocol\":\"{}\",\"local_addr\":\"{}\",\"local_port\":{},\"remote_addr\":\"{}\",\"remote_port\":{},\"state\":\"{}\",\"bind_scope\":\"{}\",\"pid\":{},\"ppid\":{},\"user\":{},\"memory_kb\":{},\"process\":{},\"runtime\":{},\"service\":{},\"cmdline\":{}}}",
        e.protocol.as_str(),
        json_escape(&e.local_addr),
        e.local_port,
        json_escape(&e.remote_addr),
        e.remote_port,
        json_escape(e.state.as_str()),
        e.bind_scope().as_str(),
        pid_json,
        ppid_json,
        user_json,
        mem_json,
        proc_json,
        tag_json,
        svc_json,
        cmd_json
    )
}

pub fn print_ports_json(entries: &[PortEntry]) {
    println!("[");
    for (idx, e) in entries.iter().enumerate() {
        let comma = if idx + 1 < entries.len() { "," } else { "" };
        println!("  {}{}", port_entry_to_json(e), comma);
    }
    println!("]");
}

pub fn print_probe_results(
    results: &[ProbeResult],
    theme: &Theme,
    json: bool,
    open_only: bool,
    show_banner: bool,
) {
    let filtered: Vec<&ProbeResult> = results.iter().filter(|r| !open_only || r.open).collect();

    if json {
        println!("[");
        for (idx, r) in filtered.iter().enumerate() {
            let comma = if idx + 1 < filtered.len() { "," } else { "" };
            println!(
                "  {{\"host\":\"{}\",\"port\":{},\"open\":{},\"latency_ms\":{:.2},\"service\":{},\"detected_protocol\":{},\"banner\":{}}}{}",
                json_escape(&r.host),
                r.port,
                r.open,
                r.latency_ms,
                opt_str_json(r.service_hint),
                opt_str_json(r.detected_protocol.as_deref()),
                opt_str_json(r.banner.as_deref()),
                comma
            );
        }
        println!("]");
        return;
    }

    let open_count = results.iter().filter(|r| r.open).count();
    if show_banner {
        println!(
            "{}",
            theme.bold(&format!(
                "{:<7} {:<8} {:<11} {:<13} {:<10} {}",
                "PORT", "STATUS", "LATENCY", "SERVICE", "PROTO", "BANNER"
            ))
        );
        println!("{}", theme.dim(&"─".repeat(84)));
    } else {
        println!(
            "{}",
            theme.bold(&format!(
                "{:<7} {:<10} {:<12} {:<14} {}",
                "PORT", "STATUS", "LATENCY", "SERVICE", "TARGET"
            ))
        );
        println!("{}", theme.dim(&"─".repeat(62)));
    }

    for r in &filtered {
        let status = if r.open {
            theme.green(&format!("{:<8}", "OPEN"))
        } else {
            theme.red(&format!("{:<8}", "CLOSED"))
        };
        let latency = format!("{:.2} ms", r.latency_ms);
        let svc = r.service_hint.unwrap_or("-");
        if show_banner {
            let proto = r.detected_protocol.as_deref().unwrap_or("-");
            let banner = r.banner.as_deref().unwrap_or("-");
            println!(
                "{:<7} {} {:<11} {:<13} {:<10} {}",
                r.port,
                status,
                latency,
                svc,
                theme.cyan(proto),
                theme.dim(&truncate_str(banner, 42))
            );
        } else {
            let status_wide = if r.open {
                theme.green(&format!("{:<10}", "OPEN"))
            } else {
                theme.red(&format!("{:<10}", "CLOSED"))
            };
            println!(
                "{:<7} {} {:<12} {:<14} {}:{}",
                r.port, status_wide, latency, svc, r.host, r.port
            );
        }
    }

    let open_latencies: Vec<f64> = results
        .iter()
        .filter(|r| r.open)
        .map(|r| r.latency_ms)
        .collect();
    let lat_summary = if !open_latencies.is_empty() {
        let min = open_latencies
            .iter()
            .copied()
            .fold(f64::INFINITY, f64::min);
        let max = open_latencies.iter().copied().fold(0.0_f64, f64::max);
        let avg = open_latencies.iter().sum::<f64>() / open_latencies.len() as f64;
        format!(" | open latency min/avg/max: {min:.2}/{avg:.2}/{max:.2} ms")
    } else {
        String::new()
    };

    println!(
        "\n{}",
        theme.dim(&format!(
            "Scanned {} port(s): {} open, {} closed{}",
            results.len(),
            open_count,
            results.len() - open_count,
            lat_summary
        ))
    );
}

pub fn print_stats(entries: &[PortEntry], theme: &Theme, json: bool) {
    let mut by_proto: BTreeMap<&str, usize> = BTreeMap::new();
    let mut by_state: BTreeMap<String, usize> = BTreeMap::new();
    let mut by_scope: BTreeMap<&str, usize> = BTreeMap::new();
    let mut by_proc: BTreeMap<String, usize> = BTreeMap::new();

    for e in entries {
        *by_proto.entry(e.protocol.as_str()).or_insert(0) += 1;
        *by_state.entry(e.state.as_str().to_string()).or_insert(0) += 1;
        if e.state.is_listening() || (e.protocol.is_udp() && e.local_port > 0) {
            *by_scope.entry(e.bind_scope().as_str()).or_insert(0) += 1;
        }
        let pname = e
            .process_name
            .clone()
            .unwrap_or_else(|| "<unknown>".to_string());
        *by_proc.entry(pname).or_insert(0) += 1;
    }

    let mut top_procs: Vec<(String, usize)> = by_proc.into_iter().collect();
    top_procs.sort_by(|a, b| b.1.cmp(&a.1).then_with(|| a.0.cmp(&b.0)));
    top_procs.truncate(10);

    if json {
        println!("{{");
        println!("  \"total\": {},", entries.len());

        print!("  \"by_protocol\": {{");
        for (i, (k, v)) in by_proto.iter().enumerate() {
            if i > 0 {
                print!(", ");
            }
            print!("\"{}\": {}", json_escape(k), v);
        }
        println!("}},");

        print!("  \"by_state\": {{");
        for (i, (k, v)) in by_state.iter().enumerate() {
            if i > 0 {
                print!(", ");
            }
            print!("\"{}\": {}", json_escape(k), v);
        }
        println!("}},");

        print!("  \"listening_by_scope\": {{");
        for (i, (k, v)) in by_scope.iter().enumerate() {
            if i > 0 {
                print!(", ");
            }
            print!("\"{}\": {}", json_escape(k), v);
        }
        println!("}},");

        print!("  \"top_processes\": [");
        for (i, (k, v)) in top_procs.iter().enumerate() {
            if i > 0 {
                print!(", ");
            }
            print!("{{\"name\":\"{}\",\"count\":{}}}", json_escape(k), v);
        }
        println!("]");
        println!("}}");
        return;
    }

    println!("{}", theme.bold("Clous — Socket Statistics"));
    println!("{}", theme.dim(&"─".repeat(58)));
    println!(
        "Total sockets: {}\n",
        theme.cyan(&entries.len().to_string())
    );

    let max_proto = by_proto.values().copied().max().unwrap_or(1);
    println!("{}", theme.bold("By Protocol:"));
    for (proto, count) in &by_proto {
        println!(
            "  {:<12} {:>4}  {}",
            proto,
            count,
            theme.cyan(&ascii_bar(*count, max_proto, 24))
        );
    }

    let max_state = by_state.values().copied().max().unwrap_or(1);
    println!("\n{}", theme.bold("By State:"));
    for (state, count) in &by_state {
        println!(
            "  {:<14} {:>4}  {}",
            state,
            count,
            theme.green(&ascii_bar(*count, max_state, 24))
        );
    }

    if !by_scope.is_empty() {
        let max_scope = by_scope.values().copied().max().unwrap_or(1);
        println!("\n{}", theme.bold("Listening Bind Exposure:"));
        for (scope, count) in &by_scope {
            println!(
                "  {:<14} {:>4}  {}",
                scope,
                count,
                theme.yellow(&ascii_bar(*count, max_scope, 24))
            );
        }
    }

    let max_proc = top_procs.first().map(|(_, c)| *c).unwrap_or(1);
    println!("\n{}", theme.bold("Top Processes:"));
    for (proc_name, count) in &top_procs {
        println!(
            "  {:<22} {:>4}  {}",
            truncate_str(proc_name, 22),
            count,
            theme.magenta(&ascii_bar(*count, max_proc, 20))
        );
    }
}

pub fn print_audit_report(report: &AuditReport, theme: &Theme, json: bool) {
    if json {
        let opt_bool = |b: Option<bool>| match b {
            Some(true) => "true",
            Some(false) => "false",
            None => "null",
        };
        println!("{{");
        println!("  \"profile\": \"{}\",", report.profile.as_str());
        println!("  \"deep_scan\": {},", report.deep_scan);
        println!("  \"score\": {},", report.score);
        println!("  \"grade\": \"{}\",", report.grade);
        println!("  \"total_sockets\": {},", report.total_sockets);
        println!("  \"listening_count\": {},", report.listening_count);
        println!("  \"exposed_count\": {},", report.exposed_count);
        println!(
            "  \"posture\": {{\"firewall_enabled\":{},\"stealth_mode\":{},\"verified_binaries\":{},\"unsigned_binaries\":{},\"suspicious_path_binaries\":{}}},",
            opt_bool(report.posture.firewall_enabled),
            opt_bool(report.posture.stealth_mode),
            report.posture.verified_binaries,
            report.posture.unsigned_binaries,
            report.posture.suspicious_path_binaries
        );
        println!("  \"binary_trusts\": [");
        for (i, b) in report.binary_trusts.iter().enumerate() {
            let comma = if i + 1 < report.binary_trusts.len() { "," } else { "" };
            let ports_s: String = b
                .ports
                .iter()
                .map(|p| p.to_string())
                .collect::<Vec<_>>()
                .join(",");
            println!(
                "    {{\"process\":\"{}\",\"path\":\"{}\",\"trust\":\"{}\",\"authority\":{},\"suspicious_path\":{},\"ports\":[{}]}}{}",
                json_escape(&b.process),
                json_escape(&b.path),
                b.trust.as_str(),
                opt_str_json(b.authority.as_deref()),
                b.suspicious_path,
                ports_s,
                comma
            );
        }
        println!("  ],");
        println!("  \"findings\": [");
        for (i, f) in report.findings.iter().enumerate() {
            let comma = if i + 1 < report.findings.len() { "," } else { "" };
            println!(
                "    {{\"severity\":\"{}\",\"code\":\"{}\",\"port\":{},\"process\":{},\"endpoint\":{},\"title\":\"{}\",\"recommendation\":\"{}\",\"remediation_cmd\":{}}}{}",
                f.severity.as_str(),
                f.code,
                opt_u64_json(f.port.map(u64::from)),
                opt_str_json(f.process.as_deref()),
                opt_str_json(f.endpoint.as_deref()),
                json_escape(&f.title),
                json_escape(&f.recommendation),
                opt_str_json(f.remediation_cmd.as_deref()),
                comma
            );
        }
        println!("  ]");
        println!("}}");
        return;
    }

    let score_str = format!("{}/100 (Grade {})", report.score, report.grade);
    let score_colored = match report.score {
        90..=100 => theme.green(&score_str),
        70..=89 => theme.yellow(&score_str),
        _ => theme.bold_red(&score_str),
    };

    println!(
        "{} {}",
        theme.bold("Clous — Security & Binary Trust Audit"),
        theme.dim(&format!(
            "(profile: {}{})",
            report.profile.as_str(),
            if report.deep_scan { " | deep" } else { "" }
        ))
    );
    println!("{}", theme.dim(&"─".repeat(68)));
    println!(
        "Score: {}  |  Sockets: {}  |  Listening: {}  |  Exposed: {}",
        score_colored, report.total_sockets, report.listening_count, report.exposed_count
    );
    let fw_s = match report.posture.firewall_enabled {
        Some(true) => theme.green("ON"),
        Some(false) => theme.red("OFF"),
        None => theme.dim("N/A"),
    };
    let stealth_s = match report.posture.stealth_mode {
        Some(true) => theme.green("ON"),
        Some(false) => theme.yellow("OFF"),
        None => theme.dim("N/A"),
    };
    println!(
        "Posture: Firewall {}  |  Stealth {}  |  Signed Binaries: {}  |  Unsigned: {}\n",
        fw_s,
        stealth_s,
        theme.green(&report.posture.verified_binaries.to_string()),
        if report.posture.unsigned_binaries > 0 {
            theme.red(&report.posture.unsigned_binaries.to_string())
        } else {
            theme.dim("0")
        }
    );

    if report.findings.is_empty() {
        println!(
            "{} No security or socket health issues detected.",
            theme.green("✓")
        );
        return;
    }

    for f in &report.findings {
        let badge = theme.color_severity(f.severity, &format!("[{:^8}]", f.severity.as_str()));
        let proc_info = match (&f.process, &f.endpoint) {
            (Some(p), Some(ep)) => format!(" ({p} @ {ep})"),
            (None, Some(ep)) => format!(" ({ep})"),
            _ => String::new(),
        };
        println!(
            "{} {} {}{}",
            badge,
            theme.dim(f.code),
            theme.bold(&f.title),
            theme.dim(&proc_info)
        );
        println!("           {} {}", theme.dim("Fix:"), f.recommendation);
    }
}

pub fn print_diff_report(report: &DiffReport, theme: &Theme, json: bool) {
    if json {
        println!("{{");
        println!(
            "  \"baseline_created_unix\": {},",
            report.baseline_created_unix
        );
        println!("  \"has_drift\": {},", report.has_drift());
        println!("  \"unchanged_count\": {},", report.unchanged_count);
        println!("  \"added\": [");
        for (i, e) in report.added.iter().enumerate() {
            let comma = if i + 1 < report.added.len() { "," } else { "" };
            println!(
                "    {{\"protocol\":\"{}\",\"local_addr\":\"{}\",\"local_port\":{},\"pid\":{},\"process\":{}}}{}",
                e.protocol.as_str(),
                json_escape(&e.local_addr),
                e.local_port,
                opt_u64_json(e.pid.map(u64::from)),
                opt_str_json(e.process_name.as_deref()),
                comma
            );
        }
        println!("  ],");
        println!("  \"removed\": [");
        for (i, e) in report.removed.iter().enumerate() {
            let comma = if i + 1 < report.removed.len() { "," } else { "" };
            println!(
                "    {{\"protocol\":\"{}\",\"local_addr\":\"{}\",\"local_port\":{},\"pid\":{},\"process\":{}}}{}",
                e.protocol.as_str(),
                json_escape(&e.local_addr),
                e.local_port,
                opt_u64_json(e.pid.map(u64::from)),
                opt_str_json(e.process_name.as_deref()),
                comma
            );
        }
        println!("  ],");
        println!("  \"changed\": [");
        for (i, c) in report.changed.iter().enumerate() {
            let comma = if i + 1 < report.changed.len() { "," } else { "" };
            let details = c.changes.join("; ");
            println!(
                "    {{\"protocol\":\"{}\",\"local_port\":{},\"before_process\":{},\"after_process\":{},\"changes\":\"{}\"}}{}",
                c.after.protocol.as_str(),
                c.after.local_port,
                opt_str_json(c.before.process_name.as_deref()),
                opt_str_json(c.after.process_name.as_deref()),
                json_escape(&details),
                comma
            );
        }
        println!("  ]");
        println!("}}");
        return;
    }

    println!("{}", theme.bold("Clous — Baseline Drift Diff"));
    println!("{}", theme.dim(&"─".repeat(60)));
    if !report.has_drift() {
        println!(
            "{} No drift detected ({} port(s) unchanged).",
            theme.green("✓"),
            report.unchanged_count
        );
        return;
    }

    for e in &report.added {
        println!(
            "  {} {:<5} {:<20} (PID: {}, {})",
            theme.green("+ ADDED  "),
            e.protocol.as_str(),
            sanitize_terminal(&format!("{}:{}", e.local_addr, e.local_port)),
            e.pid.map(|p| p.to_string()).unwrap_or_else(|| "-".into()),
            sanitize_terminal(e.process_name.as_deref().unwrap_or("-"))
        );
    }
    for e in &report.removed {
        println!(
            "  {} {:<5} {:<20} (was PID: {}, {})",
            theme.red("- REMOVED"),
            e.protocol.as_str(),
            sanitize_terminal(&format!("{}:{}", e.local_addr, e.local_port)),
            e.pid.map(|p| p.to_string()).unwrap_or_else(|| "-".into()),
            sanitize_terminal(e.process_name.as_deref().unwrap_or("-"))
        );
    }
    for c in &report.changed {
        println!(
            "  {} {:<5} :{:<6} {}",
            theme.yellow("~ CHANGED"),
            c.after.protocol.as_str(),
            c.after.local_port,
            sanitize_terminal(&c.changes.join(" | "))
        );
    }

    println!(
        "\n{}",
        theme.dim(&format!(
            "Summary: +{} added, -{} removed, ~{} changed, {} unchanged",
            report.added.len(),
            report.removed.len(),
            report.changed.len(),
            report.unchanged_count
        ))
    );
}

pub fn print_inspect_report(
    port: u16,
    entries: &[PortEntry],
    ancestors: &[ProcessAncestor],
    peer_connections: &[PortEntry],
    probe: Option<&ProbeResult>,
    theme: &Theme,
    json: bool,
) {
    if json {
        println!("{{");
        println!("  \"port\": {},", port);
        println!(
            "  \"service\": {},",
            opt_str_json(well_known_service(port))
        );
        println!("  \"sockets\": [");
        for (i, e) in entries.iter().enumerate() {
            let comma = if i + 1 < entries.len() { "," } else { "" };
            println!(
                "    {{\"protocol\":\"{}\",\"local\":\"{}\",\"remote\":\"{}\",\"state\":\"{}\",\"scope\":\"{}\",\"pid\":{},\"user\":{},\"memory_kb\":{},\"process\":{},\"cmdline\":{}}}{}",
                e.protocol.as_str(),
                json_escape(&e.local_endpoint()),
                json_escape(&e.remote_endpoint()),
                json_escape(e.state.as_str()),
                e.bind_scope().as_str(),
                opt_u64_json(e.pid.map(u64::from)),
                opt_str_json(e.user.as_deref()),
                opt_u64_json(e.memory_kb),
                opt_str_json(e.process_name.as_deref()),
                opt_str_json(e.cmdline.as_deref()),
                comma
            );
        }
        println!("  ],");
        println!("  \"ancestry\": [");
        for (i, a) in ancestors.iter().enumerate() {
            let comma = if i + 1 < ancestors.len() { "," } else { "" };
            println!(
                "    {{\"pid\":{},\"ppid\":{},\"user\":{},\"name\":\"{}\",\"memory_kb\":{},\"cmdline\":{}}}{}",
                a.pid,
                opt_u64_json(a.ppid.map(u64::from)),
                opt_str_json(a.user.as_deref()),
                json_escape(&a.name),
                opt_u64_json(a.memory_kb),
                opt_str_json(a.cmdline.as_deref()),
                comma
            );
        }
        println!("  ],");
        println!("  \"active_peers\": {},", peer_connections.len());
        if let Some(p) = probe {
            println!(
                "  \"probe\": {{\"open\":{},\"latency_ms\":{:.2},\"detected_protocol\":{},\"banner\":{}}}",
                p.open,
                p.latency_ms,
                opt_str_json(p.detected_protocol.as_deref()),
                opt_str_json(p.banner.as_deref())
            );
        } else {
            println!("  \"probe\": null");
        }
        println!("}}");
        return;
    }

    let svc = well_known_service(port).unwrap_or("Unknown");
    println!(
        "{} {} {}",
        theme.bold("Clous Deep Inspect — Port"),
        theme.cyan(&port.to_string()),
        theme.dim(&format!("({svc})"))
    );
    println!("{}", theme.dim(&"─".repeat(66)));

    if entries.is_empty() {
        println!(
            "{}",
            theme.yellow(&format!("No local socket currently bound on port {port}."))
        );
    } else {
        println!("{}", theme.bold("Bindings:"));
        for e in entries {
            let scope = e.bind_scope();
            println!(
                "  {} {:<22} {}  State: {}  PID: {}  User: {}  Mem: {}",
                theme.bold(e.protocol.as_str()),
                e.local_endpoint(),
                theme.color_scope(scope, &format!("[{}]", scope.as_str())),
                theme.color_state(&e.state, e.state.as_str()),
                e.pid.map(|p| p.to_string()).unwrap_or_else(|| "-".into()),
                e.user.as_deref().unwrap_or("-"),
                e.memory_human()
            );
            if let Some(ref cmd) = e.cmdline {
                println!("    {}", theme.dim(&format!("CMD: {cmd}")));
            }
        }
    }

    if !ancestors.is_empty() {
        println!("\n{}", theme.bold("Process Ancestry:"));
        for (depth, a) in ancestors.iter().enumerate() {
            let prefix = if depth == 0 { "●" } else { "└─" };
            let indent = "  ".repeat(depth + 1);
            println!(
                "{}{} {} (PID {}, user: {})",
                indent,
                theme.cyan(prefix),
                theme.bold(&a.name),
                a.pid,
                a.user.as_deref().unwrap_or("-")
            );
        }
    }

    if !peer_connections.is_empty() {
        println!(
            "\n{} ({}):",
            theme.bold("Active Peer Connections"),
            peer_connections.len()
        );
        for p in peer_connections.iter().take(15) {
            println!(
                "  {} {} -> {}  [{}]",
                p.protocol.as_str(),
                p.local_endpoint(),
                p.remote_endpoint(),
                theme.color_state(&p.state, p.state.as_str())
            );
        }
        if peer_connections.len() > 15 {
            println!(
                "  {}",
                theme.dim(&format!("... and {} more", peer_connections.len() - 15))
            );
        }
    }

    if let Some(p) = probe {
        println!("\n{}", theme.bold("Live Probe:"));
        let st = if p.open {
            theme.green("OPEN")
        } else {
            theme.red("CLOSED")
        };
        println!(
            "  Status: {}  |  Latency: {:.2} ms  |  Detected: {}",
            st,
            p.latency_ms,
            p.detected_protocol.as_deref().unwrap_or("-")
        );
        if let Some(ref b) = p.banner {
            println!("  Banner: {}", theme.cyan(&sanitize_terminal(b)));
        }
    }
}

/// Strip ASCII C0/DEL and C1 control characters (including ESC, BEL, CR, LF) before printing untrusted text to a terminal.
pub fn sanitize_terminal(s: &str) -> String {
    s.chars().filter(|c| !c.is_control()).collect()
}

fn ascii_bar(value: usize, max_val: usize, width: usize) -> String {
    if max_val == 0 || value == 0 {
        return String::new();
    }
    let filled = ((value as f64 / max_val as f64) * width as f64).round() as usize;
    let filled = filled.clamp(1, width);
    "█".repeat(filled)
}

fn truncate_str(s: &str, max_chars: usize) -> String {
    let count = s.chars().count();
    if count <= max_chars {
        s.to_string()
    } else if max_chars <= 1 {
        "…".to_string()
    } else {
        let mut out: String = s.chars().take(max_chars - 1).collect();
        out.push('…');
        out
    }
}

fn csv_escape(s: &str) -> String {
    if s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r') {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

fn opt_u64_json(val: Option<u64>) -> String {
    match val {
        Some(v) => v.to_string(),
        None => "null".to_string(),
    }
}

fn opt_str_json(val: Option<&str>) -> String {
    match val {
        Some(s) => format!("\"{}\"", json_escape(s)),
        None => "null".to_string(),
    }
}

pub fn json_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}
