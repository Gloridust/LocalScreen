//! Error types of the node.

use std::io;

use crate::core::channel::ChannelError;
use crate::core::discovery::DiscoveryError;
use crate::core::frame::FrameError;
use crate::core::pairing::{PairingError, PIN_DIGITS};
use crate::core::store::StoreError;
use crate::core::wire::WireError;

/// Errors returned by [`crate::core::Node`] operations.
#[derive(Debug, thiserror::Error)]
pub enum NodeError {
    #[error("the node is not running")]
    NotRunning,
    #[error("storage error: {0}")]
    Storage(#[from] StoreError),
    #[error("cannot listen on port {port}: {source}")]
    Bind { port: u16, source: io::Error },
    #[error("discovery error: {0}")]
    Discovery(#[from] DiscoveryError),
    #[error("unknown peer {0}")]
    UnknownPeer(String),
    #[error("unknown session {0}")]
    UnknownSession(String),
    #[error("invalid address {0:?}")]
    InvalidAddress(String),
    #[error("cannot reach {0}")]
    Unreachable(String),
    #[error("the PIN must be {PIN_DIGITS} digits")]
    InvalidPin,
    #[error("the device name must not be empty")]
    InvalidName,
    #[error("{0}")]
    InvalidState(&'static str),
    #[error("signal payload exceeds {0} bytes")]
    PayloadTooLarge(usize),
    #[error("expected device {expected} but reached {actual}")]
    PeerMismatch { expected: String, actual: String },
    #[error("refusing to connect to this device itself")]
    SelfConnect,
    #[error("the session has ended")]
    SessionEnded,
    #[error("handshake failed: {0}")]
    Handshake(#[from] SessionFault),
    #[error("i/o error: {0}")]
    Io(#[from] io::Error),
}

/// Why a connection or session failed at the transport/protocol level.
#[derive(Debug, thiserror::Error)]
pub enum SessionFault {
    #[error(transparent)]
    Frame(#[from] FrameError),
    #[error(transparent)]
    Channel(#[from] ChannelError),
    #[error(transparent)]
    Wire(#[from] WireError),
    #[error(transparent)]
    Pairing(#[from] PairingError),
    #[error("protocol violation: {0}")]
    Protocol(&'static str),
    #[error("peer speaks protocol version {0}")]
    Version(u32),
    #[error("peer did not answer in time")]
    Timeout,
    #[error("no traffic from peer; connection presumed dead")]
    Idle,
}

impl SessionFault {
    /// Whether the peer should be told about the failure with `Close{error}`.
    pub fn is_protocol(&self) -> bool {
        !matches!(
            self,
            Self::Frame(FrameError::Closed | FrameError::Io(_)) | Self::Idle
        )
    }
}
