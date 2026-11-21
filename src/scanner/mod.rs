#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;

use std::collections::HashSet;
use std::io::{Read, Write};
use std::net::{SocketAddr, TcpListener, TcpStream, ToSocketAddrs};
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::models::{PortEntry, ProbeResult, ProcessAncestor, well_known_service};

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

/// Resolve the process ancestry chain for a given PID.
pub fn get_process_ancestry(pid: u32) -> Vec<ProcessAncestor> {
    #[cfg(target_os = "linux")]
    {
        linux::get_process_ancestry(pid)
    }
    #[cfg(target_os = "macos")]
    {
        macos::get_process_ancestry(pid)
    }
    #[cfg(target_os = "windows")]
    {
        windows::get_process_ancestry(pid)
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        let _ = pid;
        Vec::new()
    }
}

/// Concurrently probe TCP connectivity (and optionally grab service banners) on `host`.
pub fn probe_ports(
    host: &str,
    ports: &[u16],
    timeout_ms: u64,
    grab_banner: bool,
    concurrency: usize,
) -> Result<Vec<ProbeResult>, String> {
    let timeout = Duration::from_millis(timeout_ms);

    let first_port = *ports
        .first()
        .ok_or_else(|| "No ports to probe".to_string())?;
    let base_ip = format!("{host}:{first_port}")
        .to_socket_addrs()
        .map_err(|e| format!("Failed to resolve host '{host}': {e}"))?
        .next()
        .ok_or_else(|| format!("Could not resolve host '{host}'"))?
        .ip();

    let worker_count = ports.len().clamp(1, concurrency.clamp(1, 256));
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
                let stream_res = TcpStream::connect_timeout(&addr, timeout);
                let latency_ms = start.elapsed().as_secs_f64() * 1000.0;

                let (open, banner, detected_protocol) = match stream_res {
                    Ok(mut stream) => {
                        if grab_banner {
                            let (b, proto) = inspect_banner(&mut stream, &host_clone, port, timeout);
                            (true, b, proto)
                        } else {
                            (true, None, None)
                        }
                    }
                    Err(_) => (false, None, None),
                };

                let res = ProbeResult {
                    host: host_clone.clone(),
                    port,
                    open,
                    latency_ms,
                    service_hint: well_known_service(port),
                    banner,
                    detected_protocol,
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

/// Attempt passive banner read first (SSH, SMTP, FTP, MySQL), then send a lightweight
/// HTTP HEAD or Redis PING probe if silent.
fn inspect_banner(
    stream: &mut TcpStream,
    host: &str,
    port: u16,
    timeout: Duration,
) -> (Option<String>, Option<String>) {
    let io_timeout = timeout.min(Duration::from_millis(600));
    let _ = stream.set_read_timeout(Some(Duration::from_millis(180)));
    let _ = stream.set_write_timeout(Some(io_timeout));

    let mut buf = [0u8; 512];
    if let Ok(n) = stream.read(&mut buf)
        && n > 0
    {
        return classify_banner(&buf[..n]);
    }

    // No immediate server-greeting banner — try an active lightweight probe.
    let _ = stream.set_read_timeout(Some(io_timeout));
    let probe: &[u8] = if port == 6379 {
        b"PING\r\n"
    } else {
        // Safe HTTP HEAD probe (sanitize host against CRLF injection)
        let safe_host: String = host.chars().filter(|c| !c.is_control()).collect();
        let req = format!("HEAD / HTTP/1.0\r\nHost: {safe_host}\r\nUser-Agent: SierraPort\r\n\r\n");
        if stream.write_all(req.as_bytes()).is_ok()
            && let Ok(n) = stream.read(&mut buf)
            && n > 0
        {
            return classify_banner(&buf[..n]);
        }
        return (None, None);
    };

    if stream.write_all(probe).is_ok()
        && let Ok(n) = stream.read(&mut buf)
        && n > 0
    {
        return classify_banner(&buf[..n]);
    }

    (None, None)
}

fn classify_banner(raw: &[u8]) -> (Option<String>, Option<String>) {
    let text = String::from_utf8_lossy(raw);
    let first_line = text
        .lines()
        .next()
        .unwrap_or("")
        .trim()
        .chars()
        .filter(|c| !c.is_control())
        .take(96)
        .collect::<String>();

    if first_line.starts_with("SSH-") {
        return (Some(first_line), Some("SSH".to_string()));
    }
    if first_line.starts_with("HTTP/") {
        // Also try to grab Server header if present (strip control chars & cap length)
        let server = text
            .lines()
            .find(|l| l.to_ascii_lowercase().starts_with("server:"))
            .map(|l| {
                l[7..]
                    .trim()
                    .chars()
                    .filter(|c| !c.is_control())
                    .take(64)
                    .collect::<String>()
            });
        let summary = match server {
            Some(srv) if !srv.is_empty() => format!("{first_line} ({srv})"),
            _ => first_line,
        };
        return (Some(summary), Some("HTTP".to_string()));
    }
    if first_line.starts_with("+PONG") || first_line.starts_with("-NOAUTH") || first_line.starts_with("-ERR") {
        return (Some(first_line), Some("Redis".to_string()));
    }
    if first_line.starts_with("220 ") {
        let lower = first_line.to_ascii_lowercase();
        let proto = if lower.contains("smtp") || lower.contains("esmtp") || lower.contains("postfix") {
            "SMTP"
        } else if lower.contains("ftp") {
            "FTP"
        } else {
            "SMTP/FTP"
        };
        return (Some(first_line), Some(proto.to_string()));
    }
    if raw.len() > 5 && raw[4] == 0x0a && text.contains("mysql") {
        return (Some("MySQL handshake".to_string()), Some("MySQL".to_string()));
    }
    if raw.len() >= 3 && raw[0] == 0x15 && raw[1] == 0x03 {
        return (Some("TLS alert/handshake".to_string()), Some("TLS".to_string()));
    }

    if !first_line.is_empty() {
        (Some(first_line), None)
    } else {
        (Some(format!("<binary {}B>", raw.len())), None)
    }
}

/// Find `count` free bindable TCP ports in `[start..=end]` on `host`.
pub fn find_free_ports(
    host: &str,
    start: u16,
    end: u16,
    count: usize,
) -> Result<Vec<u16>, String> {
    if start > end {
        return Err(format!("Range start ({start}) is greater than end ({end})"));
    }
    let occupied: HashSet<u16> = scan_ports()
        .unwrap_or_default()
        .into_iter()
        .map(|e| e.local_port)
        .collect();

    let mut found = Vec::with_capacity(count);
    for port in start..=end {
        if occupied.contains(&port) {
            continue;
        }
        if TcpListener::bind((host, port)).is_ok() {
            found.push(port);
            if found.len() >= count {
                break;
            }
        }
    }

    if found.is_empty() {
        return Err(format!(
            "No free ports found in range {start}-{end} on {host}"
        ));
    }
    Ok(found)
}

/// Wait until a TCP port reaches the desired state (open or closed), returning elapsed ms.
pub fn wait_for_port(
    host: &str,
    port: u16,
    wait_until_open: bool,
    timeout_ms: u64,
    interval_ms: u64,
) -> Result<u128, String> {
    let addr = format!("{host}:{port}")
        .to_socket_addrs()
        .map_err(|e| format!("Failed to resolve '{host}:{port}': {e}"))?
        .next()
        .ok_or_else(|| format!("Could not resolve '{host}:{port}'"))?;

    let start = Instant::now();
    let deadline = Duration::from_millis(timeout_ms);
    let interval = Duration::from_millis(interval_ms.max(50));
    let probe_timeout = Duration::from_millis(interval_ms.clamp(100, 1000));

    loop {
        let is_open = TcpStream::connect_timeout(&addr, probe_timeout).is_ok();
        if is_open == wait_until_open {
            return Ok(start.elapsed().as_millis());
        }
        if start.elapsed() >= deadline {
            let expected = if wait_until_open { "open" } else { "closed" };
            return Err(format!(
                "Timed out after {timeout_ms}ms waiting for {host}:{port} to become {expected}"
            ));
        }
        thread::sleep(interval);
    }
}

/// Terminate a process by PID in a cross-platform way.
pub fn terminate_pid(pid: u32, force: bool) -> Result<(), String> {
    if pid <= 1 || pid > i32::MAX as u32 {
        return Err(format!("Refusing to signal invalid or system PID {pid}"));
    }
    if pid == std::process::id() {
        return Err(format!("Refusing to terminate SierraPort itself (PID {pid})"));
    }

    #[cfg(unix)]
    {
        let signal = if force { "-9" } else { "-15" };
        let kill_bin = if std::path::Path::new("/bin/kill").exists() {
            "/bin/kill"
        } else {
            "kill"
        };
        let status = Command::new(kill_bin)
            .args([signal, &pid.to_string()])
            .status()
            .map_err(|e| format!("Failed to invoke kill: {e}"))?;
        if status.success() {
            Ok(())
        } else {
            Err(format!(
                "Failed to terminate PID {pid} (check permissions)"
            ))
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
            Err(format!(
                "Failed to terminate PID {pid} (check permissions)"
            ))
        }
    }
}
