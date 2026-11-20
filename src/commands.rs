use std::collections::{HashMap, HashSet, VecDeque};
use std::fs::OpenOptions;
use std::io::{self, Write};
use std::path::Path;
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crate::audit::run_audit_analysis;
use crate::cli::{GlobalOptions, KillTarget, SnapshotAction};
use crate::display::{
    Theme, print_audit_report, print_diff_report, print_inspect_report, print_ports_compact,
    print_ports_csv, print_ports_json, print_ports_table, print_probe_results, print_stats,
};
use crate::models::{
    FilterOptions, OutputFormat, PortEntry, expand_port_ranges, parse_port_spec, well_known_service,
};
use crate::scanner::{
    find_free_ports, get_process_ancestry, probe_ports, scan_ports, terminate_pid, wait_for_port,
};
use crate::snapshot::{create_snapshot, diff_snapshot, load_snapshot, save_snapshot};

pub fn run_list(filter: &FilterOptions, global: &GlobalOptions) -> Result<(), String> {
    let mut entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| filter.matches(e))
        .collect();
    filter.sort_entries(&mut entries);

    let theme = Theme::new(global.no_color);
    match global.format {
        OutputFormat::Json => print_ports_json(&entries),
        OutputFormat::Csv => print_ports_csv(&entries),
        OutputFormat::Compact => print_ports_compact(&entries, &theme),
        OutputFormat::Table => print_ports_table(&entries, &theme, global.wide),
    }
    Ok(())
}

pub fn run_watch(
    filter: &FilterOptions,
    interval_ms: u64,
    log_file: Option<&str>,
    alert_new: bool,
    global: &GlobalOptions,
) -> Result<(), String> {
    let theme = Theme::new(global.no_color);
    let interval = Duration::from_millis(interval_ms);
    let mut previous: HashMap<_, PortEntry> = HashMap::new();
    let mut events: VecDeque<String> = VecDeque::with_capacity(14);
    let mut first_run = true;
    let mut total_opened = 0usize;
    let mut total_closed = 0usize;

    loop {
        let mut entries: Vec<PortEntry> = scan_ports()?
            .into_iter()
            .filter(|e| filter.matches(e))
            .collect();
        filter.sort_entries(&mut entries);

        let current: HashMap<_, PortEntry> = entries
            .iter()
            .map(|e| (e.identity_key(), e.clone()))
            .collect();

        let ts = format_hms_utc();
        let mut opened_this_tick = false;

        if !first_run {
            for (k, entry) in &current {
                if !previous.contains_key(k) {
                    total_opened += 1;
                    opened_this_tick = true;
                    let proc_str = entry.process_name.as_deref().unwrap_or("-");
                    let pid_str = entry
                        .pid
                        .map(|p| p.to_string())
                        .unwrap_or_else(|| "-".to_string());
                    let msg = format!(
                        "[{}] {} {} {} [{}] (PID: {}, {})",
                        ts,
                        theme.green("+ OPEN  "),
                        entry.protocol,
                        entry.local_endpoint(),
                        entry.bind_scope().as_str(),
                        pid_str,
                        proc_str
                    );
                    push_event(&mut events, msg);
                    if let Some(path) = log_file {
                        let plain_line = format!(
                            "{{\"time\":\"{ts}\",\"event\":\"OPEN\",\"protocol\":\"{}\",\"endpoint\":\"{}\",\"scope\":\"{}\",\"pid\":\"{}\",\"process\":\"{}\"}}",
                            entry.protocol,
                            entry.local_endpoint(),
                            entry.bind_scope().as_str(),
                            pid_str,
                            proc_str
                        );
                        append_log_line(path, &plain_line);
                    }
                }
            }
            for (k, entry) in &previous {
                if !current.contains_key(k) {
                    total_closed += 1;
                    let proc_str = entry.process_name.as_deref().unwrap_or("-");
                    let pid_str = entry
                        .pid
                        .map(|p| p.to_string())
                        .unwrap_or_else(|| "-".to_string());
                    let msg = format!(
                        "[{}] {} {} {} (PID: {}, {})",
                        ts,
                        theme.red("- CLOSED"),
                        entry.protocol,
                        entry.local_endpoint(),
                        pid_str,
                        proc_str
                    );
                    push_event(&mut events, msg);
                    if let Some(path) = log_file {
                        let plain_line = format!(
                            "{{\"time\":\"{ts}\",\"event\":\"CLOSED\",\"protocol\":\"{}\",\"endpoint\":\"{}\",\"pid\":\"{}\",\"process\":\"{}\"}}",
                            entry.protocol,
                            entry.local_endpoint(),
                            pid_str,
                            proc_str
                        );
                        append_log_line(path, &plain_line);
                    }
                }
            }
        }

        if alert_new && opened_this_tick {
            print!("\x07");
        }

        let exposed_cnt = entries
            .iter()
            .filter(|e| e.state.is_listening() && e.bind_scope().is_exposed())
            .count();

        // Clear screen and move cursor to top-left
        print!("\x1b[2J\x1b[H");
        println!(
            "{}  {}  {}",
            theme.bold("SierraPort Live Watch"),
            theme.dim(&format!("(refresh: {}ms | UTC {})", interval_ms, ts)),
            theme.dim("Press Ctrl+C to exit")
        );
        println!(
            "  {}  |  {}  |  {}  |  {}\n",
            theme.cyan(&format!("Active: {}", entries.len())),
            theme.yellow(&format!("Exposed: {exposed_cnt}")),
            theme.green(&format!("+{total_opened} opened")),
            theme.red(&format!("-{total_closed} closed"))
        );

        match global.format {
            OutputFormat::Compact => print_ports_compact(&entries, &theme),
            _ => print_ports_table(&entries, &theme, global.wide),
        }

        if !events.is_empty() {
            println!("\n{}", theme.bold("Recent Changes:"));
            for ev in &events {
                println!("  {ev}");
            }
        }

        let _ = io::stdout().flush();
        previous = current;
        first_run = false;

        thread::sleep(interval);
    }
}

pub fn run_check(
    host: &str,
    ports_spec: &str,
    timeout_ms: u64,
    banner: bool,
    open_only: bool,
    concurrency: usize,
    global: &GlobalOptions,
) -> Result<(), String> {
    let ranges = parse_port_spec(ports_spec)?;
    let ports = expand_port_ranges(&ranges, 4096)?;
    let results = probe_ports(host, &ports, timeout_ms, banner, concurrency)?;
    let theme = Theme::new(global.no_color);
    print_probe_results(&results, &theme, global.is_json(), open_only, banner);
    Ok(())
}

pub fn run_who(port: u16, global: &GlobalOptions) -> Result<(), String> {
    let entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| e.local_port == port)
        .collect();

    if global.is_json() {
        print_ports_json(&entries);
        return Ok(());
    }

    let theme = Theme::new(global.no_color);
    if entries.is_empty() {
        println!(
            "{}",
            theme.yellow(&format!("No active process found on port {port}."))
        );
        return Ok(());
    }

    let svc = well_known_service(port).unwrap_or("Unknown");
    println!(
        "{} {} {}\n",
        theme.bold("Port"),
        theme.cyan(&port.to_string()),
        theme.dim(&format!("({svc})"))
    );

    for e in &entries {
        let scope = e.bind_scope();
        println!(
            "  {} {} {}  |  State: {}  |  PID: {}  |  User: {}  |  Mem: {}  |  Process: {}",
            theme.bold(e.protocol.as_str()),
            e.local_endpoint(),
            theme.color_scope(scope, &format!("[{}]", scope.as_str())),
            theme.color_state(&e.state, e.state.as_str()),
            e.pid
                .map(|p| p.to_string())
                .unwrap_or_else(|| "-".to_string()),
            e.user.as_deref().unwrap_or("-"),
            e.memory_human(),
            e.process_name.as_deref().unwrap_or("-")
        );
        if let Some(ref cmd) = e.cmdline {
            println!("    {}", theme.dim(&format!("CMD: {cmd}")));
        }
    }

    Ok(())
}

pub fn run_inspect(
    port: u16,
    do_probe: bool,
    timeout_ms: u64,
    global: &GlobalOptions,
) -> Result<(), String> {
    let all_entries = scan_ports()?;
    let port_entries: Vec<PortEntry> = all_entries
        .iter()
        .filter(|e| e.local_port == port)
        .cloned()
        .collect();

    let primary_pid = port_entries.iter().find_map(|e| e.pid);
    let ancestors = primary_pid
        .map(get_process_ancestry)
        .unwrap_or_default();

    let peer_connections: Vec<PortEntry> = all_entries
        .into_iter()
        .filter(|e| {
            !e.state.is_listening()
                && (e.local_port == port
                    || e.remote_port == port
                    || (primary_pid.is_some() && e.pid == primary_pid))
        })
        .collect();

    let probe_res = if do_probe {
        probe_ports("127.0.0.1", &[port], timeout_ms, true, 1)
            .ok()
            .and_then(|mut v| v.pop())
    } else {
        None
    };

    let theme = Theme::new(global.no_color);
    print_inspect_report(
        port,
        &port_entries,
        &ancestors,
        &peer_connections,
        probe_res.as_ref(),
        &theme,
        global.is_json(),
    );
    Ok(())
}

pub fn run_audit(
    filter: &FilterOptions,
    strict: bool,
    global: &GlobalOptions,
) -> Result<(), String> {
    let entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| filter.matches(e))
        .collect();

    let report = run_audit_analysis(&entries);
    let theme = Theme::new(global.no_color);
    print_audit_report(&report, &theme, global.is_json());

    if strict && report.has_high_or_critical() {
        return Err("Audit failed in --strict mode due to HIGH or CRITICAL findings.".to_string());
    }
    Ok(())
}

pub fn run_snapshot(action: &SnapshotAction, global: &GlobalOptions) -> Result<(), String> {
    let theme = Theme::new(global.no_color);
    match action {
        SnapshotAction::Save { path, filter } => {
            let entries: Vec<PortEntry> = scan_ports()?
                .into_iter()
                .filter(|e| filter.matches(e))
                .collect();
            let snap = create_snapshot(&entries);
            save_snapshot(Path::new(path), &snap)?;
            if global.is_json() {
                println!(
                    "{{\"saved\":\"{}\",\"entries\":{},\"created_unix\":{}}}",
                    path,
                    snap.entries.len(),
                    snap.created_unix
                );
            } else {
                println!(
                    "{} Saved baseline snapshot to {} ({} port entries)",
                    theme.green("✓"),
                    theme.cyan(path),
                    snap.entries.len()
                );
            }
            Ok(())
        }
        SnapshotAction::Diff {
            path,
            filter,
            fail_on_drift,
        } => {
            let baseline = load_snapshot(Path::new(path))?;
            let live: Vec<PortEntry> = scan_ports()?
                .into_iter()
                .filter(|e| filter.matches(e))
                .collect();
            let report = diff_snapshot(&baseline, &live);
            print_diff_report(&report, &theme, global.is_json());
            if *fail_on_drift && report.has_drift() {
                return Err("Baseline drift detected (--fail-on-drift enabled).".to_string());
            }
            Ok(())
        }
    }
}

pub fn run_free(
    host: &str,
    range_start: u16,
    range_end: u16,
    count: usize,
    plain: bool,
    global: &GlobalOptions,
) -> Result<(), String> {
    let ports = find_free_ports(host, range_start, range_end, count)?;
    if global.is_json() {
        let list: String = ports
            .iter()
            .map(|p| p.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        println!("{{\"host\":\"{host}\",\"free_ports\":[{list}]}}");
        return Ok(());
    }
    if plain {
        for p in ports {
            println!("{p}");
        }
        return Ok(());
    }

    let theme = Theme::new(global.no_color);
    println!(
        "{} Found {} free TCP port(s) on {} ({}-{}):",
        theme.green("✓"),
        ports.len(),
        host,
        range_start,
        range_end
    );
    for p in ports {
        println!("  {}", theme.cyan(&p.to_string()));
    }
    Ok(())
}

pub fn run_wait(
    host: &str,
    port: u16,
    wait_until_open: bool,
    timeout_ms: u64,
    interval_ms: u64,
    global: &GlobalOptions,
) -> Result<(), String> {
    let theme = Theme::new(global.no_color);
    let expected = if wait_until_open { "open" } else { "closed" };
    let elapsed_ms = wait_for_port(host, port, wait_until_open, timeout_ms, interval_ms)?;

    if global.is_json() {
        println!(
            "{{\"host\":\"{host}\",\"port\":{port},\"state\":\"{expected}\",\"elapsed_ms\":{elapsed_ms}}}"
        );
    } else {
        println!(
            "{} {}:{} is now {} (waited {}ms)",
            theme.green("✓"),
            host,
            port,
            theme.cyan(expected),
            elapsed_ms
        );
    }
    Ok(())
}

pub fn run_kill(
    target: &KillTarget,
    force: bool,
    yes: bool,
    wait_release: bool,
    global: &GlobalOptions,
) -> Result<(), String> {
    let theme = Theme::new(global.no_color);
    let all = scan_ports()?;

    let mut seen_pids = HashSet::new();
    let mut targets: Vec<(u32, String, Vec<u16>)> = Vec::new();
    let mut port_map: HashMap<u32, (String, Vec<u16>)> = HashMap::new();

    match target {
        KillTarget::Ports(spec) => {
            let ranges = parse_port_spec(spec)?;
            for e in &all {
                if ranges.iter().any(|r| r.contains(e.local_port))
                    && let Some(pid) = e.pid
                {
                    let entry = port_map.entry(pid).or_insert_with(|| {
                        (
                            e.process_name
                                .clone()
                                .unwrap_or_else(|| "unknown".to_string()),
                            Vec::new(),
                        )
                    });
                    if !entry.1.contains(&e.local_port) {
                        entry.1.push(e.local_port);
                    }
                }
            }
        }
        KillTarget::Pid(pid) => {
            let mut ports = Vec::new();
            let mut pname = "unknown".to_string();
            for e in &all {
                if e.pid == Some(*pid) {
                    if let Some(ref n) = e.process_name {
                        pname = n.clone();
                    }
                    if !ports.contains(&e.local_port) {
                        ports.push(e.local_port);
                    }
                }
            }
            port_map.insert(*pid, (pname, ports));
        }
        KillTarget::Process(needle) => {
            let needle_lc = needle.to_ascii_lowercase();
            for e in &all {
                let matched = e
                    .process_name
                    .as_deref()
                    .is_some_and(|n| n.to_ascii_lowercase().contains(&needle_lc));
                if matched
                    && let Some(pid) = e.pid
                {
                    let entry = port_map.entry(pid).or_insert_with(|| {
                        (
                            e.process_name
                                .clone()
                                .unwrap_or_else(|| "unknown".to_string()),
                            Vec::new(),
                        )
                    });
                    if !entry.1.contains(&e.local_port) {
                        entry.1.push(e.local_port);
                    }
                }
            }
        }
    }

    for (pid, (name, mut ports)) in port_map {
        if seen_pids.insert(pid) {
            ports.sort_unstable();
            targets.push((pid, name, ports));
        }
    }
    targets.sort_by_key(|t| t.0);

    if targets.is_empty() {
        return Err(
            "No matching process with an accessible PID found (try elevated privileges if owned by another user)."
                .to_string(),
        );
    }

    if !yes {
        println!(
            "{}",
            theme.yellow(&format!("Found {} target process(es):", targets.len()))
        );
        for (pid, name, ports) in &targets {
            let p_str: String = ports
                .iter()
                .map(|p| p.to_string())
                .collect::<Vec<_>>()
                .join(", ");
            println!("  PID {pid} ({name}) — ports: [{p_str}]");
        }
        print!(
            "Terminate {}? [y/N]: ",
            if force {
                "with SIGKILL/FORCE"
            } else {
                "gracefully (SIGTERM)"
            }
        );
        let _ = io::stdout().flush();

        let mut answer = String::new();
        io::stdin()
            .read_line(&mut answer)
            .map_err(|e| format!("Failed to read input: {e}"))?;
        let ans = answer.trim().to_ascii_lowercase();
        if ans != "y" && ans != "yes" {
            println!("{}", theme.dim("Aborted."));
            return Ok(());
        }
    }

    let mut ports_to_verify = Vec::new();
    for (pid, name, ports) in &targets {
        terminate_pid(*pid, force)?;
        ports_to_verify.extend(ports.iter().copied());
        println!(
            "{} Terminated PID {} ({})",
            theme.green("✓"),
            pid,
            name
        );
    }

    if wait_release && !ports_to_verify.is_empty() {
        let start = Instant::now();
        let deadline = Duration::from_secs(5);
        while start.elapsed() < deadline {
            let current = scan_ports().unwrap_or_default();
            let still_held = current.iter().any(|e| {
                e.state.is_listening() && ports_to_verify.contains(&e.local_port)
            });
            if !still_held {
                println!(
                    "{} Verified all target port(s) released ({}ms)",
                    theme.green("✓"),
                    start.elapsed().as_millis()
                );
                return Ok(());
            }
            thread::sleep(Duration::from_millis(150));
        }
        return Err("Process signaled, but port(s) were not released within 5s.".to_string());
    }

    Ok(())
}

pub fn run_stats(filter: &FilterOptions, global: &GlobalOptions) -> Result<(), String> {
    let entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| filter.matches(e))
        .collect();

    let theme = Theme::new(global.no_color);
    print_stats(&entries, &theme, global.is_json());
    Ok(())
}

fn push_event(events: &mut VecDeque<String>, msg: String) {
    if events.len() >= 12 {
        events.pop_front();
    }
    events.push_back(msg);
}

fn append_log_line(path: &str, line: &str) {
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
        let _ = writeln!(file, "{line}");
    }
}

fn format_hms_utc() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let h = (secs / 3600) % 24;
    let m = (secs / 60) % 60;
    let s = secs % 60;
    format!("{h:02}:{m:02}:{s:02}")
}
