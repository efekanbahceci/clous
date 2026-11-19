use std::fmt;

/// Network transport protocol.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum Protocol {
    Tcp,
    Tcp6,
    Udp,
    Udp6,
}

impl Protocol {
    pub fn is_tcp(self) -> bool {
        matches!(self, Protocol::Tcp | Protocol::Tcp6)
    }

    pub fn is_udp(self) -> bool {
        matches!(self, Protocol::Udp | Protocol::Udp6)
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Protocol::Tcp => "TCP",
            Protocol::Tcp6 => "TCP6",
            Protocol::Udp => "UDP",
            Protocol::Udp6 => "UDP6",
        }
    }
}

impl fmt::Display for Protocol {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// Socket lifecycle state.
#[derive(Debug, Clone, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum SocketState {
    Listen,
    Established,
    SynSent,
    SynRecv,
    FinWait1,
    FinWait2,
    TimeWait,
    Close,
    CloseWait,
    LastAck,
    Closing,
    Unknown(String),
}

impl SocketState {
    pub fn is_listening(&self) -> bool {
        matches!(self, SocketState::Listen)
    }

    pub fn as_str(&self) -> &str {
        match self {
            SocketState::Listen => "LISTEN",
            SocketState::Established => "ESTABLISHED",
            SocketState::SynSent => "SYN_SENT",
            SocketState::SynRecv => "SYN_RECV",
            SocketState::FinWait1 => "FIN_WAIT1",
            SocketState::FinWait2 => "FIN_WAIT2",
            SocketState::TimeWait => "TIME_WAIT",
            SocketState::Close => "CLOSE",
            SocketState::CloseWait => "CLOSE_WAIT",
            SocketState::LastAck => "LAST_ACK",
            SocketState::Closing => "CLOSING",
            SocketState::Unknown(s) => s.as_str(),
        }
    }

    /// Map Linux `/proc/net/*` hex state codes to `SocketState`.
    #[allow(dead_code)]
    pub fn from_linux_hex(hex: &str) -> Self {
        match hex {
            "01" => SocketState::Established,
            "02" => SocketState::SynSent,
            "03" => SocketState::SynRecv,
            "04" => SocketState::FinWait1,
            "05" => SocketState::FinWait2,
            "06" => SocketState::TimeWait,
            "07" => SocketState::Close,
            "08" => SocketState::CloseWait,
            "09" => SocketState::LastAck,
            "0A" => SocketState::Listen,
            "0B" => SocketState::Closing,
            other => SocketState::Unknown(other.to_string()),
        }
    }

    #[allow(dead_code)]
    pub fn from_name(name: &str) -> Self {
        match name.to_ascii_uppercase().as_str() {
            "LISTEN" | "LISTENING" => SocketState::Listen,
            "ESTABLISHED" => SocketState::Established,
            "SYN_SENT" => SocketState::SynSent,
            "SYN_RECV" | "SYN_RECEIVED" => SocketState::SynRecv,
            "FIN_WAIT1" | "FIN_WAIT_1" => SocketState::FinWait1,
            "FIN_WAIT2" | "FIN_WAIT_2" => SocketState::FinWait2,
            "TIME_WAIT" => SocketState::TimeWait,
            "CLOSE" | "CLOSED" => SocketState::Close,
            "CLOSE_WAIT" => SocketState::CloseWait,
            "LAST_ACK" => SocketState::LastAck,
            "CLOSING" => SocketState::Closing,
            other => SocketState::Unknown(other.to_string()),
        }
    }
}

impl fmt::Display for SocketState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// A single active socket / port entry discovered on the system.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct PortEntry {
    pub protocol: Protocol,
    pub local_addr: String,
    pub local_port: u16,
    pub remote_addr: String,
    pub remote_port: u16,
    pub state: SocketState,
    pub pid: Option<u32>,
    pub process_name: Option<String>,
    pub cmdline: Option<String>,
}

impl PortEntry {
    /// Key used to detect opened/closed ports between watch snapshots.
    pub fn identity_key(&self) -> (Protocol, String, u16, Option<u32>) {
        (
            self.protocol,
            self.local_addr.clone(),
            self.local_port,
            self.pid,
        )
    }

    pub fn local_endpoint(&self) -> String {
        if self.local_addr.contains(':') && !self.local_addr.starts_with('[') {
            format!("[{}]:{}", self.local_addr, self.local_port)
        } else {
            format!("{}:{}", self.local_addr, self.local_port)
        }
    }

    pub fn remote_endpoint(&self) -> String {
        if self.remote_port == 0 && (self.remote_addr == "0.0.0.0" || self.remote_addr == "::" || self.remote_addr == "*") {
            "*:*".to_string()
        } else if self.remote_addr.contains(':') && !self.remote_addr.starts_with('[') {
            format!("[{}]:{}", self.remote_addr, self.remote_port)
        } else {
            format!("{}:{}", self.remote_addr, self.remote_port)
        }
    }
}

/// Port filter supporting a single port or an inclusive range.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PortRange {
    pub start: u16,
    pub end: u16,
}

impl PortRange {
    pub fn contains(&self, port: u16) -> bool {
        port >= self.start && port <= self.end
    }
}

/// Filtering criteria shared across commands.
#[derive(Debug, Clone, Default)]
pub struct FilterOptions {
    pub tcp_only: bool,
    pub udp_only: bool,
    pub listen_only: bool,
    pub all_states: bool,
    pub port_ranges: Vec<PortRange>,
    pub process_filter: Option<String>,
}

impl FilterOptions {
    pub fn matches(&self, entry: &PortEntry) -> bool {
        if self.tcp_only && !entry.protocol.is_tcp() {
            return false;
        }
        if self.udp_only && !entry.protocol.is_udp() {
            return false;
        }
        if self.listen_only && !self.all_states {
            let is_udp_bound = entry.protocol.is_udp() && entry.local_port > 0;
            if !entry.state.is_listening() && !is_udp_bound {
                return false;
            }
        }
        if !self.port_ranges.is_empty()
            && !self.port_ranges.iter().any(|r| r.contains(entry.local_port))
        {
            return false;
        }
        if let Some(ref needle) = self.process_filter {
            let needle_lc = needle.to_ascii_lowercase();
            let name_match = entry
                .process_name
                .as_deref()
                .is_some_and(|n| n.to_ascii_lowercase().contains(&needle_lc));
            let cmd_match = entry
                .cmdline
                .as_deref()
                .is_some_and(|c| c.to_ascii_lowercase().contains(&needle_lc));
            if !name_match && !cmd_match {
                return false;
            }
        }
        true
    }
}

/// Result of actively probing a TCP port.
#[derive(Debug, Clone)]
pub struct ProbeResult {
    pub host: String,
    pub port: u16,
    pub open: bool,
    pub latency_ms: f64,
    pub service_hint: Option<&'static str>,
}

/// Parse a port specification like `"80"`, `"80,443,8080"`, or `"8000-8010"`.
pub fn parse_port_spec(spec: &str) -> Result<Vec<PortRange>, String> {
    let mut ranges = Vec::new();
    for part in spec.split(',') {
        let part = part.trim();
        if part.is_empty() {
            continue;
        }
        if let Some((start_s, end_s)) = part.split_once('-') {
            let start: u16 = start_s
                .trim()
                .parse()
                .map_err(|_| format!("Invalid start port: '{start_s}'"))?;
            let end: u16 = end_s
                .trim()
                .parse()
                .map_err(|_| format!("Invalid end port: '{end_s}'"))?;
            if start > end {
                return Err(format!("Port range start ({start}) is greater than end ({end})"));
            }
            ranges.push(PortRange { start, end });
        } else {
            let port: u16 = part
                .parse()
                .map_err(|_| format!("Invalid port number: '{part}'"))?;
            ranges.push(PortRange {
                start: port,
                end: port,
            });
        }
    }
    if ranges.is_empty() {
        return Err("No valid ports specified".to_string());
    }
    Ok(ranges)
}

/// Expand port ranges into a sorted, deduplicated list of ports (capped for safety).
pub fn expand_port_ranges(ranges: &[PortRange], max_ports: usize) -> Result<Vec<u16>, String> {
    let mut ports = Vec::new();
    for r in ranges {
        let count = (r.end as usize) - (r.start as usize) + 1;
        if ports.len() + count > max_ports {
            return Err(format!(
                "Port scan exceeds maximum limit of {max_ports} ports at once"
            ));
        }
        for p in r.start..=r.end {
            ports.push(p);
        }
    }
    ports.sort_unstable();
    ports.dedup();
    Ok(ports)
}

/// Return a well-known service name hint for common ports.
pub fn well_known_service(port: u16) -> Option<&'static str> {
    match port {
        21 => Some("FTP"),
        22 => Some("SSH"),
        23 => Some("Telnet"),
        25 => Some("SMTP"),
        53 => Some("DNS"),
        80 => Some("HTTP"),
        110 => Some("POP3"),
        143 => Some("IMAP"),
        443 => Some("HTTPS"),
        465 => Some("SMTPS"),
        587 => Some("SMTP"),
        993 => Some("IMAPS"),
        995 => Some("POP3S"),
        1433 => Some("MSSQL"),
        1521 => Some("Oracle"),
        3000 => Some("Dev/Node"),
        3306 => Some("MySQL"),
        3389 => Some("RDP"),
        5000 => Some("Dev/HTTP"),
        5173 => Some("Vite"),
        5432 => Some("PostgreSQL"),
        5672 => Some("RabbitMQ"),
        6379 => Some("Redis"),
        8000 => Some("HTTP-Alt"),
        8080 => Some("HTTP-Proxy"),
        8443 => Some("HTTPS-Alt"),
        9000 => Some("PHP-FPM/Sonar"),
        9090 => Some("Prometheus"),
        9200 => Some("Elasticsearch"),
        27017 => Some("MongoDB"),
        _ => None,
    }
}
