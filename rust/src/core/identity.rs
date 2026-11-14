//! Long-term device identity.
//!
//! On first start an Ed25519 key pair is generated and its 32-byte seed is
//! stored hex-encoded in `<storage_dir>/identity.key` (mode 0600 on Unix).
//! The device id is the first 8 bytes of SHA-256(public key) as 16 hex chars.
//! The key signs pairing transcripts so a device cannot claim another's id.

use std::fs;
use std::path::Path;

use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};

use crate::core::store::{write_private, StoreError};

const IDENTITY_FILE: &str = "identity.key";
const FINGERPRINT_BYTES: usize = 8;

/// The local device's key pair. Not `Debug`, so the key cannot leak into logs.
pub struct Identity {
    key: SigningKey,
    id: String,
}

impl Identity {
    /// Generates a fresh, unpersisted identity.
    pub fn generate() -> Self {
        Self::from_key(SigningKey::generate(&mut OsRng))
    }

    /// Loads the identity from `dir`, creating and persisting one if absent.
    ///
    /// An unreadable or corrupt key file is moved aside to `identity.key.bad`
    /// and replaced, since refusing to start would leave the app unusable.
    pub fn load_or_create(dir: &Path) -> Result<Self, StoreError> {
        let path = dir.join(IDENTITY_FILE);
        match fs::read_to_string(&path) {
            Ok(text) => {
                if let Some(identity) = parse_seed(&text).map(Self::from_seed) {
                    return Ok(identity);
                }
                log::warn!("identity key file is corrupt; generating a new identity");
                let backup = dir.join(format!("{IDENTITY_FILE}.bad"));
                fs::rename(&path, &backup).map_err(|e| StoreError::io(&path, e))?;
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(StoreError::io(&path, e)),
        }
        let identity = Self::generate();
        write_private(&path, hex::encode(identity.key.to_bytes()).as_bytes())?;
        Ok(identity)
    }

    fn from_seed(seed: [u8; 32]) -> Self {
        Self::from_key(SigningKey::from_bytes(&seed))
    }

    fn from_key(key: SigningKey) -> Self {
        let id = fingerprint(&key.verifying_key().to_bytes());
        Self { key, id }
    }

    pub fn id(&self) -> &str {
        &self.id
    }

    pub fn public_key(&self) -> [u8; 32] {
        self.key.verifying_key().to_bytes()
    }

    pub fn sign(&self, message: &[u8]) -> [u8; 64] {
        self.key.sign(message).to_bytes()
    }
}

fn parse_seed(text: &str) -> Option<[u8; 32]> {
    hex::decode(text.trim()).ok()?.try_into().ok()
}

/// Device id for a public key.
pub fn fingerprint(public_key: &[u8; 32]) -> String {
    let digest = Sha256::digest(public_key);
    hex::encode(&digest[..FINGERPRINT_BYTES])
}

/// Verifies an Ed25519 signature (strict verification, rejects weak keys).
pub fn verify(public_key: &[u8; 32], message: &[u8], signature: &[u8; 64]) -> bool {
    let Ok(key) = VerifyingKey::from_bytes(public_key) else {
        return false;
    };
    key.verify_strict(message, &Signature::from_bytes(signature))
        .is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn persists_and_reloads() {
        let dir = tempfile::tempdir().unwrap();
        let first = Identity::load_or_create(dir.path()).unwrap();
        let second = Identity::load_or_create(dir.path()).unwrap();
        assert_eq!(first.id(), second.id());
        assert_eq!(first.public_key(), second.public_key());
        assert_eq!(first.id().len(), FINGERPRINT_BYTES * 2);
    }

    #[test]
    fn replaces_corrupt_key() {
        let dir = tempfile::tempdir().unwrap();
        fs::write(dir.path().join(IDENTITY_FILE), "not hex").unwrap();
        let identity = Identity::load_or_create(dir.path()).unwrap();
        assert!(dir.path().join("identity.key.bad").exists());
        let again = Identity::load_or_create(dir.path()).unwrap();
        assert_eq!(identity.id(), again.id());
    }

    #[test]
    fn signatures_verify() {
        let identity = Identity::generate();
        let sig = identity.sign(b"transcript");
        assert!(verify(&identity.public_key(), b"transcript", &sig));
        assert!(!verify(&identity.public_key(), b"other", &sig));
        let other = Identity::generate();
        assert!(!verify(&other.public_key(), b"transcript", &sig));
    }
}
