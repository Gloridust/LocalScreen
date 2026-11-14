//! Authenticated encryption of control frames once the handshake is done.
//!
//! Each direction has its own ChaCha20-Poly1305 key, so a frame can never be
//! reflected back to its sender. An encrypted frame payload is
//!
//! ```text
//! counter: u64 big-endian | ciphertext || 16-byte Poly1305 tag
//! ```
//!
//! The nonce is `0u32 || counter` and the counter is also bound as AAD. The
//! receiver accepts exactly the next expected counter, which rejects
//! replayed, dropped and reordered frames (TCP already delivers in order, so
//! any deviation means tampering).

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};

use crate::api::types::SessionRole;

pub const KEY_LEN: usize = 32;
const COUNTER_LEN: usize = 8;
const TAG_LEN: usize = 16;

/// Bytes an encrypted frame adds on top of its plaintext.
pub const OVERHEAD: usize = COUNTER_LEN + TAG_LEN;

#[derive(Debug, PartialEq, Eq, thiserror::Error)]
pub enum ChannelError {
    #[error("encrypted frame is too short")]
    Truncated,
    #[error("frame counter {got} is not the expected {expected} (replayed or reordered)")]
    Sequence { expected: u64, got: u64 },
    #[error("frame failed authentication")]
    Authentication,
    #[error("frame counter space exhausted")]
    Exhausted,
}

/// Directional keys of one session. Not `Debug` on purpose.
pub struct SessionKeys {
    host_to_display: [u8; KEY_LEN],
    display_to_host: [u8; KEY_LEN],
}

impl SessionKeys {
    pub fn new(host_to_display: [u8; KEY_LEN], display_to_host: [u8; KEY_LEN]) -> Self {
        Self {
            host_to_display,
            display_to_host,
        }
    }

    /// Splits into the sealer/opener pair used by `role`.
    pub fn into_channel(self, role: SessionRole) -> (Sealer, Opener) {
        let (send, recv) = match role {
            SessionRole::Host => (self.host_to_display, self.display_to_host),
            SessionRole::Display => (self.display_to_host, self.host_to_display),
        };
        (Sealer::new(&send), Opener::new(&recv))
    }
}

fn nonce_for(counter: u64) -> Nonce {
    let mut nonce = [0u8; 12];
    nonce[4..].copy_from_slice(&counter.to_be_bytes());
    Nonce::from(nonce)
}

/// Encrypts outgoing frames.
pub struct Sealer {
    cipher: ChaCha20Poly1305,
    next: u64,
}

impl Sealer {
    fn new(key: &[u8; KEY_LEN]) -> Self {
        Self {
            cipher: ChaCha20Poly1305::new(Key::from_slice(key)),
            next: 0,
        }
    }

    pub fn seal(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, ChannelError> {
        let counter = self.next;
        self.next = counter.checked_add(1).ok_or(ChannelError::Exhausted)?;
        let counter_bytes = counter.to_be_bytes();
        let ciphertext = self
            .cipher
            .encrypt(
                &nonce_for(counter),
                Payload {
                    msg: plaintext,
                    aad: &counter_bytes,
                },
            )
            .map_err(|_| ChannelError::Authentication)?;
        let mut out = Vec::with_capacity(COUNTER_LEN + ciphertext.len());
        out.extend_from_slice(&counter_bytes);
        out.extend_from_slice(&ciphertext);
        Ok(out)
    }
}

/// Decrypts and sequence-checks incoming frames.
pub struct Opener {
    cipher: ChaCha20Poly1305,
    next: u64,
}

impl Opener {
    fn new(key: &[u8; KEY_LEN]) -> Self {
        Self {
            cipher: ChaCha20Poly1305::new(Key::from_slice(key)),
            next: 0,
        }
    }

    pub fn open(&mut self, frame: &[u8]) -> Result<Vec<u8>, ChannelError> {
        if frame.len() < OVERHEAD {
            return Err(ChannelError::Truncated);
        }
        let (counter_bytes, ciphertext) = frame.split_at(COUNTER_LEN);
        let mut raw = [0u8; COUNTER_LEN];
        raw.copy_from_slice(counter_bytes);
        let counter = u64::from_be_bytes(raw);
        if counter != self.next {
            return Err(ChannelError::Sequence {
                expected: self.next,
                got: counter,
            });
        }
        let plaintext = self
            .cipher
            .decrypt(
                &nonce_for(counter),
                Payload {
                    msg: ciphertext,
                    aad: counter_bytes,
                },
            )
            .map_err(|_| ChannelError::Authentication)?;
        self.next = counter.checked_add(1).ok_or(ChannelError::Exhausted)?;
        Ok(plaintext)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pair() -> ((Sealer, Opener), (Sealer, Opener)) {
        let host = SessionKeys::new([1; 32], [2; 32]).into_channel(SessionRole::Host);
        let display = SessionKeys::new([1; 32], [2; 32]).into_channel(SessionRole::Display);
        (host, display)
    }

    #[test]
    fn round_trips_both_directions() {
        let ((mut h_seal, mut h_open), (mut d_seal, mut d_open)) = pair();
        for i in 0..3u8 {
            let frame = h_seal.seal(&[i; 10]).unwrap();
            assert_eq!(frame.len(), 10 + OVERHEAD);
            assert_eq!(d_open.open(&frame).unwrap(), vec![i; 10]);
        }
        let frame = d_seal.seal(b"back").unwrap();
        assert_eq!(h_open.open(&frame).unwrap(), b"back");
    }

    #[test]
    fn rejects_replay() {
        let ((mut h_seal, _), (_, mut d_open)) = pair();
        let frame = h_seal.seal(b"once").unwrap();
        d_open.open(&frame).unwrap();
        assert_eq!(
            d_open.open(&frame),
            Err(ChannelError::Sequence {
                expected: 1,
                got: 0
            })
        );
    }

    #[test]
    fn rejects_reordering() {
        let ((mut h_seal, _), (_, mut d_open)) = pair();
        let first = h_seal.seal(b"1").unwrap();
        let second = h_seal.seal(b"2").unwrap();
        assert!(matches!(
            d_open.open(&second),
            Err(ChannelError::Sequence { .. })
        ));
        assert_eq!(d_open.open(&first).unwrap(), b"1");
        assert_eq!(d_open.open(&second).unwrap(), b"2");
    }

    #[test]
    fn rejects_tampering() {
        let ((mut h_seal, _), (_, mut d_open)) = pair();
        let mut frame = h_seal.seal(b"signal").unwrap();
        let last = frame.len() - 1;
        frame[last] ^= 0x01;
        assert_eq!(d_open.open(&frame), Err(ChannelError::Authentication));
    }

    #[test]
    fn rejects_forged_counter() {
        let ((mut h_seal, _), (_, mut d_open)) = pair();
        let _skipped = h_seal.seal(b"0").unwrap();
        let mut frame = h_seal.seal(b"1").unwrap();
        // Rewrite counter 1 -> 0: sequence check passes but AAD/nonce no longer match.
        frame[..COUNTER_LEN].copy_from_slice(&0u64.to_be_bytes());
        assert_eq!(d_open.open(&frame), Err(ChannelError::Authentication));
    }

    #[test]
    fn rejects_reflection() {
        let ((mut h_seal, mut h_open), _) = pair();
        let frame = h_seal.seal(b"mine").unwrap();
        assert_eq!(h_open.open(&frame), Err(ChannelError::Authentication));
    }

    #[test]
    fn rejects_truncated() {
        let (_, (_, mut d_open)) = pair();
        assert_eq!(d_open.open(&[0u8; 5]), Err(ChannelError::Truncated));
    }
}
