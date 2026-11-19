use std::collections::HashMap;
use std::process::Command;

use crate::models::{PortEntry, Protocol, SocketState};

/// Scan active TCP/UDP sockets on Windows using `netstat -ano` and `tasklist`.
pub fn scan_system_ports() -> Result<Vec<PortEntry>, String> {
    let pid_names = fetch_windows_process_names();

    let output = Command::new("netstat")
        .args(["-ano"])
        .output()
        .map_err(|e| format!("Failed to execute netstat: {e}"))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut entries = Vec::new();

    for line in stdout.lines() {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 4 {
            continue;
        }

        let proto_str = cols[0].to_ascii_uppercase();
        if proto_str != "TCP" && proto_str != "UDP" {
            continue;
        }

        let Some((local_addr, local_port)) = split_host_port(cols[1]) else {
            continue;
        };
        let (remote_addr, remote_port) =
            split_host_port(cols[2]).unwrap_or_else(|| ("*".to_string(), 0));

        let is_v6 = local_addr.contains(':');
        let protocol = match (proto_str.as_str(), is_v6) {
            ("TCP", true) => Protocol::Tcp6,
            ("TCP", false) => Protocol::Tcp,
            ("UDP", true) => Protocol::Udp6,
            _ => Protocol::Udp,
        };

        let (state, pid_str) = if proto_str == "TCP" && cols.len() >= 5 {
            (SocketState::from_name(cols[3]), cols[4])
        } else {
            (SocketState::Listen, cols[3])
        };

        let pid = pid_str.parse::<u32>().ok();
        let process_name = pid.and_then(|p| pid_names.get(&p).cloned());

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

fn fetch_windows_process_names() -> HashMap<u32, String> {
    let mut map = HashMap::new();
    let Ok(output) = Command::new("tasklist")
        .args(["/FO", "CSV", "/NH"])
        .output()
    else {
        return map;
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        let parts: Vec<&str> = line.split("\",\"").collect();
        if parts.len() >= 2 {
            let name = parts[0].trim_matches('"').to_string();
            let pid_s = parts[1].trim_matches('"');
            if let Ok(pid) = pid_s.parse::<u32>() {
                map.insert(pid, name);
            }
        }
    }
    map
}

fn split_host_port(s: &str) -> Option<(String, u16)> {
    let (host, port_s) = s.rsplit_once(':')?;
    let port = port_s.parse::<u16>().ok()?;
    let clean_host = host.trim_matches(|c| c == '[' || c == ']').to_string();
    Some((clean_host, port))
}
