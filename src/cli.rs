use crate::audit::AuditProfile;
use crate::models::{
    FilterOptions, OutputFormat, SocketState, SortField, parse_port_spec,
};

#[derive(Debug, Clone)]
pub struct GlobalOptions {
    pub format: OutputFormat,
    pub wide: bool,
    pub no_color: bool,
}

impl GlobalOptions {
    pub fn is_json(&self) -> bool {
        self.format == OutputFormat::Json
    }
}

#[derive(Debug, Clone)]
pub enum KillTarget {
    Ports(String),
    Pid(u32),
    Process(String),
}

#[derive(Debug, Clone)]
pub enum SnapshotAction {
    Save {
        path: String,
        filter: FilterOptions,
    },
    Diff {
        path: String,
        filter: FilterOptions,
        fail_on_drift: bool,
    },
}

#[derive(Debug, Clone)]
pub enum Command {
    List {
        filter: FilterOptions,
    },
    Watch {
        filter: FilterOptions,
        interval_ms: u64,
        log_file: Option<String>,
        alert_new: bool,
    },
    Stream {
        filter: FilterOptions,
        interval_ms: u64,
    },
    Check {
        host: String,
        ports_spec: String,
        timeout_ms: u64,
        banner: bool,
        open_only: bool,
        concurrency: usize,
    },
    Who {
        port: u16,
    },
    Inspect {
        port: u16,
        probe: bool,
        timeout_ms: u64,
    },
    Audit {
        filter: FilterOptions,
        strict: bool,
        profile: AuditProfile,
        deep: bool,
    },
    Snapshot(SnapshotAction),
    Free {
        host: String,
        range_start: u16,
        range_end: u16,
        count: usize,
        plain: bool,
    },
    Wait {
        host: String,
        port: u16,
        wait_until_open: bool,
        timeout_ms: u64,
        interval_ms: u64,
    },
    Kill {
        target: KillTarget,
        force: bool,
        yes: bool,
        wait_release: bool,
    },
    Stats {
        filter: FilterOptions,
    },
    Help,
    Version,
}

#[derive(Debug, Clone)]
pub struct CliArgs {
    pub command: Command,
    pub global: GlobalOptions,
}

pub fn parse_args<I: IntoIterator<Item = String>>(args: I) -> Result<CliArgs, String> {
    let raw: Vec<String> = args.into_iter().skip(1).collect();

    let mut global = GlobalOptions {
        format: OutputFormat::Table,
        wide: false,
        no_color: std::env::var_os("NO_COLOR").is_some(),
    };

    if raw.is_empty() {
        return Ok(CliArgs {
            command: Command::List {
                filter: FilterOptions {
                    listen_only: true,
                    ..Default::default()
                },
            },
            global,
        });
    }

    let first = raw[0].as_str();
    match first {
        "-h" | "--help" | "help" => {
            return Ok(CliArgs {
                command: Command::Help,
                global,
            });
        }
        "-V" | "--version" | "version" => {
            return Ok(CliArgs {
                command: Command::Version,
                global,
            });
        }
        _ => {}
    }

    let (subcmd, rest) = if first.starts_with('-') {
        ("list", &raw[..])
    } else {
        (first, &raw[1..])
    };

    match subcmd {
        "list" | "ls" => {
            let filter = parse_filter_flags(rest, &mut global, true)?;
            Ok(CliArgs {
                command: Command::List { filter },
                global,
            })
        }
        "watch" | "monitor" | "w" => {
            let mut interval_ms: u64 = 1000;
            let mut log_file: Option<String> = None;
            let mut alert_new = false;
            let mut filtered_rest = Vec::new();
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "-i" | "--interval" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --interval".to_string())?;
                        interval_ms = val
                            .parse()
                            .map_err(|_| format!("Invalid interval (ms): '{val}'"))?;
                        if interval_ms < 100 {
                            return Err("Minimum interval is 100ms".to_string());
                        }
                    }
                    "--log" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing file path for --log".to_string())?;
                        log_file = Some(val.clone());
                    }
                    "--alert-new" | "--bell" => alert_new = true,
                    other => filtered_rest.push(other.to_string()),
                }
                i += 1;
            }
            let filter = parse_filter_flags(&filtered_rest, &mut global, true)?;
            Ok(CliArgs {
                command: Command::Watch {
                    filter,
                    interval_ms,
                    log_file,
                    alert_new,
                },
                global,
            })
        }
        "stream" => {
            let mut interval_ms: u64 = 1000;
            let mut filtered_rest = Vec::new();
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "-i" | "--interval" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --interval".to_string())?;
                        interval_ms = val
                            .parse()
                            .map_err(|_| format!("Invalid interval (ms): '{val}'"))?;
                        if interval_ms < 200 {
                            return Err("Minimum stream interval is 200ms".to_string());
                        }
                    }
                    other => filtered_rest.push(other.to_string()),
                }
                i += 1;
            }
            let filter = parse_filter_flags(&filtered_rest, &mut global, true)?;
            Ok(CliArgs {
                command: Command::Stream {
                    filter,
                    interval_ms,
                },
                global,
            })
        }
        "check" | "probe" | "ping" => {
            let mut host = "127.0.0.1".to_string();
            let mut timeout_ms: u64 = 500;
            let mut banner = false;
            let mut open_only = false;
            let mut concurrency: usize = 64;
            let mut positional = Vec::new();
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "-H" | "--host" => {
                        i += 1;
                        host = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --host".to_string())?
                            .clone();
                    }
                    "-t" | "--timeout" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --timeout".to_string())?;
                        timeout_ms = val
                            .parse()
                            .map_err(|_| format!("Invalid timeout (ms): '{val}'"))?;
                    }
                    "-b" | "--banner" => banner = true,
                    "--open-only" => open_only = true,
                    "-c" | "--concurrency" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --concurrency".to_string())?;
                        concurrency = val
                            .parse()
                            .map_err(|_| format!("Invalid concurrency: '{val}'"))?;
                    }
                    "--json" => global.format = OutputFormat::Json,
                    "--no-color" => global.no_color = true,
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    arg if arg.starts_with('-') => {
                        return Err(format!("Unknown flag for check: '{arg}'"));
                    }
                    arg => positional.push(arg.to_string()),
                }
                i += 1;
            }
            let ports_spec = positional
                .first()
                .ok_or_else(|| "Usage: clous check <port|range|list> [host]".to_string())?
                .clone();
            if let Some(h) = positional.get(1) {
                host = h.clone();
            }
            Ok(CliArgs {
                command: Command::Check {
                    host,
                    ports_spec,
                    timeout_ms,
                    banner,
                    open_only,
                    concurrency,
                },
                global,
            })
        }
        "who" | "find" | "pid" => {
            let mut port_opt: Option<u16> = None;
            for arg in rest {
                match arg.as_str() {
                    "--json" => global.format = OutputFormat::Json,
                    "--no-color" => global.no_color = true,
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    a if a.starts_with('-') => {
                        return Err(format!("Unknown flag for who: '{a}'"));
                    }
                    a => {
                        let p: u16 = a
                            .parse()
                            .map_err(|_| format!("Invalid port number: '{a}'"))?;
                        port_opt = Some(p);
                    }
                }
            }
            let port = port_opt.ok_or_else(|| "Usage: clous who <port>".to_string())?;
            Ok(CliArgs {
                command: Command::Who { port },
                global,
            })
        }
        "inspect" | "info" | "deep" => {
            let mut port_opt: Option<u16> = None;
            let mut probe = false;
            let mut timeout_ms: u64 = 500;
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "--probe" | "-b" => probe = true,
                    "-t" | "--timeout" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --timeout".to_string())?;
                        timeout_ms = val
                            .parse()
                            .map_err(|_| format!("Invalid timeout (ms): '{val}'"))?;
                    }
                    "--json" => global.format = OutputFormat::Json,
                    "--no-color" => global.no_color = true,
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    a if a.starts_with('-') => {
                        return Err(format!("Unknown flag for inspect: '{a}'"));
                    }
                    a => {
                        let p: u16 = a
                            .parse()
                            .map_err(|_| format!("Invalid port number: '{a}'"))?;
                        port_opt = Some(p);
                    }
                }
                i += 1;
            }
            let port = port_opt
                .ok_or_else(|| "Usage: clous inspect <port> [--probe]".to_string())?;
            Ok(CliArgs {
                command: Command::Inspect {
                    port,
                    probe,
                    timeout_ms,
                },
                global,
            })
        }
        "audit" | "sec" | "security" => {
            let mut strict = false;
            let mut profile = AuditProfile::Developer;
            let mut deep = false;
            let mut filtered_rest = Vec::new();
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "--strict" => strict = true,
                    "--deep" | "--active" => deep = true,
                    "--profile" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --profile".to_string())?;
                        profile = AuditProfile::parse(val)?;
                    }
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    other => filtered_rest.push(other.to_string()),
                }
                i += 1;
            }
            let filter = parse_filter_flags(&filtered_rest, &mut global, false)?;
            Ok(CliArgs {
                command: Command::Audit {
                    filter,
                    strict,
                    profile,
                    deep,
                },
                global,
            })
        }
        "snapshot" | "snap" => {
            let action = rest
                .first()
                .map(|s| s.as_str())
                .ok_or_else(|| "Usage: clous snapshot <save|diff> <file>".to_string())?;
            let tail = &rest[1..];
            match action {
                "save" => {
                    let mut path: Option<String> = None;
                    let mut flag_args = Vec::new();
                    for arg in tail {
                        if !arg.starts_with('-') && path.is_none() {
                            path = Some(arg.clone());
                        } else {
                            flag_args.push(arg.clone());
                        }
                    }
                    let path = path.ok_or_else(|| {
                        "Usage: clous snapshot save <file>".to_string()
                    })?;
                    let filter = parse_filter_flags(&flag_args, &mut global, true)?;
                    Ok(CliArgs {
                        command: Command::Snapshot(SnapshotAction::Save { path, filter }),
                        global,
                    })
                }
                "diff" => parse_diff_args(tail, global),
                other => Err(format!(
                    "Unknown snapshot subcommand: '{other}'. Use 'save' or 'diff'."
                )),
            }
        }
        "diff" => parse_diff_args(rest, global),
        "free" | "available" => {
            let mut host = "127.0.0.1".to_string();
            let mut range_start: u16 = 3000;
            let mut range_end: u16 = 9999;
            let mut count: usize = 1;
            let mut plain = false;
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "-H" | "--host" => {
                        i += 1;
                        host = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --host".to_string())?
                            .clone();
                    }
                    "-r" | "--range" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --range".to_string())?;
                        let ranges = parse_port_spec(val)?;
                        if let Some(first) = ranges.first() {
                            range_start = first.start;
                            range_end = first.end;
                        }
                    }
                    "-n" | "--count" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --count".to_string())?;
                        count = val
                            .parse()
                            .map_err(|_| format!("Invalid count: '{val}'"))?;
                        if count == 0 || count > 256 {
                            return Err("Count must be between 1 and 256".to_string());
                        }
                    }
                    "--plain" | "-q" => plain = true,
                    "--json" => global.format = OutputFormat::Json,
                    "--no-color" => global.no_color = true,
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    other => return Err(format!("Unknown flag for free: '{other}'")),
                }
                i += 1;
            }
            Ok(CliArgs {
                command: Command::Free {
                    host,
                    range_start,
                    range_end,
                    count,
                    plain,
                },
                global,
            })
        }
        "wait" => {
            let mut host = "127.0.0.1".to_string();
            let mut wait_until_open = true;
            let mut timeout_ms: u64 = 30_000;
            let mut interval_ms: u64 = 250;
            let mut positional = Vec::new();
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "-H" | "--host" => {
                        i += 1;
                        host = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --host".to_string())?
                            .clone();
                    }
                    "--until" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --until".to_string())?;
                        match val.to_ascii_lowercase().as_str() {
                            "open" | "up" | "ready" => wait_until_open = true,
                            "closed" | "close" | "down" => wait_until_open = false,
                            other => {
                                return Err(format!(
                                    "Invalid --until value '{other}'. Expected 'open' or 'closed'."
                                ));
                            }
                        }
                    }
                    "-t" | "--timeout" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --timeout".to_string())?;
                        timeout_ms = val
                            .parse()
                            .map_err(|_| format!("Invalid timeout (ms): '{val}'"))?;
                    }
                    "-i" | "--interval" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --interval".to_string())?;
                        interval_ms = val
                            .parse()
                            .map_err(|_| format!("Invalid interval (ms): '{val}'"))?;
                    }
                    "--json" => global.format = OutputFormat::Json,
                    "--no-color" => global.no_color = true,
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    a if a.starts_with('-') => {
                        return Err(format!("Unknown flag for wait: '{a}'"));
                    }
                    a => positional.push(a.to_string()),
                }
                i += 1;
            }
            let port_s = positional
                .first()
                .ok_or_else(|| "Usage: clous wait <port> [host] [--until open|closed]".to_string())?;
            let port: u16 = port_s
                .parse()
                .map_err(|_| format!("Invalid port number: '{port_s}'"))?;
            if let Some(h) = positional.get(1) {
                host = h.clone();
            }
            Ok(CliArgs {
                command: Command::Wait {
                    host,
                    port,
                    wait_until_open,
                    timeout_ms,
                    interval_ms,
                },
                global,
            })
        }
        "kill" => {
            let mut target: Option<KillTarget> = None;
            let mut force = false;
            let mut yes = false;
            let mut wait_release = false;
            let mut i = 0;
            while i < rest.len() {
                match rest[i].as_str() {
                    "-f" | "--force" => force = true,
                    "-y" | "--yes" => yes = true,
                    "--wait" => wait_release = true,
                    "--pid" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --pid".to_string())?;
                        let pid: u32 = val
                            .parse()
                            .map_err(|_| format!("Invalid PID: '{val}'"))?;
                        target = Some(KillTarget::Pid(pid));
                    }
                    "--proc" | "--process" => {
                        i += 1;
                        let val = rest
                            .get(i)
                            .ok_or_else(|| "Missing value for --proc".to_string())?;
                        target = Some(KillTarget::Process(val.clone()));
                    }
                    "--json" => global.format = OutputFormat::Json,
                    "--no-color" => global.no_color = true,
                    "-h" | "--help" => {
                        return Ok(CliArgs {
                            command: Command::Help,
                            global,
                        });
                    }
                    a if a.starts_with('-') => {
                        return Err(format!("Unknown flag for kill: '{a}'"));
                    }
                    a => {
                        // Validate port spec early
                        parse_port_spec(a)?;
                        target = Some(KillTarget::Ports(a.to_string()));
                    }
                }
                i += 1;
            }
            let target = target.ok_or_else(|| {
                "Usage: clous kill <port|range|list> | --pid <PID> | --proc <NAME> [-f] [-y] [--wait]"
                    .to_string()
            })?;
            Ok(CliArgs {
                command: Command::Kill {
                    target,
                    force,
                    yes,
                    wait_release,
                },
                global,
            })
        }
        "stats" | "summary" => {
            let filter = parse_filter_flags(rest, &mut global, false)?;
            Ok(CliArgs {
                command: Command::Stats { filter },
                global,
            })
        }
        other => Err(format!(
            "Unknown command: '{other}'. Run 'clous --help' for usage."
        )),
    }
}

fn parse_diff_args(args: &[String], mut global: GlobalOptions) -> Result<CliArgs, String> {
    let mut path: Option<String> = None;
    let mut fail_on_drift = false;
    let mut flag_args = Vec::new();
    for arg in args {
        match arg.as_str() {
            "--fail-on-drift" => fail_on_drift = true,
            "-h" | "--help" => {
                return Ok(CliArgs {
                    command: Command::Help,
                    global,
                });
            }
            a if !a.starts_with('-') && path.is_none() => path = Some(a.to_string()),
            other => flag_args.push(other.to_string()),
        }
    }
    let path = path.ok_or_else(|| "Usage: clous diff <snapshot.json> [--fail-on-drift]".to_string())?;
    let filter = parse_filter_flags(&flag_args, &mut global, true)?;
    Ok(CliArgs {
        command: Command::Snapshot(SnapshotAction::Diff {
            path,
            filter,
            fail_on_drift,
        }),
        global,
    })
}

fn parse_filter_flags(
    args: &[String],
    global: &mut GlobalOptions,
    default_listen_only: bool,
) -> Result<FilterOptions, String> {
    let mut filter = FilterOptions {
        listen_only: default_listen_only,
        ..Default::default()
    };

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--tcp" | "-t" => filter.tcp_only = true,
            "--udp" | "-u" => filter.udp_only = true,
            "-4" | "--ipv4" => filter.ipv4_only = true,
            "-6" | "--ipv6" => filter.ipv6_only = true,
            "--listen" | "-l" => {
                filter.listen_only = true;
                filter.all_states = false;
            }
            "--all" | "-a" => {
                filter.all_states = true;
                filter.listen_only = false;
            }
            "--exposed" => filter.exposed_only = true,
            "--state" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "Missing value for --state".to_string())?;
                filter.state_filter = Some(SocketState::from_name(val));
                filter.all_states = true;
                filter.listen_only = false;
            }
            "--user" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "Missing value for --user".to_string())?;
                filter.user_filter = Some(val.clone());
            }
            "--port" | "-p" => {
                i += 1;
                let spec = args
                    .get(i)
                    .ok_or_else(|| "Missing value for --port".to_string())?;
                let mut ranges = parse_port_spec(spec)?;
                filter.port_ranges.append(&mut ranges);
            }
            "--proc" | "--process" => {
                i += 1;
                let name = args
                    .get(i)
                    .ok_or_else(|| "Missing value for --proc".to_string())?;
                filter.process_filter = Some(name.clone());
            }
            "--sort" | "-s" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "Missing value for --sort".to_string())?;
                filter.sort_by = SortField::parse(val)?;
            }
            "--desc" | "-r" => filter.descending = true,
            "-w" | "--wide" => global.wide = true,
            "--format" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "Missing value for --format".to_string())?;
                global.format = OutputFormat::parse(val)?;
            }
            "--json" => global.format = OutputFormat::Json,
            "--csv" => global.format = OutputFormat::Csv,
            "--compact" => global.format = OutputFormat::Compact,
            "--no-color" => global.no_color = true,
            other => return Err(format!("Unknown option: '{other}'")),
        }
        i += 1;
    }

    if filter.tcp_only && filter.udp_only {
        filter.tcp_only = false;
        filter.udp_only = false;
    }
    if filter.ipv4_only && filter.ipv6_only {
        filter.ipv4_only = false;
        filter.ipv6_only = false;
    }

    Ok(filter)
}

pub fn help_text() -> &'static str {
    r#"Clous — Advanced terminal port monitoring, security audit & inspection system

USAGE:
  clous [COMMAND] [OPTIONS]

COMMANDS:
  list, ls                 List active ports with bind exposure & runtime tags
  watch, monitor, w        Live real-time port monitor with open/close diff log
  inspect, info <port>     Deep forensic inspection (process ancestry, peers, probe)
  audit, sec               Security & socket health audit with 0-100 score
  snapshot save <file>     Save current port baseline snapshot to JSON
  diff <file>              Detect port/process drift against a saved snapshot
  check, probe <ports>     Concurrent TCP port scanner with optional banner grabbing
  free                     Find available bindable TCP port(s) in a range
  wait <port> [host]       Wait until a port becomes open or closed (CI/dev helper)
  who, find, pid <port>    Quick lookup of process(es) occupying a port
  kill <target>            Terminate process(es) by port(s), --pid, or --proc
  stats, summary           Visual ASCII bar-chart socket & exposure statistics
  help / version           Show help or version information

FILTER, SORT & FORMAT OPTIONS (list / watch / stats / snapshot):
  -l, --listen             Show only listening/bound ports (default for list/watch)
  -a, --all                Show all socket states (ESTABLISHED, TIME_WAIT, etc.)
  -t, --tcp / -u, --udp    Filter by transport protocol
  -4, --ipv4 / -6, --ipv6  Filter by IP family
      --exposed            Show only externally exposed sockets (0.0.0.0 / :: / public)
      --state <STATE>      Filter by exact socket state (e.g. ESTABLISHED, CLOSE_WAIT)
      --user <NAME>        Filter by socket owner username
  -p, --port <SPEC>        Filter by port, list, or range (e.g. 80,443 or 8000-9000)
      --proc <NAME>        Filter by process name or full command line
  -s, --sort <FIELD>       Sort by: port, pid, process, state, proto, mem
  -r, --desc               Reverse sort order
  -w, --wide               Wide table (adds USER, MEM, CMDLINE)
      --format <FMT>       Output format: table, json, csv, compact (or --json/--csv/--compact)
      --no-color           Disable ANSI colors

COMMAND-SPECIFIC OPTIONS:
  watch:    -i, --interval <MS>  |  --log <FILE>  |  --alert-new
  inspect:  --probe (banner/HTTP probe)  |  -t, --timeout <MS>
  audit:    --strict (exit non-zero on HIGH/CRITICAL findings)
  diff:     --fail-on-drift (exit non-zero if baseline drift detected)
  check:    -H, --host <HOST> | -t <MS> | -b, --banner | --open-only | -c <THREADS>
  free:     -r, --range <3000-9999> | -n, --count <N> | -H <HOST> | --plain
  wait:     --until <open|closed> | -t, --timeout <MS> | -i, --interval <MS>
  kill:     <PORT|RANGE> | --pid <PID> | --proc <NAME> | -f, --force | -y, --yes | --wait

EXAMPLES:
  clous list --wide --sort mem --desc
  clous audit --strict
  clous inspect 5432 --probe
  clous check 1-1024 127.0.0.1 --open-only --banner
  clous snapshot save baseline.json && clous diff baseline.json
  clous free --range 8000-8999 --count 3 --plain
  clous wait 3000 --until open --timeout 15000
  clous watch -i 500 --log events.log --alert-new"#
}
