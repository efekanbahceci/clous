mod audit;
mod cli;
mod commands;
mod display;
mod models;
mod scanner;
mod snapshot;

use std::process::ExitCode;

use crate::cli::{Command, help_text, parse_args};

fn main() -> ExitCode {
    let parsed = match parse_args(std::env::args()) {
        Ok(args) => args,
        Err(err) => {
            eprintln!("Error: {err}");
            return ExitCode::from(2);
        }
    };

    let result = match parsed.command {
        Command::List { filter } => commands::run_list(&filter, &parsed.global),
        Command::Watch {
            filter,
            interval_ms,
            log_file,
            alert_new,
        } => commands::run_watch(
            &filter,
            interval_ms,
            log_file.as_deref(),
            alert_new,
            &parsed.global,
        ),
        Command::Stream {
            filter,
            interval_ms,
        } => commands::run_stream(&filter, interval_ms),
        Command::Check {
            host,
            ports_spec,
            timeout_ms,
            banner,
            open_only,
            concurrency,
        } => commands::run_check(
            &host,
            &ports_spec,
            timeout_ms,
            banner,
            open_only,
            concurrency,
            &parsed.global,
        ),
        Command::Who { port } => commands::run_who(port, &parsed.global),
        Command::Inspect {
            port,
            probe,
            timeout_ms,
        } => commands::run_inspect(port, probe, timeout_ms, &parsed.global),
        Command::Audit {
            filter,
            strict,
            profile,
            deep,
        } => commands::run_audit(&filter, strict, profile, deep, &parsed.global),
        Command::Snapshot(action) => commands::run_snapshot(&action, &parsed.global),
        Command::Free {
            host,
            range_start,
            range_end,
            count,
            plain,
        } => commands::run_free(&host, range_start, range_end, count, plain, &parsed.global),
        Command::Wait {
            host,
            port,
            wait_until_open,
            timeout_ms,
            interval_ms,
        } => commands::run_wait(
            &host,
            port,
            wait_until_open,
            timeout_ms,
            interval_ms,
            &parsed.global,
        ),
        Command::Kill {
            target,
            force,
            yes,
            wait_release,
        } => commands::run_kill(&target, force, yes, wait_release, &parsed.global),
        Command::Stats { filter } => commands::run_stats(&filter, &parsed.global),
        Command::Help => {
            println!("{}", help_text());
            Ok(())
        }
        Command::Version => {
            println!("sierraport {}", env!("CARGO_PKG_VERSION"));
            Ok(())
        }
    };

    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("Error: {err}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use std::net::TcpListener;

    use crate::audit::{Severity, run_audit_analysis};
    use crate::cli::{Command, KillTarget, SnapshotAction, parse_args};
    use crate::models::{
        BindScope, FilterOptions, OutputFormat, PortEntry, Protocol, SocketState, SortField,
        expand_port_ranges, parse_port_spec,
    };
    use crate::scanner::{find_free_ports, probe_ports, wait_for_port};
    use crate::snapshot::{create_snapshot, diff_snapshot, parse_snapshot, serialize_snapshot};

    fn sample_entry(port: u16, addr: &str, proc_name: &str, state: SocketState) -> PortEntry {
        PortEntry {
            protocol: Protocol::Tcp,
            local_addr: addr.to_string(),
            local_port: port,
            remote_addr: "*".to_string(),
            remote_port: 0,
            state,
            pid: Some(1000 + port as u32),
            ppid: Some(1),
            user: Some("efekan".to_string()),
            process_name: Some(proc_name.to_string()),
            cmdline: Some(format!("/usr/bin/{proc_name} --port {port}")),
            memory_kb: Some(4096),
        }
    }

    #[test]
    fn test_bind_scope_classification() {
        assert_eq!(BindScope::classify("127.0.0.1"), BindScope::Loopback);
        assert_eq!(BindScope::classify("::1"), BindScope::Loopback);
        assert_eq!(BindScope::classify("0.0.0.0"), BindScope::AllInterfaces);
        assert_eq!(BindScope::classify("*"), BindScope::AllInterfaces);
        assert_eq!(BindScope::classify("::"), BindScope::AllInterfaces);
        assert_eq!(BindScope::classify("192.168.1.50"), BindScope::Lan);
        assert_eq!(BindScope::classify("10.0.0.5"), BindScope::Lan);
        assert_eq!(BindScope::classify("8.8.8.8"), BindScope::Public);
    }

    #[test]
    fn test_port_spec_and_expand() {
        let ranges = parse_port_spec("80,443,8000-8002").unwrap();
        let ports = expand_port_ranges(&ranges, 100).unwrap();
        assert_eq!(ports, vec![80, 443, 8000, 8001, 8002]);
        assert!(parse_port_spec("9000-8000").is_err());
    }

    #[test]
    fn test_filter_and_sort() {
        let mut entries = vec![
            sample_entry(8080, "0.0.0.0", "node", SocketState::Listen),
            sample_entry(5432, "127.0.0.1", "postgres", SocketState::Listen),
            sample_entry(3000, "127.0.0.1", "vite", SocketState::Established),
        ];
        entries[1].memory_kb = Some(65536);

        let filter = FilterOptions {
            exposed_only: true,
            listen_only: true,
            ..Default::default()
        };
        let exposed: Vec<_> = entries.iter().filter(|e| filter.matches(e)).collect();
        assert_eq!(exposed.len(), 1);
        assert_eq!(exposed[0].local_port, 8080);

        let sort_mem = FilterOptions {
            sort_by: SortField::Memory,
            descending: true,
            ..Default::default()
        };
        sort_mem.sort_entries(&mut entries);
        assert_eq!(entries[0].local_port, 5432);
    }

    #[test]
    fn test_audit_detects_exposed_database_and_leaks() {
        let mut entries = vec![
            sample_entry(6379, "0.0.0.0", "redis-server", SocketState::Listen),
            sample_entry(5432, "0.0.0.0", "postgres", SocketState::Listen),
            sample_entry(3000, "127.0.0.1", "node", SocketState::Listen),
        ];
        for i in 0..25 {
            entries.push(sample_entry(
                40000 + i,
                "127.0.0.1",
                "leaky-app",
                SocketState::CloseWait,
            ));
        }

        let report = run_audit_analysis(&entries);
        assert!(report.has_high_or_critical());
        assert!(report.score < 70);
        assert!(report.findings.iter().any(|f| f.severity == Severity::Critical && f.port == Some(6379)));
        assert!(report.findings.iter().any(|f| f.severity == Severity::High && f.port == Some(5432)));
        assert!(report.findings.iter().any(|f| f.code == "SOCK-CLOSEWAIT"));
    }

    #[test]
    fn test_snapshot_roundtrip_and_diff() {
        let base_entries = vec![
            sample_entry(80, "0.0.0.0", "nginx", SocketState::Listen),
            sample_entry(5432, "127.0.0.1", "postgres", SocketState::Listen),
        ];
        let snap = create_snapshot(&base_entries);
        let serialized = serialize_snapshot(&snap);
        let parsed = parse_snapshot(&serialized).unwrap();
        assert_eq!(parsed.entries.len(), 2);

        let mut live_entries = vec![
            sample_entry(80, "0.0.0.0", "caddy", SocketState::Listen), // changed process
            sample_entry(3000, "127.0.0.1", "node", SocketState::Listen), // added
        ];
        live_entries[0].pid = Some(9999);

        let diff = diff_snapshot(&parsed, &live_entries);
        assert!(diff.has_drift());
        assert_eq!(diff.added.len(), 1);
        assert_eq!(diff.added[0].local_port, 3000);
        assert_eq!(diff.removed.len(), 1);
        assert_eq!(diff.removed[0].local_port, 5432);
        assert_eq!(diff.changed.len(), 1);
        assert_eq!(diff.changed[0].after.local_port, 80);
    }

    #[test]
    fn test_cli_parsing_advanced_commands() {
        let args = parse_args(
            ["sierraport", "list", "--wide", "--exposed", "--sort", "mem", "--desc", "--csv"]
                .map(String::from),
        )
        .unwrap();
        assert_eq!(args.global.format, OutputFormat::Csv);
        assert!(args.global.wide);
        match args.command {
            Command::List { filter } => {
                assert!(filter.exposed_only);
                assert_eq!(filter.sort_by, SortField::Memory);
                assert!(filter.descending);
            }
            _ => panic!("expected List"),
        }

        let audit = parse_args(["sierraport", "audit", "--strict", "--json"].map(String::from)).unwrap();
        assert!(audit.global.is_json());
        assert!(matches!(audit.command, Command::Audit { strict: true, .. }));

        let diff = parse_args(["sierraport", "diff", "base.json", "--fail-on-drift"].map(String::from)).unwrap();
        assert!(matches!(
            diff.command,
            Command::Snapshot(SnapshotAction::Diff { fail_on_drift: true, .. })
        ));

        let kill = parse_args(["sierraport", "kill", "--proc", "node", "-f", "-y", "--wait"].map(String::from)).unwrap();
        assert!(matches!(
            kill.command,
            Command::Kill {
                target: KillTarget::Process(_),
                force: true,
                yes: true,
                wait_release: true
            }
        ));
    }

    #[test]
    fn test_live_free_probe_and_wait() {
        let free = find_free_ports("127.0.0.1", 41000, 42000, 2).unwrap();
        assert_eq!(free.len(), 2);

        let listener = TcpListener::bind(("127.0.0.1", free[0])).unwrap();
        let bound_port = listener.local_addr().unwrap().port();

        let probed = probe_ports("127.0.0.1", &[bound_port, free[1]], 300, false, 4).unwrap();
        assert_eq!(probed.len(), 2);
        let p_open = probed.iter().find(|r| r.port == bound_port).unwrap();
        assert!(p_open.open);

        // wait_for_port open should succeed immediately
        let waited = wait_for_port("127.0.0.1", bound_port, true, 1000, 50).unwrap();
        assert!(waited < 1000);

        drop(listener);
        // wait_for_port closed should succeed after drop
        let waited_closed = wait_for_port("127.0.0.1", bound_port, false, 1000, 50).unwrap();
        assert!(waited_closed < 1000);
    }

    #[test]
    fn test_security_zerotrust_lan_and_airplay_spoof() {
        use crate::audit::{AuditOptions, AuditProfile, run_audit_with_options};

        // 1. LAN-bound listener must be flagged under ZeroTrust
        let lan_entries = vec![
            sample_entry(9999, "192.168.1.10", "internal-svc", SocketState::Listen),
            sample_entry(6379, "10.0.0.5", "redis-server", SocketState::Listen),
        ];
        let zt = run_audit_with_options(
            &lan_entries,
            AuditOptions {
                profile: AuditProfile::ZeroTrust,
                deep_scan: false,
                check_host: false,
            },
        );
        assert!(zt.findings.iter().any(|f| f.code == "ZT-EXPOSED" && f.port == Some(9999)));
        assert!(zt.findings.iter().any(|f| f.code == "EXP-CRIT" && f.port == Some(6379)));

        // 2. Spoofed ControlCe process on port 5000 without Apple ControlCenter path must NOT be exempted
        let mut spoof = sample_entry(5000, "0.0.0.0", "ControlCe_evil", SocketState::Listen);
        spoof.cmdline = Some("/tmp/ControlCe_evil".to_string());
        let dev = run_audit_with_options(
            &[spoof],
            AuditOptions {
                profile: AuditProfile::Developer,
                deep_scan: false,
                check_host: false,
            },
        );
        assert!(dev.findings.iter().any(|f| f.code == "EXP-DEV" && f.port == Some(5000)));
    }

    #[test]
    fn test_security_sanitize_json_and_kill_guards() {
        use crate::display::{json_escape, sanitize_terminal};
        use crate::scanner::terminate_pid;

        assert_eq!(sanitize_terminal("ok\x1b]0;spoof\x07\r\nend"), "ok]0;spoofend");
        assert_eq!(json_escape("My\\x20App\"test"), "My\\\\x20App\\\"test");

        assert!(terminate_pid(0, false).is_err());
        assert!(terminate_pid(1, false).is_err());
        assert!(terminate_pid(std::process::id(), false).is_err());
    }
}
