//! Table of peers currently visible to this node.
//!
//! A peer can be known through mDNS, through a manual probe, or both. It is
//! reported lost only when it was seen through mDNS alone and its service
//! disappears; manually added peers stay until the node stops.

use std::collections::HashMap;
use std::net::IpAddr;

use crate::api::types::{DeviceInfo, DeviceKind};

/// What is known about a visible peer (trust is looked up separately).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PeerRecord {
    pub id: String,
    pub name: String,
    pub kind: DeviceKind,
    pub platform: String,
    pub addresses: Vec<IpAddr>,
    pub port: u16,
}

impl PeerRecord {
    pub fn to_device_info(&self, trusted: bool) -> DeviceInfo {
        DeviceInfo {
            id: self.id.clone(),
            name: self.name.clone(),
            kind: self.kind,
            platform: self.platform.clone(),
            addresses: self.addresses.iter().map(IpAddr::to_string).collect(),
            port: self.port,
            trusted,
        }
    }
}

#[derive(Debug)]
struct Entry {
    record: PeerRecord,
    mdns_fullname: Option<String>,
    manual: bool,
}

#[derive(Debug, Default)]
pub struct PeerTable {
    entries: HashMap<String, Entry>,
}

impl PeerTable {
    /// Records an mDNS resolution; returns whether anything visible changed.
    pub fn upsert_discovered(&mut self, fullname: &str, record: PeerRecord) -> bool {
        match self.entries.get_mut(&record.id) {
            Some(entry) => {
                entry.mdns_fullname = Some(fullname.to_owned());
                let changed = entry.record != record;
                entry.record = record;
                changed
            }
            None => {
                self.entries.insert(
                    record.id.clone(),
                    Entry {
                        record,
                        mdns_fullname: Some(fullname.to_owned()),
                        manual: false,
                    },
                );
                true
            }
        }
    }

    /// Records a manual probe result; returns the merged record.
    pub fn upsert_manual(&mut self, record: PeerRecord) -> PeerRecord {
        let entry = self
            .entries
            .entry(record.id.clone())
            .or_insert_with(|| Entry {
                record: record.clone(),
                mdns_fullname: None,
                manual: true,
            });
        entry.manual = true;
        let mut addresses = record.addresses.clone();
        for addr in &entry.record.addresses {
            if !addresses.contains(addr) {
                addresses.push(*addr);
            }
        }
        entry.record = PeerRecord {
            addresses,
            ..record
        };
        entry.record.clone()
    }

    /// Handles an mDNS removal; returns the id if the peer is now gone.
    pub fn remove_discovered(&mut self, fullname: &str) -> Option<String> {
        let id = self
            .entries
            .iter()
            .find(|(_, e)| e.mdns_fullname.as_deref() == Some(fullname))
            .map(|(id, _)| id.clone())?;
        let entry = self.entries.get_mut(&id)?;
        if entry.manual {
            entry.mdns_fullname = None;
            return None;
        }
        self.entries.remove(&id);
        Some(id)
    }

    pub fn get(&self, id: &str) -> Option<&PeerRecord> {
        self.entries.get(id).map(|e| &e.record)
    }

    pub fn list(&self) -> Vec<PeerRecord> {
        let mut peers: Vec<PeerRecord> = self.entries.values().map(|e| e.record.clone()).collect();
        peers.sort_by(|a, b| a.name.cmp(&b.name).then_with(|| a.id.cmp(&b.id)));
        peers
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn record(id: &str, ip: &str) -> PeerRecord {
        PeerRecord {
            id: id.into(),
            name: "Pad".into(),
            kind: DeviceKind::Tablet,
            platform: "android".into(),
            addresses: vec![ip.parse().unwrap()],
            port: 53520,
        }
    }

    #[test]
    fn discovered_peers_come_and_go() {
        let mut table = PeerTable::default();
        assert!(table.upsert_discovered("a._x", record("a", "10.0.0.1")));
        assert!(!table.upsert_discovered("a._x", record("a", "10.0.0.1")));
        assert!(table.upsert_discovered("a._x", record("a", "10.0.0.2")));
        assert_eq!(table.remove_discovered("a._x").as_deref(), Some("a"));
        assert!(table.get("a").is_none());
        assert_eq!(table.remove_discovered("a._x"), None);
    }

    #[test]
    fn manual_peers_survive_mdns_removal() {
        let mut table = PeerTable::default();
        table.upsert_discovered("a._x", record("a", "10.0.0.1"));
        let merged = table.upsert_manual(record("a", "10.0.0.9"));
        assert_eq!(merged.addresses.len(), 2);
        assert_eq!(table.remove_discovered("a._x"), None);
        assert!(table.get("a").is_some());
    }
}
