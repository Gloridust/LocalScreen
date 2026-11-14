//! LAN address helpers.

use std::net::{IpAddr, Ipv4Addr, SocketAddr};

use crate::core::NodeError;

/// Non-loopback IPv4 addresses of this machine, private ranges first.
pub fn lan_ipv4_addresses() -> Vec<Ipv4Addr> {
    let mut addrs: Vec<Ipv4Addr> = match if_addrs::get_if_addrs() {
        Ok(interfaces) => interfaces
            .into_iter()
            .filter_map(|i| match i.ip() {
                IpAddr::V4(v4) if !v4.is_loopback() && !v4.is_unspecified() => Some(v4),
                _ => None,
            })
            .collect(),
        Err(e) => {
            log::warn!("cannot enumerate network interfaces: {e}");
            Vec::new()
        }
    };
    addrs.sort_by_key(|a| (!a.is_private(), a.is_link_local(), *a));
    addrs.dedup();
    addrs
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
    fn lan_addresses_exclude_loopback() {
        assert!(lan_ipv4_addresses().iter().all(|a| !a.is_loopback()));
    }
}
