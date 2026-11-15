//! Control-plane core of LocalScreen.
//!
//! Everything here is independent of flutter_rust_bridge so it can be unit and
//! integration tested in-process. The bridge facade in `crate::api` forwards
//! to [`Node`] through `crate::bridge`.
//!
//! Module map:
//! - [`identity`]: long-term Ed25519 device key and device id.
//! - [`store`]: persisted trusted-device store.
//! - [`net`]: LAN address enumeration and manual address parsing.
//! - [`discovery`]: mDNS advertisement and browsing.
//! - [`peers`]: table of currently visible peers.
//! - [`frame`]: length-prefixed framing on the TCP control channel.
//! - [`channel`]: ChaCha20-Poly1305 encryption of frames after the handshake.
//! - [`wire`]: protocol messages and their JSON encoding.
//! - [`pairing`]: PIN generation, SPAKE2 pairing and trusted challenge-response.
//! - [`conn`]: a framed, optionally encrypted TCP connection.
//! - [`session`]: per-session state machines for the host and display roles.
//! - [`node`]: the node itself; owns the listener, discovery and sessions.

pub mod channel;
pub mod conn;
pub mod discovery;
pub mod error;
pub mod events;
pub mod frame;
pub mod identity;
pub mod net;
pub mod node;
pub mod pairing;
pub mod peers;
pub mod session;
pub mod store;
pub mod wire;

#[cfg(test)]
mod tests;

pub use error::{NodeError, SessionFault};
pub use events::EventSink;
pub use node::{Node, NodeOptions, Timings};

/// Version of the control protocol, advertised in mDNS (`v`) and in `Hello`.
pub const PROTOCOL_VERSION: u32 = 1;

/// Preferred control port. Used when `NodeConfig::port` is `0`; if it is busy
/// the node falls back to any free port.
pub const DEFAULT_PORT: u16 = 53520;

/// mDNS service type advertised and browsed by every node.
pub const SERVICE_TYPE: &str = "_localscreen._tcp.local.";

/// Locks a mutex, recovering the data if another thread panicked while
/// holding it. None of the guarded state can be left logically inconsistent
/// by a panic, so continuing is preferable to cascading the panic.
pub(crate) fn lock<T>(mutex: &std::sync::Mutex<T>) -> std::sync::MutexGuard<'_, T> {
    mutex
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner)
}
