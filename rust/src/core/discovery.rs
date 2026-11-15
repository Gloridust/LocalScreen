//! LAN discovery over mDNS / DNS-SD (`mdns-sd`, pure Rust).
//!
//! Each node registers `<device id>._localscreen._tcp.local.` on host
//! `<device id>.local.` with TXT keys `id`, `name`, `kind`, `platform` and
//! `v` (protocol version), and browses the same service type. Using the id as
//! the instance name keeps instance names unique and makes self-filtering
//! trivial. Advertising can be withdrawn while browsing continues.

use std::net::IpAddr;

use mdns_sd::{ResolvedService, ServiceDaemon, ServiceEvent, ServiceInfo};

use crate::api::types::DeviceKind;
use crate::core::peers::PeerRecord;
use crate::core::wire::{kind_from_str, kind_to_str, sanitize_name, truncate_utf8};
use crate::core::wire::{MAX_NAME_BYTES, MAX_PLATFORM_BYTES};
use crate::core::{PROTOCOL_VERSION, SERVICE_TYPE};

pub use mdns_sd::Receiver;

#[derive(Debug, thiserror::Error)]
#[error("mDNS: {0}")]
pub struct DiscoveryError(#[from] mdns_sd::Error);

/// What this node advertises.
#[derive(Debug, Clone)]
pub struct Advertisement {
    pub name: String,
    pub kind: DeviceKind,
    pub platform: String,
}

/// Running mDNS daemon with our browse subscription.
pub struct Discovery {
    daemon: ServiceDaemon,
    id: String,
    port: u16,
    fullname: Option<String>,
}

impl Discovery {
    /// Starts the daemon and begins browsing; returns the event stream.
    pub fn start(id: &str, port: u16) -> Result<(Self, Receiver<ServiceEvent>), DiscoveryError> {
        let daemon = ServiceDaemon::new()?;
        let events = daemon.browse(SERVICE_TYPE)?;
        Ok((
            Self {
                daemon,
                id: id.to_owned(),
                port,
                fullname: None,
            },
            events,
        ))
    }

    /// Registers (or re-registers with updated TXT) our service.
    pub fn advertise(&mut self, ad: &Advertisement) -> Result<(), DiscoveryError> {
        let name = truncate_utf8(&ad.name, MAX_NAME_BYTES).to_owned();
        let properties = [
            ("id", self.id.clone()),
            ("name", name),
            ("kind", kind_to_str(ad.kind).to_owned()),
            ("platform", ad.platform.clone()),
            ("v", PROTOCOL_VERSION.to_string()),
        ];
        let host = format!("{}.local.", self.id);
        let info = ServiceInfo::new(
            SERVICE_TYPE,
            &self.id,
            &host,
            (),
            self.port,
            &properties[..],
        )?
        .enable_addr_auto();
        let fullname = info.get_fullname().to_owned();
        self.daemon.register(info)?;
        self.fullname = Some(fullname);
        Ok(())
    }

    /// Stops advertising (sends goodbye packets); browsing continues.
    pub fn withdraw(&mut self) -> Result<(), DiscoveryError> {
        if let Some(fullname) = self.fullname.take() {
            // The status receiver is dropped: the result is only informative.
            self.daemon.unregister(&fullname)?;
        }
        Ok(())
    }

    /// Withdraws and stops the daemon thread.
    pub fn shutdown(mut self) {
        if let Err(e) = self.withdraw() {
            log::debug!("mDNS withdraw on shutdown failed: {e}");
        }
        if let Err(e) = self.daemon.shutdown() {
            log::debug!("mDNS shutdown failed: {e}");
        }
    }
}

/// Converts a resolved service into a peer, skipping ourselves, malformed
/// records and incompatible protocol versions.
pub fn parse_service(service: &ResolvedService, own_id: &str) -> Option<PeerRecord> {
    let id = service.get_property_val_str("id")?.trim();
    if id.is_empty() || id == own_id || id.len() > 64 {
        return None;
    }
    let version: u32 = service.get_property_val_str("v")?.trim().parse().ok()?;
    if version != PROTOCOL_VERSION {
        log::debug!("ignoring peer with protocol version {version}");
        return None;
    }
    let mut addresses: Vec<IpAddr> = service
        .get_addresses_v4()
        .into_iter()
        .map(IpAddr::V4)
        .collect();
    addresses.sort();
    if addresses.is_empty() || service.get_port() == 0 {
        return None;
    }
    let name = sanitize_name(service.get_property_val_str("name").unwrap_or_default());
    Some(PeerRecord {
        id: id.to_owned(),
        name: if name.is_empty() { id.to_owned() } else { name },
        kind: kind_from_str(service.get_property_val_str("kind").unwrap_or_default()),
        platform: truncate_utf8(
            service.get_property_val_str("platform").unwrap_or_default(),
            MAX_PLATFORM_BYTES,
        )
        .to_owned(),
        addresses,
        port: service.get_port(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn resolved(props: &[(&str, &str)]) -> ResolvedService {
        ServiceInfo::new(
            SERVICE_TYPE,
            "peer",
            "peer.local.",
            "192.168.1.7",
            4000,
            props,
        )
        .unwrap()
        .as_resolved_service()
    }

    #[test]
    fn parses_txt_records() {
        let service = resolved(&[
            ("id", "abcd"),
            ("name", "Mi Pad"),
            ("kind", "tablet"),
            ("platform", "android"),
            ("v", "1"),
        ]);
        let peer = parse_service(&service, "self").unwrap();
        assert_eq!(peer.id, "abcd");
        assert_eq!(peer.name, "Mi Pad");
        assert_eq!(peer.kind, DeviceKind::Tablet);
        assert_eq!(peer.platform, "android");
        assert_eq!(peer.port, 4000);
        assert_eq!(
            peer.addresses,
            vec!["192.168.1.7".parse::<IpAddr>().unwrap()]
        );
    }

    #[test]
    fn skips_self_and_incompatible() {
        let own = resolved(&[("id", "self"), ("v", "1")]);
        assert!(parse_service(&own, "self").is_none());
        let future = resolved(&[("id", "abcd"), ("v", "2")]);
        assert!(parse_service(&future, "self").is_none());
        let no_id = resolved(&[("v", "1")]);
        assert!(parse_service(&no_id, "self").is_none());
    }
}
