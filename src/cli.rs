use crate::models::{FilterOptions, parse_port_spec};

#[derive(Debug, Clone)]
pub struct GlobalOptions {
    pub json: bool,
    pub no_color: bool,
}

#[derive(Debug, Clone)]
pub enum Command {
    List {
        filter: FilterOptions,
    },
    Watch {
        filter: FilterOptions,
        interval_ms: u64,
    },
    Check {
        host: String,
        ports_spec: String,
        timeout_ms: u64,
    },
    Who {
        port: u16,
    },
    Kill {
        port: u16,
        force: bool,
        yes: bool,
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
        json: false,
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
                    other => filtered_rest.push(other.to_string()),
                }
                i += 1;
            }
            let filter = parse_filter_flags(&filtered_rest, &mut global, true)?;
            Ok(CliArgs {
                command: Command::Watch {
                    filter,
                    interval_ms,
                },
                global,
            })
        }
        "check" | "probe" | "ping" => {
            let mut host = "127.0.0.1".to_string();
            let mut timeout_ms: u64 = 500;
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
                    "--json" => global.json = true,
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
                .ok_or_else(|| "Usage: sierraport check <port|range|list> [host]".to_string())?
                .clone();
            if let Some(h) = positional.get(1) {
                host = h.clone();
            }
            Ok(CliArgs {
                command: Command::Check {
                    host,
                    ports_spec,
                    timeout_ms,
                },
                global,
            })
        }
        "who" | "find" | "pid" => {
            let mut port_opt: Option<u16> = None;
            for arg in rest {
                match arg.as_str() {
                    "--json" => global.json = true,
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
            let port = port_opt.ok_or_else(|| "Usage: sierraport who <port>".to_string())?;
            Ok(CliArgs {
                command: Command::Who { port },
                global,
            })
        }
        "kill" => {
            let mut port_opt: Option<u16> = None;
            let mut force = false;
            let mut yes = false;
            for arg in rest {
                match arg.as_str() {
                    "-f" | "--force" => force = true,
                    "-y" | "--yes" => yes = true,
                    "--json" => global.json = true,
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
                        let p: u16 = a
                            .parse()
                            .map_err(|_| format!("Invalid port number: '{a}'"))?;
                        port_opt = Some(p);
                    }
                }
            }
            let port =
                port_opt.ok_or_else(|| "Usage: sierraport kill <port> [-f] [-y]".to_string())?;
            Ok(CliArgs {
                command: Command::Kill { port, force, yes },
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
            "Unknown command: '{other}'. Run 'sierraport --help' for usage."
        )),
    }
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
            "--listen" | "-l" => {
                filter.listen_only = true;
                filter.all_states = false;
            }
            "--all" | "-a" => {
                filter.all_states = true;
                filter.listen_only = false;
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
            "--json" => global.json = true,
            "--no-color" => global.no_color = true,
            other => return Err(format!("Unknown option: '{other}'")),
        }
        i += 1;
    }

    if filter.tcp_only && filter.udp_only {
        filter.tcp_only = false;
        filter.udp_only = false;
    }

    Ok(filter)
}

pub fn help_text() -> &'static str {
    r#"SierraPort — Fast terminal port monitoring & inspection tool

USAGE:
  sierraport [COMMAND] [OPTIONS]

COMMANDS:
  list, ls                 List active ports (default: listening ports)
  watch, monitor, w        Live real-time port monitor with open/close diff log
  check, probe, ping       Fast concurrent TCP port connectivity check
  who, find, pid <port>    Show process(es) occupying a specific port
  kill <port>              Terminate process(es) listening on a port
  stats, summary           Show socket and protocol statistics
  help                     Show this help message
  version                  Show version information

LIST / WATCH / STATS OPTIONS:
  -l, --listen             Show only listening/bound ports (default for list/watch)
  -a, --all                Show all socket states (ESTABLISHED, TIME_WAIT, etc.)
  -t, --tcp                Filter TCP sockets only
  -u, --udp                Filter UDP sockets only
  -p, --port <SPEC>        Filter by port, list, or range (e.g. 80,443 or 8000-9000)
      --proc <NAME>        Filter by process name or command line
  -i, --interval <MS>      Refresh interval for watch mode (default: 1000, min: 100)
      --json               Output as JSON
      --no-color           Disable ANSI colors

CHECK OPTIONS:
  sierraport check <PORTS> [HOST] [-H HOST] [-t TIMEOUT_MS] [--json]
  Examples:
    sierraport check 80,443,8080
    sierraport check 8000-8020 127.0.0.1 -t 300

KILL OPTIONS:
  sierraport kill <PORT> [-f|--force] [-y|--yes]
  -f, --force              Send SIGKILL / force terminate
  -y, --yes                Skip confirmation prompt

EXAMPLES:
  sierraport                         List all listening ports
  sierraport list --all --tcp        List all TCP connections
  sierraport watch -i 500            Watch port changes every 500ms
  sierraport who 3000                Inspect what is running on port 3000
  sierraport kill 3000 -y            Kill process on port 3000 without prompt
  sierraport stats                   Show socket statistics overview"#
}
