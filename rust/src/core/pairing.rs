//! Pairing cryptography: PINs, SPAKE2 with key confirmation, and the
//! challenge-response used between already trusted devices.
//!
//! Everything here is pure (no I/O) so it can be tested directly; the
//! message flow that drives it lives in [`crate::core::session`].
//!
//! # Transcript
//! Both sides hash the raw `Hello`, `Welcome` and `SessionRequest` frames into
//! a [`Transcript`]. Every derived key, MAC and signature is bound to that
//! hash, so tampering with any handshake field breaks authentication.
//!
//! # PIN pairing (one attempt)
//! A fresh SPAKE2 (Ed25519 group) exchange runs per PIN guess, with
//! `id_a = host id`, `id_b = display id`. With `K` the SPAKE2 key and
//! `A = SHA-256(label || T || msg_a || msg_b)`:
//! `HKDF-SHA256(salt = A, ikm = K)` → host confirm key, display confirm key,
//! host→display key, display→host key, long-term trust secret.
//! The host proves knowledge first (`PinConfirm`); only if that verifies does
//! the display reveal its own confirmation (`PinAccepted`). Each side also
//! signs `label || A` with its identity key.
//!
//! # Trusted reconnect
//! The host sends nonce `n_h`, the display answers with nonce `n_d` and
//! `HMAC(secret, "display" || T || n_h || n_d)`, the host answers with the
//! same over `"host"`. Session keys are
//! `HKDF-SHA256(salt = T, ikm = secret, info = label || n_h || n_d)`.

use hkdf::Hkdf;
use hmac::{Hmac, Mac};
use rand::rngs::OsRng;
use rand::{Rng, RngCore};
use sha2::{Digest, Sha256};
use spake2::{Ed25519Group, Identity as SpakeIdentity, Password, Spake2};

use crate::api::types::SessionRole;
use crate::core::channel::{SessionKeys, KEY_LEN};

/// Number of digits in a pairing PIN.
pub const PIN_DIGITS: usize = 6;
/// Wrong guesses allowed per PIN.
pub const MAX_PIN_ATTEMPTS: u8 = 5;

const TRANSCRIPT_LABEL: &[u8] = b"localscreen/v1 transcript";
const ATTEMPT_LABEL: &[u8] = b"localscreen/v1 pin attempt";
const PIN_KEYS_INFO: &[u8] = b"localscreen/v1 pin keys";
const CONFIRM_HOST: &[u8] = b"localscreen/v1 confirm host";
const CONFIRM_DISPLAY: &[u8] = b"localscreen/v1 confirm display";
const SIGN_HOST: &[u8] = b"localscreen/v1 sign host";
const SIGN_DISPLAY: &[u8] = b"localscreen/v1 sign display";
const TRUST_HOST: &[u8] = b"localscreen/v1 trust host";
const TRUST_DISPLAY: &[u8] = b"localscreen/v1 trust display";
const TRUSTED_KEYS_INFO: &[u8] = b"localscreen/v1 trusted keys";

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, thiserror::Error)]
pub enum PairingError {
    #[error("malformed SPAKE2 message")]
    Spake,
    #[error("key derivation failed")]
    Kdf,
}

/// Generates a uniformly random 6-digit PIN.
pub fn generate_pin() -> String {
    format!("{:06}", OsRng.gen_range(0..1_000_000u32))
}

/// Accepts user input such as `" 123 456 "`; returns the canonical PIN.
pub fn normalize_pin(input: &str) -> Option<String> {
    let digits: String = input.chars().filter(|c| !c.is_whitespace()).collect();
    (digits.len() == PIN_DIGITS && digits.bytes().all(|b| b.is_ascii_digit())).then_some(digits)
}

/// 32 random bytes for challenge nonces.
pub fn random_nonce() -> [u8; 32] {
    let mut nonce = [0u8; 32];
    OsRng.fill_bytes(&mut nonce);
    nonce
}

/// Running hash over the plaintext handshake frames.
#[derive(Clone)]
pub struct Transcript(Sha256);

impl Default for Transcript {
    fn default() -> Self {
        let mut hash = Sha256::new();
        hash.update(TRANSCRIPT_LABEL);
        Self(hash)
    }
}

impl Transcript {
    pub fn new() -> Self {
        Self::default()
    }

    /// Absorbs one frame payload (length-prefixed, so boundaries are unambiguous).
    pub fn absorb(&mut self, frame: &[u8]) {
        self.0.update((frame.len() as u64).to_be_bytes());
        self.0.update(frame);
    }

    pub fn finish(self) -> [u8; 32] {
        self.0.finalize().into()
    }
}

/// Display-side bookkeeping for one PIN: remaining attempts and expiry.
#[derive(Debug)]
pub struct PinGuard {
    attempts_left: u8,
    deadline: tokio::time::Instant,
}

impl PinGuard {
    pub fn new(lifetime: std::time::Duration) -> Self {
        Self {
            attempts_left: MAX_PIN_ATTEMPTS,
            deadline: tokio::time::Instant::now() + lifetime,
        }
    }

    pub fn attempts_left(&self) -> u8 {
        self.attempts_left
    }

    pub fn deadline(&self) -> tokio::time::Instant {
        self.deadline
    }

    /// Records a wrong guess and returns the attempts that remain.
    pub fn record_failure(&mut self) -> u8 {
        self.attempts_left = self.attempts_left.saturating_sub(1);
        self.attempts_left
    }
}

fn hmac(key: &[u8], parts: &[&[u8]]) -> Result<[u8; 32], PairingError> {
    let mut mac = <HmacSha256 as Mac>::new_from_slice(key).map_err(|_| PairingError::Kdf)?;
    for part in parts {
        mac.update(part);
    }
    Ok(mac.finalize().into_bytes().into())
}

fn hmac_verify(key: &[u8], parts: &[&[u8]], tag: &[u8; 32]) -> bool {
    let Ok(mut mac) = <HmacSha256 as Mac>::new_from_slice(key) else {
        return false;
    };
    for part in parts {
        mac.update(part);
    }
    mac.verify_slice(tag).is_ok()
}

fn split_key(okm: &[u8], index: usize) -> [u8; KEY_LEN] {
    let mut key = [0u8; KEY_LEN];
    key.copy_from_slice(&okm[index * KEY_LEN..(index + 1) * KEY_LEN]);
    key
}

fn attempt_hash(base: &[u8; 32], msg_a: &[u8], msg_b: &[u8]) -> [u8; 32] {
    let mut transcript = Transcript(Sha256::new());
    transcript.0.update(ATTEMPT_LABEL);
    transcript.0.update(base);
    transcript.absorb(msg_a);
    transcript.absorb(msg_b);
    transcript.finish()
}

/// Keys derived from one SPAKE2 attempt. Not `Debug` on purpose.
pub struct PinKeys {
    attempt: [u8; 32],
    confirm_host: [u8; KEY_LEN],
    confirm_display: [u8; KEY_LEN],
    host_to_display: [u8; KEY_LEN],
    display_to_host: [u8; KEY_LEN],
    trust_secret: [u8; KEY_LEN],
}

impl PinKeys {
    fn derive(
        spake_key: &[u8],
        base: &[u8; 32],
        msg_a: &[u8],
        msg_b: &[u8],
    ) -> Result<Self, PairingError> {
        let attempt = attempt_hash(base, msg_a, msg_b);
        let mut okm = [0u8; KEY_LEN * 5];
        Hkdf::<Sha256>::new(Some(&attempt), spake_key)
            .expand(PIN_KEYS_INFO, &mut okm)
            .map_err(|_| PairingError::Kdf)?;
        Ok(Self {
            attempt,
            confirm_host: split_key(&okm, 0),
            confirm_display: split_key(&okm, 1),
            host_to_display: split_key(&okm, 2),
            display_to_host: split_key(&okm, 3),
            trust_secret: split_key(&okm, 4),
        })
    }

    fn confirm_material(&self, role: SessionRole) -> (&[u8; KEY_LEN], &'static [u8]) {
        match role {
            SessionRole::Host => (&self.confirm_host, CONFIRM_HOST),
            SessionRole::Display => (&self.confirm_display, CONFIRM_DISPLAY),
        }
    }

    /// The key-confirmation MAC that `role` sends.
    pub fn mac(&self, role: SessionRole) -> Result<[u8; 32], PairingError> {
        let (key, label) = self.confirm_material(role);
        hmac(key, &[label, &self.attempt])
    }

    /// Checks a key-confirmation MAC claimed to come from `role`.
    pub fn verify_mac(&self, role: SessionRole, tag: &[u8; 32]) -> bool {
        let (key, label) = self.confirm_material(role);
        hmac_verify(key, &[label, &self.attempt], tag)
    }

    /// What `role` signs with its identity key to bind it to this pairing.
    pub fn signing_payload(&self, role: SessionRole) -> Vec<u8> {
        let label = match role {
            SessionRole::Host => SIGN_HOST,
            SessionRole::Display => SIGN_DISPLAY,
        };
        [label, &self.attempt[..]].concat()
    }

    pub fn trust_secret(&self) -> [u8; KEY_LEN] {
        self.trust_secret
    }

    pub fn session_keys(&self) -> SessionKeys {
        SessionKeys::new(self.host_to_display, self.display_to_host)
    }
}

/// Host side of one PIN attempt.
pub struct HostAttempt {
    spake: Spake2<Ed25519Group>,
    msg_a: Vec<u8>,
}

impl HostAttempt {
    pub fn start(pin: &str, host_id: &str, display_id: &str) -> Self {
        let (spake, msg_a) = Spake2::<Ed25519Group>::start_a(
            &Password::new(pin.as_bytes()),
            &SpakeIdentity::new(host_id.as_bytes()),
            &SpakeIdentity::new(display_id.as_bytes()),
        );
        Self { spake, msg_a }
    }

    pub fn message(&self) -> &[u8] {
        &self.msg_a
    }

    pub fn finish(self, base: &[u8; 32], msg_b: &[u8]) -> Result<PinKeys, PairingError> {
        let key = self.spake.finish(msg_b).map_err(|_| PairingError::Spake)?;
        PinKeys::derive(&key, base, &self.msg_a, msg_b)
    }
}

/// Display side of one PIN attempt: returns message B and the derived keys.
pub fn display_respond(
    pin: &str,
    host_id: &str,
    display_id: &str,
    base: &[u8; 32],
    msg_a: &[u8],
) -> Result<(Vec<u8>, PinKeys), PairingError> {
    let (spake, msg_b) = Spake2::<Ed25519Group>::start_b(
        &Password::new(pin.as_bytes()),
        &SpakeIdentity::new(host_id.as_bytes()),
        &SpakeIdentity::new(display_id.as_bytes()),
    );
    let key = spake.finish(msg_a).map_err(|_| PairingError::Spake)?;
    let keys = PinKeys::derive(&key, base, msg_a, &msg_b)?;
    Ok((msg_b, keys))
}

fn trust_label(role: SessionRole) -> &'static [u8] {
    match role {
        SessionRole::Host => TRUST_HOST,
        SessionRole::Display => TRUST_DISPLAY,
    }
}

/// Challenge-response proof that `role` holds the trust secret.
pub fn trust_proof(
    secret: &[u8; 32],
    base: &[u8; 32],
    nonce_host: &[u8; 32],
    nonce_display: &[u8; 32],
    role: SessionRole,
) -> Result<[u8; 32], PairingError> {
    hmac(
        secret,
        &[trust_label(role), base, nonce_host, nonce_display],
    )
}

/// Verifies a proof claimed to come from `role`.
pub fn verify_trust_proof(
    secret: &[u8; 32],
    base: &[u8; 32],
    nonce_host: &[u8; 32],
    nonce_display: &[u8; 32],
    role: SessionRole,
    proof: &[u8; 32],
) -> bool {
    hmac_verify(
        secret,
        &[trust_label(role), base, nonce_host, nonce_display],
        proof,
    )
}

/// Session keys for a trusted reconnect.
pub fn trusted_session_keys(
    secret: &[u8; 32],
    base: &[u8; 32],
    nonce_host: &[u8; 32],
    nonce_display: &[u8; 32],
) -> Result<SessionKeys, PairingError> {
    let mut okm = [0u8; KEY_LEN * 2];
    let info = [TRUSTED_KEYS_INFO, nonce_host, nonce_display].concat();
    Hkdf::<Sha256>::new(Some(base), secret)
        .expand(&info, &mut okm)
        .map_err(|_| PairingError::Kdf)?;
    Ok(SessionKeys::new(split_key(&okm, 0), split_key(&okm, 1)))
}

#[cfg(test)]
mod tests {
    use super::*;

    const HOST: &str = "aaaaaaaaaaaaaaaa";
    const DISPLAY: &str = "bbbbbbbbbbbbbbbb";
    const BASE: [u8; 32] = [7; 32];

    fn run_attempt(host_pin: &str, display_pin: &str) -> (PinKeys, PinKeys) {
        let host = HostAttempt::start(host_pin, HOST, DISPLAY);
        let msg_a = host.message().to_vec();
        let (msg_b, display_keys) =
            display_respond(display_pin, HOST, DISPLAY, &BASE, &msg_a).unwrap();
        let host_keys = host.finish(&BASE, &msg_b).unwrap();
        (host_keys, display_keys)
    }

    #[test]
    fn pins_are_six_digits() {
        for _ in 0..100 {
            let pin = generate_pin();
            assert_eq!(normalize_pin(&pin).as_deref(), Some(pin.as_str()));
        }
    }

    #[test]
    fn normalizes_user_input() {
        assert_eq!(normalize_pin(" 123 456 ").as_deref(), Some("123456"));
        assert_eq!(normalize_pin("012345").as_deref(), Some("012345"));
        assert_eq!(normalize_pin("12345"), None);
        assert_eq!(normalize_pin("1234567"), None);
        assert_eq!(normalize_pin("12345a"), None);
        assert_eq!(normalize_pin("１２３４５６"), None);
    }

    #[test]
    fn guard_counts_down() {
        let mut guard = PinGuard::new(std::time::Duration::from_secs(60));
        assert_eq!(guard.attempts_left(), MAX_PIN_ATTEMPTS);
        for left in (0..MAX_PIN_ATTEMPTS).rev() {
            assert_eq!(guard.record_failure(), left);
        }
        assert_eq!(guard.record_failure(), 0);
    }

    #[test]
    fn matching_pins_confirm_both_ways() {
        let (host, display) = run_attempt("123456", "123456");
        let host_mac = host.mac(SessionRole::Host).unwrap();
        assert!(display.verify_mac(SessionRole::Host, &host_mac));
        let display_mac = display.mac(SessionRole::Display).unwrap();
        assert!(host.verify_mac(SessionRole::Display, &display_mac));
        // A MAC is not valid for the other role (no reflection).
        assert!(!host.verify_mac(SessionRole::Host, &display_mac));
        assert_eq!(host.trust_secret(), display.trust_secret());
        assert_eq!(
            host.signing_payload(SessionRole::Host),
            display.signing_payload(SessionRole::Host)
        );

        let (mut h_seal, _) = host.session_keys().into_channel(SessionRole::Host);
        let (_, mut d_open) = display.session_keys().into_channel(SessionRole::Display);
        let frame = h_seal.seal(b"hi").unwrap();
        assert_eq!(d_open.open(&frame).unwrap(), b"hi");
    }

    #[test]
    fn wrong_pin_fails_confirmation() {
        let (host, display) = run_attempt("123456", "654321");
        let host_mac = host.mac(SessionRole::Host).unwrap();
        assert!(!display.verify_mac(SessionRole::Host, &host_mac));
        assert_ne!(host.trust_secret(), display.trust_secret());
    }

    #[test]
    fn attempts_are_independent() {
        let (first, _) = run_attempt("123456", "123456");
        let (second, _) = run_attempt("123456", "123456");
        assert_ne!(first.trust_secret(), second.trust_secret());
    }

    #[test]
    fn malformed_spake_message_is_rejected() {
        assert!(display_respond("123456", HOST, DISPLAY, &BASE, b"junk").is_err());
    }

    #[test]
    fn trust_proofs() {
        let secret = [3u8; 32];
        let (nh, nd) = (random_nonce(), random_nonce());
        let proof = trust_proof(&secret, &BASE, &nh, &nd, SessionRole::Display).unwrap();
        assert!(verify_trust_proof(
            &secret,
            &BASE,
            &nh,
            &nd,
            SessionRole::Display,
            &proof
        ));
        assert!(!verify_trust_proof(
            &secret,
            &BASE,
            &nh,
            &nd,
            SessionRole::Host,
            &proof
        ));
        assert!(!verify_trust_proof(
            &[4u8; 32],
            &BASE,
            &nh,
            &nd,
            SessionRole::Display,
            &proof
        ));
        assert!(!verify_trust_proof(
            &secret,
            &BASE,
            &random_nonce(),
            &nd,
            SessionRole::Display,
            &proof
        ));
    }

    #[test]
    fn trusted_keys_match_and_depend_on_nonces() {
        let secret = [3u8; 32];
        let (nh, nd) = (random_nonce(), random_nonce());
        let (mut h_seal, _) = trusted_session_keys(&secret, &BASE, &nh, &nd)
            .unwrap()
            .into_channel(SessionRole::Host);
        let (_, mut d_open) = trusted_session_keys(&secret, &BASE, &nh, &nd)
            .unwrap()
            .into_channel(SessionRole::Display);
        let (_, mut other_open) = trusted_session_keys(&secret, &BASE, &nh, &random_nonce())
            .unwrap()
            .into_channel(SessionRole::Display);
        let frame = h_seal.seal(b"x").unwrap();
        assert!(other_open.open(&frame).is_err());
        assert_eq!(d_open.open(&frame).unwrap(), b"x");
    }
}
