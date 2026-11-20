use std::collections::{HashMap, HashSet};
use std::fs;
use std::net::{Ipv4Addr, Ipv6Addr};
use std::path::Path;

use crate::models::{PortEntry, ProcessAncestor, Protocol, SocketState};

#[derive(Debug, Clone)]
struct ProcessInfo {
    pid: u32,
    ppid: Option<u32>,
    user: Option<String>,
    name: String,
    cmdline: Option<String>,
    memory_kb: Option<u64>,
}

/// Scan active TCP/UDP sockets directly from Linux `/proc/net/*` and correlate
/// socket inodes with `/proc/<pid>/fd` for zero-subprocess speed.
pub fn scan_system_ports() -> Result<Vec<PortEntry>, String> {
    let uid_map = load_passwd_uid_map();
    let inode_map = build_inode_process_map(&uid_map);
    let mut entries = Vec::with_capacity(64);

    let sources = [
        ("/proc/net/tcp", Protocol::Tcp, false),
        ("/proc/net/tcp6", Protocol::Tcp6, true),
        ("/proc/net/udp", Protocol::Udp, false),
        ("/proc/net/udp6", Protocol::Udp6, true),
    ];

    for (path, proto, is_v6) in sources {
        if let Ok(content) = fs::read_to_string(path) {
            parse_proc_net(&content, proto, is_v6, &inode_map, &mut entries);
        }
    }

    entries.sort_by(|a, b| {
        a.local_port
            .cmp(&b.local_port)
            .then_with(|| a.protocol.cmp(&b.protocol))
            .then_with(|| a.state.cmp(&b.state))
    });

    Ok(entries)
}

/// Walk the process ancestry tree directly via `/proc/<pid>/status`.
pub fn get_process_ancestry(start_pid: u32) -> Vec<ProcessAncestor> {
    let uid_map = load_passwd_uid_map();
    let mut chain = Vec::new();
    let mut visited = HashSet::new();
    let mut current = start_pid;

    while current > 0 && visited.insert(current) && chain.len() < 16 {
        let pid_path = Path::new("/proc").join(current.to_string());
        if !pid_path.exists() {
            break;
        }
        let info = read_process_info(current, &pid_path, &uid_map);
        let next_ppid = info.ppid;
        chain.push(ProcessAncestor {
            pid: info.pid,
            ppid: info.ppid,
            user: info.user,
            name: info.name,
            memory_kb: info.memory_kb,
            cmdline: info.cmdline,
        });
        match next_ppid {
            Some(parent) if parent != current && parent > 0 => current = parent,
            _ => break,
        }
    }

    chain
}

fn parse_proc_net(
    content: &str,
    protocol: Protocol,
    is_v6: bool,
    inode_map: &HashMap<u64, ProcessInfo>,
    out: &mut Vec<PortEntry>,
) {
    for line in content.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 10 {
            continue;
        }

        let Some((local_addr, local_port)) = parse_hex_endpoint(cols[1], is_v6) else {
            continue;
        };
        let Some((remote_addr, remote_port)) = parse_hex_endpoint(cols[2], is_v6) else {
            continue;
        };

        let mut state = SocketState::from_linux_hex(cols[3]);
        // UDP sockets in Linux `/proc/net/udp` use state 07 (CLOSE) when bound & listening.
        if protocol.is_udp() && state == SocketState::Close && local_port > 0 {
            state = SocketState::Listen;
        }

        let inode: u64 = cols[9].parse().unwrap_or(0);
        let proc_info = if inode > 0 {
            inode_map.get(&inode)
        } else {
            None
        };

        out.push(PortEntry {
            protocol,
            local_addr,
            local_port,
            remote_addr,
            remote_port,
            state,
            pid: proc_info.map(|p| p.pid),
            ppid: proc_info.and_then(|p| p.ppid),
            user: proc_info.and_then(|p| p.user.clone()),
            process_name: proc_info.map(|p| p.name.clone()),
            cmdline: proc_info.and_then(|p| p.cmdline.clone()),
            memory_kb: proc_info.and_then(|p| p.memory_kb),
        });
    }
}

fn parse_hex_endpoint(token: &str, is_v6: bool) -> Option<(String, u16)> {
    let (addr_hex, port_hex) = token.split_once(':')?;
    let port = u16::from_str_radix(port_hex, 16).ok()?;

    let addr = if is_v6 {
        parse_ipv6_hex(addr_hex)?
    } else {
        parse_ipv4_hex(addr_hex)?
    };

    Some((addr, port))
}

fn parse_ipv4_hex(hex: &str) -> Option<String> {
    if hex.len() != 8 {
        return None;
    }
    let raw = u32::from_str_radix(hex, 16).ok()?;
    let bytes = raw.to_le_bytes();
    Some(Ipv4Addr::from(bytes).to_string())
}

fn parse_ipv6_hex(hex: &str) -> Option<String> {
    if hex.len() != 32 {
        return None;
    }
    let mut bytes = [0u8; 16];
    for group in 0..4 {
        let slice = &hex[group * 8..(group + 1) * 8];
        let word = u32::from_str_radix(slice, 16).ok()?;
        let le = word.to_le_bytes();
        bytes[group * 4..group * 4 + 4].copy_from_slice(&le);
    }
    Some(Ipv6Addr::from(bytes).to_string())
}

fn build_inode_process_map(uid_map: &HashMap<u32, String>) -> HashMap<u64, ProcessInfo> {
    let mut map = HashMap::new();
    let Ok(proc_dir) = fs::read_dir("/proc") else {
        return map;
    };

    for entry in proc_dir.flatten() {
        let file_name = entry.file_name();
        let Some(pid_str) = file_name.to_str() else {
            continue;
        };
        let Ok(pid) = pid_str.parse::<u32>() else {
            continue;
        };

        let pid_path = entry.path();
        let fd_path = pid_path.join("fd");
        let Ok(fds) = fs::read_dir(&fd_path) else {
            continue;
        };

        let mut proc_info: Option<ProcessInfo> = None;

        for fd_entry in fds.flatten() {
            let Ok(link) = fs::read_link(fd_entry.path()) else {
                continue;
            };
            let Some(link_str) = link.to_str() else {
                continue;
            };
            if let Some(inode) = extract_socket_inode(link_str) {
                let info = proc_info.get_or_insert_with(|| read_process_info(pid, &pid_path, uid_map));
                map.entry(inode).or_insert_with(|| info.clone());
            }
        }
    }

    map
}

fn extract_socket_inode(link: &str) -> Option<u64> {
    let inner = link.strip_prefix("socket:[")?.strip_suffix(']')?;
    inner.parse::<u64>().ok()
}

fn read_process_info(
    pid: u32,
    pid_path: &Path,
    uid_map: &HashMap<u32, String>,
) -> ProcessInfo {
    let name = fs::read_to_string(pid_path.join("comm"))
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|_| "unknown".to_string());

    let cmdline = fs::read(pid_path.join("cmdline")).ok().and_then(|bytes| {
        if bytes.is_empty() {
            None
        } else {
            let joined = bytes
                .split(|&b| b == 0)
                .filter(|s| !s.is_empty())
                .map(|s| String::from_utf8_lossy(s))
                .collect::<Vec<_>>()
                .join(" ");
            if joined.is_empty() {
                None
            } else {
                Some(joined)
            }
        }
    });

    let mut ppid = None;
    let mut user = None;
    let mut memory_kb = None;

    if let Ok(status) = fs::read_to_string(pid_path.join("status")) {
        for line in status.lines() {
            if let Some(val) = line.strip_prefix("PPid:") {
                ppid = val.trim().parse::<u32>().ok();
            } else if let Some(val) = line.strip_prefix("Uid:") {
                if let Some(uid_s) = val.split_whitespace().next()
                    && let Ok(uid) = uid_s.parse::<u32>()
                {
                    user = Some(
                        uid_map
                            .get(&uid)
                            .cloned()
                            .unwrap_or_else(|| uid.to_string()),
                    );
                }
            } else if let Some(val) = line.strip_prefix("VmRSS:") {
                if let Some(kb_s) = val.split_whitespace().next() {
                    memory_kb = kb_s.parse::<u64>().ok();
                }
            }
        }
    }

    ProcessInfo {
        pid,
        ppid,
        user,
        name,
        cmdline,
        memory_kb,
    }
}

fn load_passwd_uid_map() -> HashMap<u32, String> {
    let mut map = HashMap::new();
    let Ok(content) = fs::read_to_string("/etc/passwd") else {
        return map;
    };
    for line in content.lines() {
        let mut parts = line.split(':');
        let Some(name) = parts.next() else { continue };
        let _pw = parts.next();
        let Some(uid_s) = parts.next() else { continue };
        if let Ok(uid) = uid_s.parse::<u32>() {
            map.insert(uid, name.to_string());
        }
    }
    map
}
