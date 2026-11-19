use std::collections::{HashMap, HashSet, VecDeque};
use std::io::{self, Write};
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::cli::GlobalOptions;
use crate::display::{Theme, print_ports_json, print_ports_table, print_probe_results, print_stats};
use crate::models::{FilterOptions, PortEntry, expand_port_ranges, parse_port_spec, well_known_service};
use crate::scanner::{probe_ports, scan_ports, terminate_pid};

pub fn run_list(filter: &FilterOptions, global: &GlobalOptions) -> Result<(), String> {
    let entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| filter.matches(e))
        .collect();

    if global.json {
        print_ports_json(&entries);
    } else {
        let theme = Theme::new(global.no_color);
        print_ports_table(&entries, &theme);
    }
    Ok(())
}

pub fn run_watch(
    filter: &FilterOptions,
    interval_ms: u64,
    global: &GlobalOptions,
) -> Result<(), String> {
    let theme = Theme::new(global.no_color);
    let interval = Duration::from_millis(interval_ms);
    let mut previous: HashMap<_, PortEntry> = HashMap::new();
    let mut events: VecDeque<String> = VecDeque::with_capacity(12);
    let mut first_run = true;

    loop {
        let entries: Vec<PortEntry> = scan_ports()?
            .into_iter()
            .filter(|e| filter.matches(e))
            .collect();

        let current: HashMap<_, PortEntry> = entries
            .iter()
            .map(|e| (e.identity_key(), e.clone()))
            .collect();

        let ts = format_hms_utc();

        if !first_run {
            for (k, entry) in &current {
                if !previous.contains_key(k) {
                    let proc_str = entry.process_name.as_deref().unwrap_or("-");
                    let msg = format!(
                        "[{}] {} {} {} (PID: {}, {})",
                        ts,
                        theme.green("+ OPEN  "),
                        entry.protocol,
                        entry.local_endpoint(),
                        entry
                            .pid
                            .map(|p| p.to_string())
                            .unwrap_or_else(|| "-".to_string()),
                        proc_str
                    );
                    push_event(&mut events, msg);
                }
            }
            for (k, entry) in &previous {
                if !current.contains_key(k) {
                    let proc_str = entry.process_name.as_deref().unwrap_or("-");
                    let msg = format!(
                        "[{}] {} {} {} (PID: {}, {})",
                        ts,
                        theme.red("- CLOSED"),
                        entry.protocol,
                        entry.local_endpoint(),
                        entry
                            .pid
                            .map(|p| p.to_string())
                            .unwrap_or_else(|| "-".to_string()),
                        proc_str
                    );
                    push_event(&mut events, msg);
                }
            }
        }

        // Clear screen and move cursor to top-left
        print!("\x1b[2J\x1b[H");
        println!(
            "{}  {}  {}",
            theme.bold("SierraPort Live Watch"),
            theme.dim(&format!("(refresh: {}ms | UTC {})", interval_ms, ts)),
            theme.dim("Press Ctrl+C to exit")
        );
        println!();

        print_ports_table(&entries, &theme);

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
    global: &GlobalOptions,
) -> Result<(), String> {
    let ranges = parse_port_spec(ports_spec)?;
    let ports = expand_port_ranges(&ranges, 2048)?;
    let results = probe_ports(host, &ports, timeout_ms)?;
    let theme = Theme::new(global.no_color);
    print_probe_results(&results, &theme, global.json);
    Ok(())
}

pub fn run_who(port: u16, global: &GlobalOptions) -> Result<(), String> {
    let entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| e.local_port == port)
        .collect();

    if global.json {
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
        println!(
            "  {} {}  |  State: {}  |  PID: {}  |  Process: {}",
            theme.bold(e.protocol.as_str()),
            e.local_endpoint(),
            theme.color_state(&e.state, e.state.as_str()),
            e.pid
                .map(|p| p.to_string())
                .unwrap_or_else(|| "-".to_string()),
            e.process_name.as_deref().unwrap_or("-")
        );
        if let Some(ref cmd) = e.cmdline {
            println!("    {}", theme.dim(&format!("CMD: {cmd}")));
        }
    }

    Ok(())
}

pub fn run_kill(port: u16, force: bool, yes: bool, global: &GlobalOptions) -> Result<(), String> {
    let theme = Theme::new(global.no_color);
    let matches: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| e.local_port == port && e.pid.is_some())
        .collect();

    if matches.is_empty() {
        return Err(format!(
            "No process with an accessible PID found on port {port} (try running with elevated privileges if owned by another user)."
        ));
    }

    let mut seen_pids = HashSet::new();
    let mut targets: Vec<(u32, String)> = Vec::new();
    for e in &matches {
        if let Some(pid) = e.pid
            && seen_pids.insert(pid)
        {
            targets.push((
                pid,
                e.process_name
                    .clone()
                    .unwrap_or_else(|| "unknown".to_string()),
            ));
        }
    }

    if !yes {
        println!(
            "{}",
            theme.yellow(&format!(
                "Found {} process(es) on port {port}:",
                targets.len()
            ))
        );
        for (pid, name) in &targets {
            println!("  PID {pid} ({name})");
        }
        print!(
            "Terminate {}? [y/N]: ",
            if force { "with SIGKILL/FORCE" } else { "gracefully" }
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

    for (pid, name) in targets {
        terminate_pid(pid, force)?;
        println!(
            "{} Terminated PID {} ({}) on port {}",
            theme.green("✓"),
            pid,
            name,
            port
        );
    }

    Ok(())
}

pub fn run_stats(filter: &FilterOptions, global: &GlobalOptions) -> Result<(), String> {
    let entries: Vec<PortEntry> = scan_ports()?
        .into_iter()
        .filter(|e| filter.matches(e))
        .collect();

    let theme = Theme::new(global.no_color);
    print_stats(&entries, &theme, global.json);
    Ok(())
}

fn push_event(events: &mut VecDeque<String>, msg: String) {
    if events.len() >= 10 {
        events.pop_front();
    }
    events.push_back(msg);
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
