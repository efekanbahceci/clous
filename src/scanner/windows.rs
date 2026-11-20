use std::collections::HashMap;
use std::process::Command;

use crate::models::{PortEntry, ProcessAncestor, Protocol, SocketState};

/// Scan active TCP/UDP sockets on Windows using `netstat -ano` and `tasklist`.
pub fn scan_system_ports() -> Result<Vec<PortEntry>, String> {
    let pid_info = fetch_windows_process_info();

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
        let meta = pid.and_then(|p| pid_info.get(&p));

        entries.push(PortEntry {
            protocol,
            local_addr,
            local_port,
            remote_addr,
            remote_port,
            state,
            pid,
            ppid: None,
            user: None,
            process_name: meta.map(|m| m.0.clone()),
            cmdline: None,
            memory_kb: meta.and_then(|m| m.1),
        });
    }

    entries.sort_by(|a, b| {
        a.local_port
            .cmp(&b.local_port)
            .then_with(|| a.protocol.cmp(&b.protocol))
    });

    Ok(entries)
}

pub fn get_process_ancestry(start_pid: u32) -> Vec<ProcessAncestor> {
    let pid_info = fetch_windows_process_info();
    if let Some((name, mem)) = pid_info.get(&start_pid) {
        vec![ProcessAncestor {
            pid: start_pid,
            ppid: None,
            user: None,
            name: name.clone(),
            memory_kb: *mem,
            cmdline: None,
        }]
    } else {
        Vec::new()
    }
}

fn fetch_windows_process_info() -> HashMap<u32, (String, Option<u64>)> {
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
            let mem_kb = parts.get(4).and_then(|m| {
                let digits: String = m.chars().filter(|c| c.is_ascii_digit()).collect();
                digits.parse::<u64>().ok()
            });
            if let Ok(pid) = pid_s.parse::<u32>() {
                map.insert(pid, (name, mem_kb));
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
