use std::fmt;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr};

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

    pub fn is_ipv4(self) -> bool {
        matches!(self, Protocol::Tcp | Protocol::Udp)
    }

    pub fn is_ipv6(self) -> bool {
        matches!(self, Protocol::Tcp6 | Protocol::Udp6)
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Protocol::Tcp => "TCP",
            Protocol::Tcp6 => "TCP6",
            Protocol::Udp => "UDP",
            Protocol::Udp6 => "UDP6",
        }
    }

    pub fn from_str_loose(s: &str) -> Option<Self> {
        match s.to_ascii_uppercase().as_str() {
            "TCP" => Some(Protocol::Tcp),
            "TCP6" => Some(Protocol::Tcp6),
            "UDP" => Some(Protocol::Udp),
            "UDP6" => Some(Protocol::Udp6),
            _ => None,
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

/// Network exposure classification for a bound local address.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum BindScope {
    Loopback,
    Lan,
    AllInterfaces,
    Public,
    Unknown,
}

impl BindScope {
    pub fn classify(addr: &str) -> Self {
        let trimmed = addr.trim().trim_matches(|c| c == '[' || c == ']');
        if trimmed == "*" || trimmed == "0.0.0.0" || trimmed == "::" {
            return BindScope::AllInterfaces;
        }
        if trimmed.eq_ignore_ascii_case("localhost") {
            return BindScope::Loopback;
        }
        // Strip IPv6 zone identifier if present (e.g. fe80::1%en0)
        let clean = trimmed.split('%').next().unwrap_or(trimmed);
        match clean.parse::<IpAddr>() {
            Ok(IpAddr::V4(v4)) => classify_v4(v4),
            Ok(IpAddr::V6(v6)) => classify_v6(v6),
            Err(_) => BindScope::Unknown,
        }
    }

    pub fn is_exposed(self) -> bool {
        matches!(self, BindScope::AllInterfaces | BindScope::Public)
    }

    pub fn as_str(self) -> &'static str {
        match self {
            BindScope::Loopback => "LOCAL",
            BindScope::Lan => "LAN",
            BindScope::AllInterfaces => "ALL(*)",
            BindScope::Public => "PUBLIC",
            BindScope::Unknown => "UNKNOWN",
        }
    }
}

fn classify_v4(ip: Ipv4Addr) -> BindScope {
    if ip.is_unspecified() {
        BindScope::AllInterfaces
    } else if ip.is_loopback() {
        BindScope::Loopback
    } else if ip.is_private() || ip.is_link_local() {
        BindScope::Lan
    } else {
        BindScope::Public
    }
}

fn classify_v6(ip: Ipv6Addr) -> BindScope {
    if ip.is_unspecified() {
        BindScope::AllInterfaces
    } else if ip.is_loopback() {
        BindScope::Loopback
    } else if let Some(v4) = ip.to_ipv4_mapped() {
        classify_v4(v4)
    } else {
        let seg0 = ip.segments()[0];
        // fc00::/7 (Unique Local) or fe80::/10 (Link-Local)
        if (seg0 & 0xfe00) == 0xfc00 || (seg0 & 0xffc0) == 0xfe80 {
            BindScope::Lan
        } else {
            BindScope::Public
        }
    }
}

impl fmt::Display for BindScope {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// Output format for list and report commands.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum OutputFormat {
    #[default]
    Table,
    Json,
    Csv,
    Compact,
}

impl OutputFormat {
    pub fn parse(s: &str) -> Result<Self, String> {
        match s.to_ascii_lowercase().as_str() {
            "table" => Ok(OutputFormat::Table),
            "json" => Ok(OutputFormat::Json),
            "csv" => Ok(OutputFormat::Csv),
            "compact" | "short" => Ok(OutputFormat::Compact),
            other => Err(format!(
                "Invalid format '{other}'. Expected: table, json, csv, compact"
            )),
        }
    }
}

/// Sort key for port listings.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum SortField {
    #[default]
    Port,
    Pid,
    Process,
    State,
    Proto,
    Memory,
}

impl SortField {
    pub fn parse(s: &str) -> Result<Self, String> {
        match s.to_ascii_lowercase().as_str() {
            "port" => Ok(SortField::Port),
            "pid" => Ok(SortField::Pid),
            "proc" | "process" | "name" => Ok(SortField::Process),
            "state" => Ok(SortField::State),
            "proto" | "protocol" => Ok(SortField::Proto),
            "mem" | "memory" | "rss" => Ok(SortField::Memory),
            other => Err(format!(
                "Invalid sort field '{other}'. Expected: port, pid, process, state, proto, mem"
            )),
        }
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
    pub ppid: Option<u32>,
    pub user: Option<String>,
    pub process_name: Option<String>,
    pub cmdline: Option<String>,
    pub memory_kb: Option<u64>,
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

    /// Key used for baseline drift detection (protocol + port).
    pub fn service_slot_key(&self) -> (Protocol, u16) {
        (self.protocol, self.local_port)
    }

    pub fn bind_scope(&self) -> BindScope {
        BindScope::classify(&self.local_addr)
    }

    pub fn local_endpoint(&self) -> String {
        if self.local_addr.contains(':') && !self.local_addr.starts_with('[') {
            format!("[{}]:{}", self.local_addr, self.local_port)
        } else {
            format!("{}:{}", self.local_addr, self.local_port)
        }
    }

    pub fn remote_endpoint(&self) -> String {
        if self.remote_port == 0
            && (self.remote_addr == "0.0.0.0"
                || self.remote_addr == "::"
                || self.remote_addr == "*")
        {
            "*:*".to_string()
        } else if self.remote_addr.contains(':') && !self.remote_addr.starts_with('[') {
            format!("[{}]:{}", self.remote_addr, self.remote_port)
        } else {
            format!("{}:{}", self.remote_addr, self.remote_port)
        }
    }

    pub fn memory_human(&self) -> String {
        match self.memory_kb {
            Some(kb) if kb >= 1024 * 1024 => format!("{:.1}G", kb as f64 / (1024.0 * 1024.0)),
            Some(kb) if kb >= 1024 => format!("{:.1}M", kb as f64 / 1024.0),
            Some(kb) => format!("{kb}K"),
            None => "-".to_string(),
        }
    }

    /// Infer runtime/container tag from process name or command line.
    pub fn runtime_tag(&self) -> Option<&'static str> {
        let name = self
            .process_name
            .as_deref()
            .unwrap_or("")
            .to_ascii_lowercase();
        let cmd = self.cmdline.as_deref().unwrap_or("").to_ascii_lowercase();

        if name.contains("docker")
            || cmd.contains("docker-proxy")
            || name.contains("containerd")
            || name.contains("orbstack")
            || name.contains("colima")
            || name.contains("podman")
        {
            Some("container")
        } else if name == "node" || name == "bun" || name == "deno" || cmd.contains("node ") {
            Some("js/ts")
        } else if name.starts_with("python") || name == "uvicorn" || name == "gunicorn" {
            Some("python")
        } else if name == "java" || name.contains("gradle") {
            Some("jvm")
        } else if name == "postgres"
            || name == "mysqld"
            || name == "mariadbd"
            || name == "redis-server"
            || name == "mongod"
        {
            Some("database")
        } else if name == "nginx"
            || name == "httpd"
            || name == "caddy"
            || name == "haproxy"
            || name == "envoy"
        {
            Some("proxy/web")
        } else {
            None
        }
    }
}

/// Process ancestry node for deep inspection.
#[derive(Debug, Clone)]
pub struct ProcessAncestor {
    pub pid: u32,
    pub ppid: Option<u32>,
    pub user: Option<String>,
    pub name: String,
    pub memory_kb: Option<u64>,
    pub cmdline: Option<String>,
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

/// Filtering & sorting criteria shared across commands.
#[derive(Debug, Clone, Default)]
pub struct FilterOptions {
    pub tcp_only: bool,
    pub udp_only: bool,
    pub ipv4_only: bool,
    pub ipv6_only: bool,
    pub listen_only: bool,
    pub all_states: bool,
    pub exposed_only: bool,
    pub state_filter: Option<SocketState>,
    pub user_filter: Option<String>,
    pub port_ranges: Vec<PortRange>,
    pub process_filter: Option<String>,
    pub sort_by: SortField,
    pub descending: bool,
}

impl FilterOptions {
    pub fn matches(&self, entry: &PortEntry) -> bool {
        if self.tcp_only && !entry.protocol.is_tcp() {
            return false;
        }
        if self.udp_only && !entry.protocol.is_udp() {
            return false;
        }
        if self.ipv4_only && !entry.protocol.is_ipv4() {
            return false;
        }
        if self.ipv6_only && !entry.protocol.is_ipv6() {
            return false;
        }
        if let Some(ref target_state) = self.state_filter {
            if &entry.state != target_state {
                return false;
            }
        } else if self.listen_only && !self.all_states {
            let is_udp_bound = entry.protocol.is_udp() && entry.local_port > 0;
            if !entry.state.is_listening() && !is_udp_bound {
                return false;
            }
        }
        if self.exposed_only && !entry.bind_scope().is_exposed() {
            return false;
        }
        if !self.port_ranges.is_empty()
            && !self.port_ranges.iter().any(|r| r.contains(entry.local_port))
        {
            return false;
        }
        if let Some(ref user_needle) = self.user_filter {
            let needle_lc = user_needle.to_ascii_lowercase();
            let matched = entry
                .user
                .as_deref()
                .is_some_and(|u| u.to_ascii_lowercase().contains(&needle_lc));
            if !matched {
                return false;
            }
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

    pub fn sort_entries(&self, entries: &mut [PortEntry]) {
        entries.sort_by(|a, b| {
            let ord = match self.sort_by {
                SortField::Port => a
                    .local_port
                    .cmp(&b.local_port)
                    .then_with(|| a.protocol.cmp(&b.protocol)),
                SortField::Pid => a
                    .pid
                    .unwrap_or(u32::MAX)
                    .cmp(&b.pid.unwrap_or(u32::MAX))
                    .then_with(|| a.local_port.cmp(&b.local_port)),
                SortField::Process => a
                    .process_name
                    .as_deref()
                    .unwrap_or("~")
                    .to_ascii_lowercase()
                    .cmp(
                        &b.process_name
                            .as_deref()
                            .unwrap_or("~")
                            .to_ascii_lowercase(),
                    )
                    .then_with(|| a.local_port.cmp(&b.local_port)),
                SortField::State => a
                    .state
                    .cmp(&b.state)
                    .then_with(|| a.local_port.cmp(&b.local_port)),
                SortField::Proto => a
                    .protocol
                    .cmp(&b.protocol)
                    .then_with(|| a.local_port.cmp(&b.local_port)),
                SortField::Memory => a
                    .memory_kb
                    .unwrap_or(0)
                    .cmp(&b.memory_kb.unwrap_or(0))
                    .then_with(|| a.local_port.cmp(&b.local_port)),
            };
            if self.descending { ord.reverse() } else { ord }
        });
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
    pub banner: Option<String>,
    pub detected_protocol: Option<String>,
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
                return Err(format!(
                    "Port range start ({start}) is greater than end ({end})"
                ));
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
        20 => Some("FTP-Data"),
        21 => Some("FTP"),
        22 => Some("SSH"),
        23 => Some("Telnet"),
        25 => Some("SMTP"),
        53 => Some("DNS"),
        67 | 68 => Some("DHCP"),
        80 => Some("HTTP"),
        110 => Some("POP3"),
        123 => Some("NTP"),
        135 => Some("MSRPC"),
        139 => Some("NetBIOS"),
        143 => Some("IMAP"),
        161 => Some("SNMP"),
        389 => Some("LDAP"),
        443 => Some("HTTPS"),
        445 => Some("SMB"),
        465 => Some("SMTPS"),
        514 => Some("Syslog"),
        587 => Some("SMTP"),
        631 => Some("IPP/CUPS"),
        636 => Some("LDAPS"),
        873 => Some("Rsync"),
        993 => Some("IMAPS"),
        995 => Some("POP3S"),
        1080 => Some("SOCKS"),
        1433 => Some("MSSQL"),
        1521 => Some("Oracle"),
        2049 => Some("NFS"),
        2181 => Some("ZooKeeper"),
        2375 => Some("Docker-TCP"),
        2376 => Some("Docker-TLS"),
        2379 => Some("etcd"),
        3000 => Some("Dev/Node"),
        3001 => Some("Dev/HTTP"),
        3306 => Some("MySQL"),
        3389 => Some("RDP"),
        4000 => Some("Dev/GraphQL"),
        4200 => Some("Angular"),
        4222 => Some("NATS"),
        4317 => Some("OTLP-gRPC"),
        4318 => Some("OTLP-HTTP"),
        5000 => Some("Dev/HTTP"),
        5173 => Some("Vite"),
        5353 => Some("mDNS"),
        5432 => Some("PostgreSQL"),
        5601 => Some("Kibana"),
        5672 => Some("RabbitMQ"),
        5900 => Some("VNC"),
        6379 => Some("Redis"),
        6443 => Some("K8s-API"),
        7000 => Some("AirPlay/Dev"),
        7474 => Some("Neo4j"),
        8000 => Some("HTTP-Alt"),
        8080 => Some("HTTP-Proxy"),
        8081 => Some("HTTP-Alt2"),
        8443 => Some("HTTPS-Alt"),
        8888 => Some("Jupyter"),
        9000 => Some("PHP-FPM/MinIO"),
        9042 => Some("Cassandra"),
        9090 => Some("Prometheus"),
        9092 => Some("Kafka"),
        9200 => Some("Elasticsearch"),
        9418 => Some("Git"),
        11211 => Some("Memcached"),
        15672 => Some("RabbitMQ-UI"),
        27017 => Some("MongoDB"),
        _ => None,
    }
}
