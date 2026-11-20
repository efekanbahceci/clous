use std::collections::{HashMap, HashSet};
use std::process::Command;

use crate::models::{PortEntry, ProcessAncestor, Protocol, SocketState};

#[derive(Debug, Clone)]
struct PsMetadata {
    ppid: Option<u32>,
    rss_kb: Option<u64>,
    user: Option<String>,
    cmdline: Option<String>,
}

/// Scan active TCP/UDP sockets on macOS using `lsof` + batched `ps` enrichment.
pub fn scan_system_ports() -> Result<Vec<PortEntry>, String> {
    let output = Command::new("lsof")
        .args(["-nP", "-iTCP", "-iUDP"])
        .output()
        .map_err(|e| format!("Failed to execute lsof: {e}"))?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut entries = Vec::new();
    let mut pids = HashSet::new();

    for line in stdout.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 9 {
            continue;
        }

        let process_name = Some(cols[0].to_string());
        let pid = cols[1].parse::<u32>().ok();
        let user = Some(cols[2].to_string());
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

        if let Some(p) = pid {
            pids.insert(p);
        }

        entries.push(PortEntry {
            protocol,
            local_addr,
            local_port,
            remote_addr,
            remote_port,
            state,
            pid,
            ppid: None,
            user,
            process_name,
            cmdline: None,
            memory_kb: None,
        });
    }

    if !pids.is_empty() {
        let meta_map = fetch_ps_metadata(&pids);
        for entry in &mut entries {
            if let Some(pid) = entry.pid
                && let Some(meta) = meta_map.get(&pid)
            {
                entry.ppid = meta.ppid;
                entry.memory_kb = meta.rss_kb;
                if meta.user.is_some() {
                    entry.user = meta.user.clone();
                }
                entry.cmdline = meta.cmdline.clone();
            }
        }
    }

    entries.sort_by(|a, b| {
        a.local_port
            .cmp(&b.local_port)
            .then_with(|| a.protocol.cmp(&b.protocol))
    });

    Ok(entries)
}

/// Walk the process ancestry tree up to PID 1 using `ps`.
pub fn get_process_ancestry(start_pid: u32) -> Vec<ProcessAncestor> {
    let mut chain = Vec::new();
    let mut visited = HashSet::new();
    let mut current = start_pid;

    while current > 0 && visited.insert(current) && chain.len() < 16 {
        let Ok(output) = Command::new("ps")
            .args(["-o", "pid=,ppid=,rss=,user=,args=", "-p", &current.to_string()])
            .output()
        else {
            break;
        };
        let stdout = String::from_utf8_lossy(&output.stdout);
        let Some(line) = stdout.lines().find(|l| !l.trim().is_empty()) else {
            break;
        };

        let Some((pid, ppid, rss, user, args)) = parse_ps_ancestry_line(line) else {
            break;
        };

        let exe = args.split_whitespace().next().unwrap_or("unknown");
        let name = exe.rsplit('/').next().unwrap_or(exe).to_string();
        chain.push(ProcessAncestor {
            pid,
            ppid,
            user: Some(user),
            name,
            memory_kb: rss,
            cmdline: if args.is_empty() { None } else { Some(args) },
        });

        match ppid {
            Some(parent) if parent != current && parent > 0 => current = parent,
            _ => break,
        }
    }

    chain
}

fn fetch_ps_metadata(pids: &HashSet<u32>) -> HashMap<u32, PsMetadata> {
    let mut map = HashMap::new();
    let pid_list: String = pids
        .iter()
        .map(|p| p.to_string())
        .collect::<Vec<_>>()
        .join(",");

    let Ok(output) = Command::new("ps")
        .args(["-o", "pid=,ppid=,rss=,user=,args=", "-p", &pid_list])
        .output()
    else {
        return map;
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let mut parts = trimmed.splitn(5, char::is_whitespace);
        let Some(pid_s) = parts.next() else {
            continue;
        };
        let rest = trimmed[pid_s.len()..].trim_start();
        let Some(ppid_s) = rest.split_whitespace().next() else {
            continue;
        };
        let rest = rest[ppid_s.len()..].trim_start();
        let Some(rss_s) = rest.split_whitespace().next() else {
            continue;
        };
        let rest = rest[rss_s.len()..].trim_start();
        let Some(user_s) = rest.split_whitespace().next() else {
            continue;
        };
        let args = rest[user_s.len()..].trim();

        let Ok(pid) = pid_s.parse::<u32>() else {
            continue;
        };
        let ppid = ppid_s.parse::<u32>().ok();
        let rss_kb = rss_s.parse::<u64>().ok();
        let user = if user_s.is_empty() {
            None
        } else {
            Some(user_s.to_string())
        };
        let cmdline = if args.is_empty() {
            None
        } else {
            Some(args.to_string())
        };

        map.insert(
            pid,
            PsMetadata {
                ppid,
                rss_kb,
                user,
                cmdline,
            },
        );
    }

    map
}

fn parse_ps_ancestry_line(
    line: &str,
) -> Option<(u32, Option<u32>, Option<u64>, String, String)> {
    let trimmed = line.trim();
    let pid_s = trimmed.split_whitespace().next()?;
    let rest = trimmed[pid_s.len()..].trim_start();
    let ppid_s = rest.split_whitespace().next()?;
    let rest = rest[ppid_s.len()..].trim_start();
    let rss_s = rest.split_whitespace().next()?;
    let rest = rest[rss_s.len()..].trim_start();
    let user_s = rest.split_whitespace().next()?;
    let args = rest[user_s.len()..].trim();

    let pid = pid_s.parse::<u32>().ok()?;
    let ppid = ppid_s.parse::<u32>().ok();
    let rss = rss_s.parse::<u64>().ok();
    Some((pid, ppid, rss, user_s.to_string(), args.to_string()))
}

fn split_host_port(s: &str) -> Option<(String, u16)> {
    let (host, port_s) = s.rsplit_once(':')?;
    let port = port_s.parse::<u16>().ok()?;
    let clean_host = host.trim_matches(|c| c == '[' || c == ']').to_string();
    Some((clean_host, port))
}
