 use std::collections::BTreeMap;

use crate::models::{PortEntry, ProbeResult, SocketState, well_known_service};

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

    pub fn color_state(&self, state: &SocketState, padded: &str) -> String {
        match state {
            SocketState::Listen => self.green(padded),
            SocketState::Established => self.cyan(padded),
            SocketState::TimeWait | SocketState::CloseWait => self.yellow(padded),
            SocketState::Close => self.dim(padded),
            _ => padded.to_string(),
        }
    }
}

pub fn print_ports_table(entries: &[PortEntry], theme: &Theme) {
    if entries.is_empty() {
        println!("{}", theme.dim("No matching ports found."));
        return;
    }

    let proto_w = 5;
    let port_w = 7;
    let local_w = entries
        .iter()
        .map(|e| e.local_endpoint().len())
        .max()
        .unwrap_or(13)
        .max(13);
    let remote_w = entries
        .iter()
        .map(|e| e.remote_endpoint().len())
        .max()
        .unwrap_or(14)
        .max(14);
    let state_w = 12;
    let pid_w = 7;
    let service_w = 12;

    let header = format!(
        "{:<proto_w$} {:<port_w$} {:<local_w$} {:<remote_w$} {:<state_w$} {:<pid_w$} {:<service_w$} {}",
        "PROTO", "PORT", "LOCAL", "REMOTE", "STATE", "PID", "SERVICE", "PROCESS"
    );
    println!("{}", theme.bold(&header));
    println!(
        "{}",
        theme.dim(&"─".repeat(proto_w + port_w + local_w + remote_w + state_w + pid_w + service_w + 18))
    );

    for e in entries {
        let local = e.local_endpoint();
        let remote = e.remote_endpoint();
        let state_padded = format!("{:<state_w$}", e.state.as_str());
        let state_colored = theme.color_state(&e.state, &state_padded);
        let pid_str = e
            .pid
            .map(|p| p.to_string())
            .unwrap_or_else(|| "-".to_string());
        let service = well_known_service(e.local_port).unwrap_or("-");
        let proc_name = e.process_name.as_deref().unwrap_or("-");

        println!(
            "{:<proto_w$} {:<port_w$} {:<local_w$} {:<remote_w$} {} {:<pid_w$} {:<service_w$} {}",
            e.protocol.as_str(),
            theme.cyan(&format!("{:<port_w$}", e.local_port)),
            local,
            remote,
            state_colored,
            pid_str,
            theme.dim(&format!("{:<service_w$}", service)),
            proc_name
        );
    }

    println!(
        "\n{}",
        theme.dim(&format!("Total: {} socket(s)", entries.len()))
    );
}

pub fn print_ports_json(entries: &[PortEntry]) {
    println!("[");
    for (idx, e) in entries.iter().enumerate() {
        let comma = if idx + 1 < entries.len() { "," } else { "" };
        let pid_json = e
            .pid
            .map(|p| p.to_string())
            .unwrap_or_else(|| "null".to_string());
        let proc_json = opt_str_json(e.process_name.as_deref());
        let cmd_json = opt_str_json(e.cmdline.as_deref());
        let svc_json = opt_str_json(well_known_service(e.local_port));

        println!(
            "  {{\"protocol\":\"{}\",\"local_addr\":\"{}\",\"local_port\":{},\"remote_addr\":\"{}\",\"remote_port\":{},\"state\":\"{}\",\"pid\":{},\"process\":{},\"service\":{},\"cmdline\":{}}}{}",
            e.protocol.as_str(),
            json_escape(&e.local_addr),
            e.local_port,
            json_escape(&e.remote_addr),
            e.remote_port,
            json_escape(e.state.as_str()),
            pid_json,
            proc_json,
            svc_json,
            cmd_json,
            comma
        );
    }
    println!("]");
}

pub fn print_probe_results(results: &[ProbeResult], theme: &Theme, json: bool) {
    if json {
        println!("[");
        for (idx, r) in results.iter().enumerate() {
            let comma = if idx + 1 < results.len() { "," } else { "" };
            println!(
                "  {{\"host\":\"{}\",\"port\":{},\"open\":{},\"latency_ms\":{:.2},\"service\":{}}}{}",
                json_escape(&r.host),
                r.port,
                r.open,
                r.latency_ms,
                opt_str_json(r.service_hint),
                comma
            );
        }
        println!("]");
        return;
    }

    let open_count = results.iter().filter(|r| r.open).count();
    println!(
        "{}",
        theme.bold(&format!(
            "{:<7} {:<10} {:<12} {:<14} {}",
            "PORT", "STATUS", "LATENCY", "SERVICE", "TARGET"
        ))
    );
    println!("{}", theme.dim(&"─".repeat(60)));

    for r in results {
        let status = if r.open {
            theme.green(&format!("{:<10}", "OPEN"))
        } else {
            theme.red(&format!("{:<10}", "CLOSED"))
        };
        let latency = format!("{:.2} ms", r.latency_ms);
        let svc = r.service_hint.unwrap_or("-");
        println!(
            "{:<7} {} {:<12} {:<14} {}:{}",
            r.port, status, latency, svc, r.host, r.port
        );
    }

    println!(
        "\n{}",
        theme.dim(&format!(
            "Scanned {} port(s): {} open, {} closed",
            results.len(),
            open_count,
            results.len() - open_count
        ))
    );
}

pub fn print_stats(entries: &[PortEntry], theme: &Theme, json: bool) {
    let mut by_proto: BTreeMap<&str, usize> = BTreeMap::new();
    let mut by_state: BTreeMap<String, usize> = BTreeMap::new();
    let mut by_proc: BTreeMap<String, usize> = BTreeMap::new();

    for e in entries {
        *by_proto.entry(e.protocol.as_str()).or_insert(0) += 1;
        *by_state.entry(e.state.as_str().to_string()).or_insert(0) += 1;
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

    println!("{}", theme.bold("SierraPort — Socket Statistics"));
    println!("{}", theme.dim(&"─".repeat(42)));
    println!("Total sockets: {}\n", theme.cyan(&entries.len().to_string()));

    println!("{}", theme.bold("By Protocol:"));
    for (proto, count) in &by_proto {
        println!("  {:<12} {}", proto, count);
    }

    println!("\n{}", theme.bold("By State:"));
    for (state, count) in &by_state {
        println!("  {:<14} {}", state, count);
    }

    println!("\n{}", theme.bold("Top Processes:"));
    for (proc_name, count) in &top_procs {
        println!("  {:<24} {}", proc_name, count);
    }
}

fn opt_str_json(val: Option<&str>) -> String {
    match val {
        Some(s) => format!("\"{}\"", json_escape(s)),
        None => "null".to_string(),
    }
}

fn json_escape(s: &str) -> String {
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
