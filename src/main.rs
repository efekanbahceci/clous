mod cli;
mod commands;
mod display;
mod models;
mod scanner;

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
        } => commands::run_watch(&filter, interval_ms, &parsed.global),
        Command::Check {
            host,
            ports_spec,
            timeout_ms,
        } => commands::run_check(&host, &ports_spec, timeout_ms, &parsed.global),
        Command::Who { port } => commands::run_who(port, &parsed.global),
        Command::Kill { port, force, yes } => {
            commands::run_kill(port, force, yes, &parsed.global)
        }
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
