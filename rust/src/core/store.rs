//! Persistent store of trusted devices.
//!
//! Stored as JSON in `<storage_dir>/trusted.json`, rewritten atomically
//! (temp file + rename) and restricted to the owner on Unix. Each entry keeps
//! the peer's public key, so a trust secret is only ever used with the exact
//! key it was paired with, plus the 32-byte trust secret derived during PIN
//! pairing.
//!
//! The secret is stored in plaintext inside the app's private storage
//! directory; OS keychain integration is out of scope for now.

use std::collections::BTreeMap;
use std::fmt;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::core::wire::hex_bytes;

const STORE_FILE: &str = "trusted.json";

#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    #[error("cannot access {path}: {source}")]
    Io { path: PathBuf, source: io::Error },
    #[error("cannot encode the trusted store: {0}")]
    Encode(#[from] serde_json::Error),
}

impl StoreError {
    pub(crate) fn io(path: &Path, source: io::Error) -> Self {
        Self::Io {
            path: path.to_owned(),
            source,
        }
    }
}

/// A device paired with a PIN in the past.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TrustedDevice {
    pub id: String,
    #[serde(with = "hex_bytes")]
    pub public_key: [u8; 32],
    #[serde(with = "hex_bytes")]
    pub secret: [u8; 32],
    pub name: String,
    pub kind: String,
    pub platform: String,
    /// Last addresses the device was reached at.
    pub addresses: Vec<String>,
    pub port: u16,
    /// Unix time (seconds) of the last successful PIN pairing.
    pub paired_at: u64,
}

impl fmt::Debug for TrustedDevice {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TrustedDevice")
            .field("id", &self.id)
            .field("name", &self.name)
            .field("secret", &"<redacted>")
            .finish_non_exhaustive()
    }
}

#[derive(Default, Serialize, Deserialize)]
struct StoreFile {
    devices: Vec<TrustedDevice>,
}

/// In-memory view of `trusted.json`; every mutation is written through.
#[derive(Debug)]
pub struct TrustStore {
    path: PathBuf,
    devices: BTreeMap<String, TrustedDevice>,
}

impl TrustStore {
    /// Opens the store in `dir`. A corrupt file is moved aside and the store
    /// starts empty (the affected devices simply need a PIN again).
    pub fn open(dir: &Path) -> Result<Self, StoreError> {
        let path = dir.join(STORE_FILE);
        let devices = match fs::read(&path) {
            Ok(bytes) => match serde_json::from_slice::<StoreFile>(&bytes) {
                Ok(file) => file.devices,
                Err(_) => {
                    log::warn!("trusted store is corrupt; starting with an empty store");
                    let backup = dir.join(format!("{STORE_FILE}.bad"));
                    fs::rename(&path, &backup).map_err(|e| StoreError::io(&path, e))?;
                    Vec::new()
                }
            },
            Err(e) if e.kind() == io::ErrorKind::NotFound => Vec::new(),
            Err(e) => return Err(StoreError::io(&path, e)),
        };
        Ok(Self {
            path,
            devices: devices.into_iter().map(|d| (d.id.clone(), d)).collect(),
        })
    }

    pub fn get(&self, id: &str) -> Option<&TrustedDevice> {
        self.devices.get(id)
    }

    pub fn contains(&self, id: &str) -> bool {
        self.devices.contains_key(id)
    }

    /// The trust secret for `id`, only if it was paired with `public_key`.
    pub fn secret_for(&self, id: &str, public_key: &[u8; 32]) -> Option<[u8; 32]> {
        self.devices
            .get(id)
            .filter(|d| &d.public_key == public_key)
            .map(|d| d.secret)
    }

    pub fn list(&self) -> Vec<TrustedDevice> {
        self.devices.values().cloned().collect()
    }

    /// Inserts or replaces a device and persists the store.
    pub fn upsert(&mut self, device: TrustedDevice) -> Result<(), StoreError> {
        self.devices.insert(device.id.clone(), device);
        self.save()
    }

    /// Updates the cached name/addresses of a device; persists only on change.
    pub fn refresh(
        &mut self,
        id: &str,
        name: &str,
        addresses: Vec<String>,
        port: u16,
    ) -> Result<(), StoreError> {
        let Some(device) = self.devices.get_mut(id) else {
            return Ok(());
        };
        if device.name == name && device.addresses == addresses && device.port == port {
            return Ok(());
        }
        device.name = name.to_owned();
        device.addresses = addresses;
        device.port = port;
        self.save()
    }

    /// Removes a device; returns whether it was present.
    pub fn remove(&mut self, id: &str) -> Result<bool, StoreError> {
        if self.devices.remove(id).is_none() {
            return Ok(false);
        }
        self.save()?;
        Ok(true)
    }

    fn save(&self) -> Result<(), StoreError> {
        let file = StoreFile {
            devices: self.devices.values().cloned().collect(),
        };
        write_private(&self.path, &serde_json::to_vec_pretty(&file)?)
    }
}

/// Atomically replaces `path` with `contents`, readable only by the owner.
pub(crate) fn write_private(path: &Path, contents: &[u8]) -> Result<(), StoreError> {
    let tmp = path.with_extension("tmp");
    write_restricted(&tmp, contents).map_err(|e| StoreError::io(&tmp, e))?;
    fs::rename(&tmp, path).map_err(|e| StoreError::io(path, e))
}

#[cfg(unix)]
fn write_restricted(path: &Path, contents: &[u8]) -> io::Result<()> {
    use std::io::Write;
    use std::os::unix::fs::OpenOptionsExt;
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(path)?;
    file.write_all(contents)?;
    file.sync_all()
}

#[cfg(not(unix))]
fn write_restricted(path: &Path, contents: &[u8]) -> io::Result<()> {
    use std::io::Write;
    let mut file = fs::File::create(path)?;
    file.write_all(contents)?;
    file.sync_all()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn device(id: &str) -> TrustedDevice {
        TrustedDevice {
            id: id.into(),
            public_key: [1; 32],
            secret: [2; 32],
            name: "Pad".into(),
            kind: "tablet".into(),
            platform: "android".into(),
            addresses: vec!["192.168.1.5".into()],
            port: 53520,
            paired_at: 1,
        }
    }

    #[test]
    fn persists_across_reopen() {
        let dir = tempfile::tempdir().unwrap();
        let mut store = TrustStore::open(dir.path()).unwrap();
        store.upsert(device("a")).unwrap();
        store.upsert(device("b")).unwrap();
        assert!(store.remove("b").unwrap());
        assert!(!store.remove("b").unwrap());

        let reopened = TrustStore::open(dir.path()).unwrap();
        assert_eq!(reopened.list(), vec![device("a")]);
        assert!(reopened.contains("a"));
    }

    #[test]
    fn secret_requires_matching_key() {
        let dir = tempfile::tempdir().unwrap();
        let mut store = TrustStore::open(dir.path()).unwrap();
        store.upsert(device("a")).unwrap();
        assert_eq!(store.secret_for("a", &[1; 32]), Some([2; 32]));
        assert_eq!(store.secret_for("a", &[9; 32]), None);
        assert_eq!(store.secret_for("missing", &[1; 32]), None);
    }

    #[test]
    fn refresh_updates_metadata() {
        let dir = tempfile::tempdir().unwrap();
        let mut store = TrustStore::open(dir.path()).unwrap();
        store.upsert(device("a")).unwrap();
        store
            .refresh("a", "Renamed", vec!["10.0.0.2".into()], 1234)
            .unwrap();
        let reopened = TrustStore::open(dir.path()).unwrap();
        let entry = reopened.get("a").unwrap();
        assert_eq!(entry.name, "Renamed");
        assert_eq!(entry.port, 1234);
        assert_eq!(entry.secret, [2; 32]);
    }

    #[test]
    fn corrupt_file_starts_empty() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join(STORE_FILE), b"{oops").unwrap();
        let store = TrustStore::open(dir.path()).unwrap();
        assert!(store.list().is_empty());
        assert!(dir.path().join("trusted.json.bad").exists());
    }

    #[test]
    fn debug_redacts_secret() {
        let text = format!("{:?}", device("a"));
        assert!(text.contains("redacted"));
        assert!(!text.contains("[2, 2"));
    }
}
