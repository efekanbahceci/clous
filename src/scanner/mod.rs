#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;

use std::net::{SocketAddr, TcpStream, ToSocketAddrs};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::models::{PortEntry, ProbeResult, well_known_service};

/// Scan system sockets using the fastest native method for the current OS.
pub fn scan_ports() -> Result<Vec<PortEntry>, String> {
    #[cfg(target_os = "linux")]
    {
        linux::scan_system_ports()
    }
    #[cfg(target_os = "macos")]
    {
        macos::scan_system_ports()
    }
    #[cfg(target_os = "windows")]
    {
        windows::scan_system_ports()
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        Err("Unsupported operating system".to_string())
    }
}

/// Concurrently probe TCP connectivity to a list of ports on `host`.
pub fn probe_ports(host: &str, ports: &[u16], timeout_ms: u64) -> Result<Vec<ProbeResult>, String> {
    let timeout = Duration::from_millis(timeout_ms);

    // Resolve host once using the first port to fail fast on invalid hostnames.
    let first_port = *ports.first().ok_or_else(|| "No ports to probe".to_string())?;
    let base_ip = format!("{host}:{first_port}")
        .to_socket_addrs()
        .map_err(|e| format!("Failed to resolve host '{host}': {e}"))?
        .next()
        .ok_or_else(|| format!("Could not resolve host '{host}'"))?
        .ip();

    let worker_count = ports.len().clamp(1, 64);
    let queue = Arc::new(Mutex::new(ports.to_vec()));
    let results = Arc::new(Mutex::new(Vec::with_capacity(ports.len())));
    let host_owned = host.to_string();

    let mut handles = Vec::with_capacity(worker_count);
    for _ in 0..worker_count {
        let queue = Arc::clone(&queue);
        let results = Arc::clone(&results);
        let host_clone = host_owned.clone();

        handles.push(thread::spawn(move || {
            loop {
                let next_port = {
                    let mut q = queue.lock().unwrap();
                    q.pop()
                };
                let Some(port) = next_port else {
                    break;
                };

                let addr = SocketAddr::new(base_ip, port);
                let start = Instant::now();
                let open = TcpStream::connect_timeout(&addr, timeout).is_ok();
                let latency_ms = start.elapsed().as_secs_f64() * 1000.0;

                let res = ProbeResult {
                    host: host_clone.clone(),
                    port,
                    open,
                    latency_ms,
                    service_hint: well_known_service(port),
                };
                results.lock().unwrap().push(res);
            }
        }));
    }

    for h in handles {
        let _ = h.join();
    }

    let mut out = Arc::try_unwrap(results).unwrap().into_inner().unwrap();
    out.sort_by_key(|r| r.port);
    Ok(out)
}

/// Terminate a process by PID in a cross-platform way.
pub fn terminate_pid(pid: u32, force: bool) -> Result<(), String> {
    #[cfg(unix)]
    {
        let signal = if force { "-9" } else { "-15" };
        let status = Command::new("kill")
            .args([signal, &pid.to_string()])
            .status()
            .map_err(|e| format!("Failed to invoke kill: {e}"))?;
        if status.success() {
            Ok(())
        } else {
            Err(format!("Failed to terminate PID {pid} (check permissions)"))
        }
    }

    #[cfg(windows)]
    {
        let mut args = vec!["/PID".to_string(), pid.to_string()];
        if force {
            args.push("/F".to_string());
        }
        let status = Command::new("taskkill")
            .args(&args)
            .status()
            .map_err(|e| format!("Failed to invoke taskkill: {e}"))?;
        if status.success() {
            Ok(())
        } else {
            Err(format!("Failed to terminate PID {pid} (check permissions)"))
        }
    }
}
