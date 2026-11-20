use std::collections::BTreeMap;
use std::fs;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::models::{PortEntry, Protocol, SocketState};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SnapshotEntry {
    pub protocol: Protocol,
    pub local_addr: String,
    pub local_port: u16,
    pub state: SocketState,
    pub pid: Option<u32>,
    pub user: Option<String>,
    pub process_name: Option<String>,
}

impl From<&PortEntry> for SnapshotEntry {
    fn from(e: &PortEntry) -> Self {
        Self {
            protocol: e.protocol,
            local_addr: e.local_addr.clone(),
            local_port: e.local_port,
            state: e.state.clone(),
            pid: e.pid,
            user: e.user.clone(),
            process_name: e.process_name.clone(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct Snapshot {
    pub version: u32,
    pub created_unix: u64,
    pub entries: Vec<SnapshotEntry>,
}

#[derive(Debug, Clone)]
pub struct DriftChange {
    pub before: SnapshotEntry,
    pub after: SnapshotEntry,
    pub changes: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct DiffReport {
    pub baseline_created_unix: u64,
    pub added: Vec<SnapshotEntry>,
    pub removed: Vec<SnapshotEntry>,
    pub changed: Vec<DriftChange>,
    pub unchanged_count: usize,
}

impl DiffReport {
    pub fn has_drift(&self) -> bool {
        !self.added.is_empty() || !self.removed.is_empty() || !self.changed.is_empty()
    }
}

pub fn create_snapshot(entries: &[PortEntry]) -> Snapshot {
    let created_unix = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);

    // Deduplicate by (protocol, local_addr, local_port, pid)
    let mut seen = BTreeMap::new();
    for e in entries {
        seen.entry((e.protocol, e.local_port, e.local_addr.clone()))
            .or_insert_with(|| SnapshotEntry::from(e));
    }

    Snapshot {
        version: 1,
        created_unix,
        entries: seen.into_values().collect(),
    }
}

pub fn save_snapshot(path: &Path, snapshot: &Snapshot) -> Result<(), String> {
    let json = serialize_snapshot(snapshot);
    fs::write(path, json)
        .map_err(|e| format!("Failed to write snapshot to '{}': {e}", path.display()))
}

pub fn load_snapshot(path: &Path) -> Result<Snapshot, String> {
    let raw = fs::read_to_string(path)
        .map_err(|e| format!("Failed to read snapshot '{}': {e}", path.display()))?;
    parse_snapshot(&raw)
}

pub fn diff_snapshot(baseline: &Snapshot, live_entries: &[PortEntry]) -> DiffReport {
    let mut base_map: BTreeMap<(Protocol, u16), SnapshotEntry> = BTreeMap::new();
    for e in &baseline.entries {
        base_map.entry((e.protocol, e.local_port)).or_insert_with(|| e.clone());
    }

    let mut live_map: BTreeMap<(Protocol, u16), SnapshotEntry> = BTreeMap::new();
    for e in live_entries {
        live_map
            .entry(e.service_slot_key())
            .or_insert_with(|| SnapshotEntry::from(e));
    }

    let mut added = Vec::new();
    let mut removed = Vec::new();
    let mut changed = Vec::new();
    let mut unchanged_count = 0usize;

    for (key, live) in &live_map {
        match base_map.get(key) {
            None => added.push(live.clone()),
            Some(base) => {
                let mut diffs = Vec::new();
                if base.local_addr != live.local_addr {
                    diffs.push(format!("addr: {} -> {}", base.local_addr, live.local_addr));
                }
                if base.process_name != live.process_name {
                    diffs.push(format!(
                        "process: {} -> {}",
                        base.process_name.as_deref().unwrap_or("-"),
                        live.process_name.as_deref().unwrap_or("-")
                    ));
                }
                if base.user != live.user {
                    diffs.push(format!(
                        "user: {} -> {}",
                        base.user.as_deref().unwrap_or("-"),
                        live.user.as_deref().unwrap_or("-")
                    ));
                }
                if base.pid != live.pid && diffs.is_empty() {
                    diffs.push(format!(
                        "pid: {} -> {} (restarted)",
                        base.pid.map(|p| p.to_string()).unwrap_or_else(|| "-".into()),
                        live.pid.map(|p| p.to_string()).unwrap_or_else(|| "-".into())
                    ));
                }

                if diffs.is_empty() {
                    unchanged_count += 1;
                } else {
                    changed.push(DriftChange {
                        before: base.clone(),
                        after: live.clone(),
                        changes: diffs,
                    });
                }
            }
        }
    }

    for (key, base) in &base_map {
        if !live_map.contains_key(key) {
            removed.push(base.clone());
        }
    }

    DiffReport {
        baseline_created_unix: baseline.created_unix,
        added,
        removed,
        changed,
        unchanged_count,
    }
}

pub fn serialize_snapshot(snap: &Snapshot) -> String {
    let mut out = String::new();
    out.push_str("{\n");
    out.push_str(&format!("  \"version\": {},\n", snap.version));
    out.push_str(&format!("  \"created_unix\": {},\n", snap.created_unix));
    out.push_str("  \"entries\": [\n");
    for (i, e) in snap.entries.iter().enumerate() {
        let comma = if i + 1 < snap.entries.len() { "," } else { "" };
        let pid_s = e
            .pid
            .map(|p| p.to_string())
            .unwrap_or_else(|| "null".to_string());
        let user_s = opt_str_json(e.user.as_deref());
        let proc_s = opt_str_json(e.process_name.as_deref());
        out.push_str(&format!(
            "    {{\"protocol\":\"{}\",\"local_addr\":\"{}\",\"local_port\":{},\"state\":\"{}\",\"pid\":{},\"user\":{},\"process\":{}}}{}\n",
            e.protocol.as_str(),
            json_escape(&e.local_addr),
            e.local_port,
            json_escape(e.state.as_str()),
            pid_s,
            user_s,
            proc_s,
            comma
        ));
    }
    out.push_str("  ]\n");
    out.push_str("}\n");
    out
}

pub fn parse_snapshot(raw: &str) -> Result<Snapshot, String> {
    let mut version = 1u32;
    let mut created_unix = 0u64;
    let mut entries = Vec::new();

    for line in raw.lines() {
        let trimmed = line.trim();
        if let Some(val) = trimmed.strip_prefix("\"version\":") {
            let num = val.trim().trim_end_matches(',');
            version = num
                .parse::<u32>()
                .map_err(|_| format!("Invalid snapshot version: {num}"))?;
        } else if let Some(val) = trimmed.strip_prefix("\"created_unix\":") {
            let num = val.trim().trim_end_matches(',');
            created_unix = num
                .parse::<u64>()
                .map_err(|_| format!("Invalid snapshot timestamp: {num}"))?;
        } else if trimmed.starts_with('{') && trimmed.contains("\"local_port\"") {
            let obj = trimmed.trim_end_matches(',');
            entries.push(parse_entry_object(obj)?);
        }
    }

    Ok(Snapshot {
        version,
        created_unix,
        entries,
    })
}

fn parse_entry_object(obj: &str) -> Result<SnapshotEntry, String> {
    let proto_str = extract_json_string(obj, "protocol")
        .ok_or_else(|| "Snapshot entry missing 'protocol'".to_string())?;
    let protocol = Protocol::from_str_loose(&proto_str)
        .ok_or_else(|| format!("Unknown protocol in snapshot: {proto_str}"))?;
    let local_addr = extract_json_string(obj, "local_addr")
        .ok_or_else(|| "Snapshot entry missing 'local_addr'".to_string())?;
    let local_port = extract_json_u64(obj, "local_port")
        .ok_or_else(|| "Snapshot entry missing 'local_port'".to_string())? as u16;
    let state_str = extract_json_string(obj, "state").unwrap_or_else(|| "LISTEN".to_string());
    let state = SocketState::from_name(&state_str);
    let pid = extract_json_u64(obj, "pid").map(|v| v as u32);
    let user = extract_json_string(obj, "user");
    let process_name = extract_json_string(obj, "process");

    Ok(SnapshotEntry {
        protocol,
        local_addr,
        local_port,
        state,
        pid,
        user,
        process_name,
    })
}

fn extract_json_string(obj: &str, key: &str) -> Option<String> {
    let pattern = format!("\"{key}\":");
    let idx = obj.find(&pattern)?;
    let rest = obj[idx + pattern.len()..].trim_start();
    if rest.starts_with("null") {
        return None;
    }
    let rest = rest.strip_prefix('"')?;
    let mut out = String::new();
    let mut chars = rest.chars();
    while let Some(c) = chars.next() {
        match c {
            '"' => return Some(out),
            '\\' => match chars.next()? {
                '"' => out.push('"'),
                '\\' => out.push('\\'),
                'n' => out.push('\n'),
                'r' => out.push('\r'),
                't' => out.push('\t'),
                other => out.push(other),
            },
            other => out.push(other),
        }
    }
    None
}

fn extract_json_u64(obj: &str, key: &str) -> Option<u64> {
    let pattern = format!("\"{key}\":");
    let idx = obj.find(&pattern)?;
    let rest = obj[idx + pattern.len()..].trim_start();
    if rest.starts_with("null") {
        return None;
    }
    let digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
    digits.parse::<u64>().ok()
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
