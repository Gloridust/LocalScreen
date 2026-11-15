//! Control-channel messages and their encoding.
//!
//! Every frame payload is UTF-8 JSON (`serde_json`), chosen for
//! debuggability; binary fields (keys, nonces, MACs, SPAKE2 messages) are
//! lower-case hex strings. Messages are internally tagged with `"type"`.
//!
//! The connection has two phases:
//! 1. [`Handshake`] messages travel in plaintext frames.
//! 2. Once a session key is agreed, both sides switch to [`Secure`]
//!    messages, each sealed by [`crate::core::channel`].
//!
//! These wire types are deliberately separate from the bridge types in
//! `crate::api::types` so the Dart contract and the protocol can evolve
//! independently.

use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};

use crate::api::types::{CloseReason, DeviceKind, ShareMode};
use crate::core::identity;

/// Longest device name accepted or advertised, in UTF-8 bytes.
pub const MAX_NAME_BYTES: usize = 96;
/// Longest platform identifier accepted, in bytes.
pub const MAX_PLATFORM_BYTES: usize = 16;

#[derive(Debug, thiserror::Error)]
pub enum WireError {
    #[error("malformed message: {0}")]
    Json(#[from] serde_json::Error),
    #[error("device id does not match its public key")]
    IdMismatch,
}

/// Serde helper encoding byte containers (`[u8; N]`, `Vec<u8>`) as hex.
pub mod hex_bytes {
    use serde::de::Error as _;
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer, T: AsRef<[u8]>>(value: &T, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&hex::encode(value))
    }

    pub fn deserialize<'de, D, T>(d: D) -> Result<T, D::Error>
    where
        D: Deserializer<'de>,
        T: TryFrom<Vec<u8>>,
    {
        let text = String::deserialize(d)?;
        let bytes = hex::decode(text).map_err(D::Error::custom)?;
        T::try_from(bytes).map_err(|_| D::Error::custom("unexpected byte length"))
    }
}

/// Self-description each side sends in `Hello` / `Welcome`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceHello {
    pub id: String,
    pub name: String,
    /// One of the [`kind_to_str`] values; unknown values map to desktop.
    pub kind: String,
    pub platform: String,
    /// The sender's control port (where it accepts connections).
    pub port: u16,
    #[serde(with = "hex_bytes")]
    pub public_key: [u8; 32],
}

impl DeviceHello {
    /// Checks the id is the fingerprint of the key and clamps free-text fields.
    pub fn validated(mut self) -> Result<Self, WireError> {
        if identity::fingerprint(&self.public_key) != self.id {
            return Err(WireError::IdMismatch);
        }
        self.name = sanitize_name(&self.name);
        self.platform = truncate_utf8(self.platform.trim(), MAX_PLATFORM_BYTES).to_owned();
        Ok(self)
    }

    pub fn device_kind(&self) -> DeviceKind {
        kind_from_str(&self.kind)
    }
}

/// What the initiator wants from a connection.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Purpose {
    /// Exchange `Hello`/`Welcome` and disconnect (manual probing).
    Info,
    /// Start a screen-sharing session with the initiator as host.
    Session,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WireMode {
    Extend,
    Mirror,
}

impl From<ShareMode> for WireMode {
    fn from(mode: ShareMode) -> Self {
        match mode {
            ShareMode::Extend => Self::Extend,
            ShareMode::Mirror => Self::Mirror,
        }
    }
}

impl From<WireMode> for ShareMode {
    fn from(mode: WireMode) -> Self {
        match mode {
            WireMode::Extend => Self::Extend,
            WireMode::Mirror => Self::Mirror,
        }
    }
}

/// Reason carried by a `Close` message, from the sender's point of view.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum WireClose {
    Hangup,
    Declined,
    PinFailed,
    Timeout,
    Error,
}

impl WireClose {
    /// The reason the *receiver* of this close reports to its UI.
    pub fn remote_reason(self) -> CloseReason {
        match self {
            Self::Hangup => CloseReason::RemoteHangup,
            Self::Declined => CloseReason::Declined,
            Self::PinFailed => CloseReason::PinFailed,
            Self::Timeout => CloseReason::Timeout,
            Self::Error => CloseReason::NetworkError,
        }
    }
}

/// How the host proposes to authenticate.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "method", rename_all = "snake_case")]
pub enum AuthMethod {
    /// The host holds no trust secret for the display.
    Pin,
    /// The host holds a trust secret and offers a fresh nonce.
    Trusted {
        #[serde(with = "hex_bytes")]
        nonce: [u8; 32],
    },
}

/// Plaintext handshake messages (H = host/initiator, D = display/responder).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Handshake {
    /// H → D, first frame on every connection.
    Hello {
        version: u32,
        purpose: Purpose,
        device: DeviceHello,
    },
    /// D → H, answer to `Hello`.
    Welcome { version: u32, device: DeviceHello },
    /// H → D, asks the display to show the host's screen.
    SessionRequest { mode: WireMode, auth: AuthMethod },
    /// D → H, the display also has the trust secret.
    TrustChallenge {
        #[serde(with = "hex_bytes")]
        nonce: [u8; 32],
        #[serde(with = "hex_bytes")]
        proof: [u8; 32],
    },
    /// H → D, the host verified the challenge.
    TrustProof {
        #[serde(with = "hex_bytes")]
        proof: [u8; 32],
    },
    /// H → D, the display's proof did not verify; fall back to a PIN.
    TrustFailed,
    /// D → H, the host's proof verified; both switch to encrypted frames.
    TrustAccepted,
    /// D → H, a PIN is now shown on the display.
    PinRequired { attempts_left: u8 },
    /// H → D, SPAKE2 message A for one PIN guess.
    PinAttempt {
        #[serde(with = "hex_bytes")]
        spake: Vec<u8>,
    },
    /// D → H, SPAKE2 message B for the same guess.
    PinReply {
        #[serde(with = "hex_bytes")]
        spake: Vec<u8>,
    },
    /// H → D, host key confirmation plus identity signature.
    PinConfirm {
        #[serde(with = "hex_bytes")]
        mac: [u8; 32],
        #[serde(with = "hex_bytes")]
        signature: [u8; 64],
    },
    /// D → H, the guess was wrong.
    PinRejected { attempts_left: u8 },
    /// D → H, display key confirmation; both switch to encrypted frames.
    PinAccepted {
        #[serde(with = "hex_bytes")]
        mac: [u8; 32],
        #[serde(with = "hex_bytes")]
        signature: [u8; 64],
    },
    /// Either side, ends the connection before encryption is up.
    Close { reason: WireClose },
}

/// Messages inside the encrypted channel.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Secure {
    /// D → H, the display user accepted a trusted request.
    Accept,
    /// Either side, opaque signalling payload for the media plane.
    Signal {
        payload: String,
    },
    /// Keepalive probe; answered with `Pong`.
    Ping,
    Pong,
    /// Either side, ends the session.
    Close {
        reason: WireClose,
    },
}

pub fn encode<T: Serialize>(message: &T) -> Result<Vec<u8>, WireError> {
    Ok(serde_json::to_vec(message)?)
}

pub fn decode<T: DeserializeOwned>(bytes: &[u8]) -> Result<T, WireError> {
    Ok(serde_json::from_slice(bytes)?)
}

pub fn kind_to_str(kind: DeviceKind) -> &'static str {
    match kind {
        DeviceKind::Desktop => "desktop",
        DeviceKind::Laptop => "laptop",
        DeviceKind::Tablet => "tablet",
        DeviceKind::Phone => "phone",
        DeviceKind::Tv => "tv",
    }
}

pub fn kind_from_str(kind: &str) -> DeviceKind {
    match kind {
        "laptop" => DeviceKind::Laptop,
        "tablet" => DeviceKind::Tablet,
        "phone" => DeviceKind::Phone,
        "tv" => DeviceKind::Tv,
        _ => DeviceKind::Desktop,
    }
}

/// Trims a device name and clamps it to [`MAX_NAME_BYTES`].
pub fn sanitize_name(name: &str) -> String {
    let cleaned: String = name.trim().chars().filter(|c| !c.is_control()).collect();
    truncate_utf8(&cleaned, MAX_NAME_BYTES).to_owned()
}

/// Truncates to at most `max` bytes without splitting a character.
pub fn truncate_utf8(text: &str, max: usize) -> &str {
    if text.len() <= max {
        return text;
    }
    let mut end = max;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    &text[..end]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::identity::Identity;

    fn hello() -> DeviceHello {
        let identity = Identity::generate();
        DeviceHello {
            id: identity.id().to_owned(),
            name: "Pad".into(),
            kind: "tablet".into(),
            platform: "android".into(),
            port: 53520,
            public_key: identity.public_key(),
        }
    }

    #[test]
    fn handshake_round_trip() {
        let messages = vec![
            Handshake::Hello {
                version: 1,
                purpose: Purpose::Session,
                device: hello(),
            },
            Handshake::SessionRequest {
                mode: WireMode::Extend,
                auth: AuthMethod::Trusted { nonce: [9; 32] },
            },
            Handshake::PinConfirm {
                mac: [1; 32],
                signature: [2; 64],
            },
            Handshake::PinAttempt {
                spake: vec![1, 2, 3],
            },
            Handshake::Close {
                reason: WireClose::PinFailed,
            },
        ];
        for message in messages {
            let bytes = encode(&message).unwrap();
            assert_eq!(decode::<Handshake>(&bytes).unwrap(), message);
        }
    }

    #[test]
    fn json_shape_is_stable() {
        let bytes = encode(&Secure::Signal {
            payload: "x".into(),
        })
        .unwrap();
        assert_eq!(
            String::from_utf8(bytes).unwrap(),
            r#"{"type":"signal","payload":"x"}"#
        );
        let bytes = encode(&Handshake::TrustProof { proof: [0xab; 32] }).unwrap();
        assert!(String::from_utf8(bytes).unwrap().contains(&"ab".repeat(32)));
    }

    #[test]
    fn rejects_wrong_length_hex() {
        let json = r#"{"type":"trust_proof","proof":"abcd"}"#;
        assert!(decode::<Handshake>(json.as_bytes()).is_err());
    }

    #[test]
    fn validates_id_against_key() {
        assert!(hello().validated().is_ok());
        let mut forged = hello();
        forged.id = "0000000000000000".into();
        assert!(matches!(forged.validated(), Err(WireError::IdMismatch)));
    }

    #[test]
    fn clamps_names() {
        let long = "界".repeat(100);
        let name = sanitize_name(&long);
        assert!(name.len() <= MAX_NAME_BYTES);
        assert!(name.chars().all(|c| c == '界'));
        assert_eq!(sanitize_name("  a\u{7}b  "), "ab");
    }
}
