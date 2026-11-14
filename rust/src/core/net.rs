//! LAN address helpers.

use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use crate::core::NodeError;

/// Interface-name prefixes of virtual adapters (containers, VMs, VPNs).
///
/// Their addresses are valid but rarely the one a nearby device can reach, so
/// they are listed after physical interfaces.
const VIRTUAL_INTERFACE_PREFIXES: &[&str] = &[
    "docker",
    "br-",
    "veth",
    "virbr",
    "vmnet",
    "vboxnet",
    "vethernet",
    "tun",
    "tap",
    "utun",
    "tailscale",
    "zt",
    "wg",
];

fn is_virtual_interface(name: &str) -> bool {
    let name = name.to_ascii_lowercase();
    VIRTUAL_INTERFACE_PREFIXES
        .iter()
        .any(|prefix| name.starts_with(prefix))
}

/// The local address of the default route, found without sending a packet:
/// connecting a UDP socket only selects the outgoing interface.
fn default_route_ipv4() -> Option<Ipv4Addr> {
    let socket = std::net::UdpSocket::bind((Ipv4Addr::UNSPECIFIED, 0)).ok()?;
    socket.connect((Ipv4Addr::new(192, 0, 2, 1), 9)).ok()?;
    match socket.local_addr().ok()?.ip() {
        IpAddr::V4(v4) if !v4.is_loopback() && !v4.is_unspecified() => Some(v4),
        _ => None,
    }
}

/// Orders `(interface name, address)` pairs so the address a LAN peer is most
/// likely to reach comes first: the default route, then physical private
/// addresses, then virtual adapters.
fn rank_addresses(interfaces: Vec<(String, Ipv4Addr)>, default: Option<Ipv4Addr>) -> Vec<Ipv4Addr> {
    let mut ranked: Vec<(String, Ipv4Addr)> = interfaces
        .into_iter()
        .filter(|(_, a)| !a.is_loopback() && !a.is_unspecified())
        .collect();
    ranked.sort_by_key(|(name, a)| {
        (
            Some(*a) != default,
            is_virtual_interface(name),
            !a.is_private(),
            a.is_link_local(),
            *a,
        )
    });
    let mut addrs: Vec<Ipv4Addr> = ranked.into_iter().map(|(_, a)| a).collect();
    addrs.dedup();
    addrs
}

/// Non-loopback IPv4 addresses of this machine, most reachable first.
pub fn lan_ipv4_addresses() -> Vec<Ipv4Addr> {
    let interfaces = match if_addrs::get_if_addrs() {
        Ok(interfaces) => interfaces
            .into_iter()
            .filter_map(|i| match i.ip() {
                IpAddr::V4(v4) => Some((i.name, v4)),
                IpAddr::V6(_) => None,
            })
            .collect(),
        Err(e) => {
            log::warn!("cannot enumerate network interfaces: {e}");
            Vec::new()
        }
    };
    rank_addresses(interfaces, default_route_ipv4())
}

/// Splits `host`, `host:port`, `ip`, `ip:port`, `[v6]` or `[v6]:port`.
pub fn parse_host_port(address: &str, default_port: u16) -> Result<(String, u16), NodeError> {
    let address = address.trim();
    let invalid = || NodeError::InvalidAddress(address.to_owned());
    if address.is_empty() {
        return Err(invalid());
    }
    if let Ok(socket) = address.parse::<SocketAddr>() {
        return Ok((socket.ip().to_string(), socket.port()));
    }
    if let Ok(ip) = address.parse::<IpAddr>() {
        return Ok((ip.to_string(), default_port));
    }
    if let Some(inner) = address.strip_prefix('[').and_then(|s| s.strip_suffix(']')) {
        let ip: IpAddr = inner.parse().map_err(|_| invalid())?;
        return Ok((ip.to_string(), default_port));
    }
    let (host, port) = match address.rsplit_once(':') {
        Some((host, port)) => (host, port.parse::<u16>().map_err(|_| invalid())?),
        None => (address, default_port),
    };
    let valid_host = !host.is_empty()
        && host
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '.');
    if !valid_host || port == 0 {
        return Err(invalid());
    }
    Ok((host.to_owned(), port))
}

/// Resolves a user-entered address; IPv4 results come first.
pub async fn resolve(address: &str, default_port: u16) -> Result<Vec<SocketAddr>, NodeError> {
    let (host, port) = parse_host_port(address, default_port)?;
    let mut addrs: Vec<SocketAddr> = tokio::net::lookup_host((host.as_str(), port))
        .await
        .map_err(|_| NodeError::Unreachable(address.trim().to_owned()))?
        .collect();
    addrs.sort_by_key(|a| a.is_ipv6());
    addrs.dedup();
    if addrs.is_empty() {
        return Err(NodeError::Unreachable(address.trim().to_owned()));
    }
    Ok(addrs)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_addresses() {
        let p = |s| parse_host_port(s, 53520).ok();
        assert_eq!(p("192.168.1.2"), Some(("192.168.1.2".into(), 53520)));
        assert_eq!(p(" 192.168.1.2:4000 "), Some(("192.168.1.2".into(), 4000)));
        assert_eq!(p("pad.local"), Some(("pad.local".into(), 53520)));
        assert_eq!(p("pad.local:81"), Some(("pad.local".into(), 81)));
        assert_eq!(p("::1"), Some(("::1".into(), 53520)));
        assert_eq!(p("[::1]"), Some(("::1".into(), 53520)));
        assert_eq!(p("[::1]:9"), Some(("::1".into(), 9)));
        assert_eq!(p(""), None);
        assert_eq!(p("host:notaport"), None);
        assert_eq!(p("host:0"), None);
        assert_eq!(p("bad host"), None);
        assert_eq!(p(":80"), None);
    }

    #[tokio::test]
    async fn resolves_loopback() {
        let addrs = resolve("127.0.0.1:1234", 53520).await.unwrap();
        assert_eq!(addrs, vec!["127.0.0.1:1234".parse().unwrap()]);
    }

    #[test]
    fn physical_addresses_rank_before_virtual_adapters() {
        let ip = |s: &str| s.parse::<Ipv4Addr>().unwrap();
        let interfaces = vec![
            ("lo".to_owned(), ip("127.0.0.1")),
            ("docker0".to_owned(), ip("172.17.0.1")),
            ("virbr0".to_owned(), ip("192.168.122.1")),
            ("wlp4s0".to_owned(), ip("192.168.1.156")),
            ("eth1".to_owned(), ip("10.0.0.7")),
        ];
        assert_eq!(
            rank_addresses(interfaces.clone(), Some(ip("192.168.1.156"))),
            vec![
                ip("192.168.1.156"),
                ip("10.0.0.7"),
                ip("172.17.0.1"),
                ip("192.168.122.1"),
            ]
        );
        // Without a default route, physical interfaces still come first.
        assert_eq!(
            rank_addresses(interfaces, None)[..2],
            [ip("10.0.0.7"), ip("192.168.1.156")]
        );
    }

    #[test]
    fn lan_addresses_exclude_loopback() {
        assert!(lan_ipv4_addresses().iter().all(|a| !a.is_loopback()));
    }
}
