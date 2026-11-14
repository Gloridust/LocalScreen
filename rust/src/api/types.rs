//! Plain data types shared with the Dart side.
//!
//! Keep these free of behaviour: they are mirrored 1:1 into Dart classes by
//! flutter_rust_bridge, so every field here is part of the app contract.

/// Form factor of a device, used by the UI to pick an icon and layout hints.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeviceKind {
    Desktop,
    Laptop,
    Tablet,
    Phone,
    Tv,
}

/// How the host's screen is presented on the display device.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ShareMode {
    /// The display acts as an additional monitor of the host.
    Extend,
    /// The display shows a copy of an existing host screen or window.
    Mirror,
}

/// Which side of a session this node is on.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionRole {
    /// Captures and sends its screen.
    Host,
    /// Receives and renders the host's screen.
    Display,
}

/// Why a session ended.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CloseReason {
    /// Closed by the local user.
    LocalHangup,
    /// Closed by the remote user.
    RemoteHangup,
    /// The remote user declined the request.
    Declined,
    /// Too many wrong PIN attempts, or the PIN expired.
    PinFailed,
    /// Nobody answered in time.
    Timeout,
    /// The connection dropped or a protocol error occurred.
    NetworkError,
}

/// Settings needed to start the local node.
#[derive(Debug, Clone)]
pub struct NodeConfig {
    /// Human readable name advertised to peers.
    pub device_name: String,
    pub device_kind: DeviceKind,
    /// Lower-case OS identifier: `linux`, `windows`, `macos`, `android`, `ios`.
    pub platform: String,
    /// Writable directory for the identity key and the trusted-device store.
    pub storage_dir: String,
    /// Whether this node advertises itself on the LAN.
    pub discoverable: bool,
    /// TCP port for the control channel; `0` picks a free port.
    pub port: u16,
}

/// The local node's own identity, returned once the node is running.
#[derive(Debug, Clone)]
pub struct LocalIdentity {
    /// Stable device id derived from the long-term public key.
    pub id: String,
    pub name: String,
    /// Port the control channel is actually listening on.
    pub port: u16,
    /// LAN addresses this node is reachable at.
    pub addresses: Vec<String>,
}

/// A device seen on the network (or remembered from a past pairing).
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    pub id: String,
    pub name: String,
    pub kind: DeviceKind,
    pub platform: String,
    pub addresses: Vec<String>,
    pub port: u16,
    /// True once this device has been paired with a PIN.
    pub trusted: bool,
}

/// Events pushed from the node to the UI.
#[derive(Debug, Clone)]
pub enum NodeEvent {
    /// A peer appeared, or its details changed.
    PeerFound { peer: DeviceInfo },
    /// A peer is no longer reachable.
    PeerLost { id: String },
    /// Display side: a host wants to use this device as a screen.
    ///
    /// `pin` is set when the host is not trusted yet; the UI must show it so
    /// the user can type it on the host. For trusted hosts it is `None` and
    /// the UI answers with [`respond_to_request`](super::node::respond_to_request).
    IncomingRequest {
        session_id: String,
        peer: DeviceInfo,
        mode: ShareMode,
        pin: Option<String>,
    },
    /// Host side: the display is showing a PIN that must be entered here.
    PinRequired { session_id: String },
    /// Host side: the entered PIN was wrong.
    PinRejected {
        session_id: String,
        attempts_left: u8,
    },
    /// Both sides: the secure control channel is up; media negotiation can start.
    SessionEstablished {
        session_id: String,
        peer: DeviceInfo,
        role: SessionRole,
        mode: ShareMode,
    },
    /// Both sides: an opaque signalling payload (SDP / ICE as JSON) from the peer.
    Signal { session_id: String, payload: String },
    /// Both sides: the session is over.
    SessionClosed {
        session_id: String,
        reason: CloseReason,
    },
}
