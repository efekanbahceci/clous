use std::process::Command;

use crate::models::{PortEntry, Protocol, SocketState};

/// Scan active TCP/UDP sockets on macOS using `lsof`.
pub fn scan_system_ports() -> Result<Vec<PortEntry>, String> {
    let output = Command::new("lsof")
        .args(["-nP", "-iTCP", "-iUDP"])
        .output()
        .map_err(|e| format!("Failed to execute lsof: {e}"))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut entries = Vec::new();

    for line in stdout.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 9 {
            continue;
        }

        let process_name = Some(cols[0].to_string());
        let pid = cols[1].parse::<u32>().ok();
        let ip_type = cols[4]; // IPv4 or IPv6
        let proto_raw = cols[7]; // TCP or UDP

        let protocol = match (proto_raw, ip_type) {
            ("TCP", "IPv6") => Protocol::Tcp6,
            ("TCP", _) => Protocol::Tcp,
            ("UDP", "IPv6") => Protocol::Udp6,
            ("UDP", _) => Protocol::Udp,
            _ => continue,
        };

        let name_col = cols[8];
        let state_col = cols.get(9).copied().unwrap_or("");
        let state = if state_col.starts_with('(') && state_col.ends_with(')') {
            SocketState::from_name(&state_col[1..state_col.len() - 1])
        } else if protocol.is_udp() {
            SocketState::Listen
        } else {
            SocketState::Unknown("UNKNOWN".to_string())
        };

        let (local_part, remote_part) = if let Some((l, r)) = name_col.split_once("->") {
            (l, Some(r))
        } else {
            (name_col, None)
        };

        let Some((local_addr, local_port)) = split_host_port(local_part) else {
            continue;
        };
        let (remote_addr, remote_port) = remote_part
            .and_then(split_host_port)
            .unwrap_or_else(|| ("*".to_string(), 0));

        entries.push(PortEntry {
            protocol,
            local_addr,
            local_port,
            remote_addr,
            remote_port,
            state,
            pid,
            process_name,
            cmdline: None,
        });
    }

    entries.sort_by(|a, b| {
        a.local_port
            .cmp(&b.local_port)
            .then_with(|| a.protocol.cmp(&b.protocol))
    });

    Ok(entries)
}

fn split_host_port(s: &str) -> Option<(String, u16)> {
    let (host, port_s) = s.rsplit_once(':')?;
    let port = port_s.parse::<u16>().ok()?;
    let clean_host = host.trim_matches(|c| c == '[' || c == ']').to_string();
    Some((clean_host, port))
}
