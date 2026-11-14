//! Node lifecycle, discovery, pairing and signalling entry points.
//!
//! The node owns the *control plane* only: finding peers, authenticating them
//! with a PIN, and carrying encrypted signalling messages. The media plane
//! (WebRTC) lives on the Dart side and uses [`send_signal`] / `NodeEvent::Signal`
//! as its signalling transport.

use crate::api::types::{DeviceInfo, LocalIdentity, NodeConfig, NodeEvent, ShareMode};
use crate::bridge::{self, with_node};
use crate::frb_generated::StreamSink;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Starts the node and streams [`NodeEvent`]s into `events` until [`stop_node`].
///
/// The bridge turns the sink into the Dart return value, so success is
/// reported in-band: the first event is [`NodeEvent::Ready`]. A failed start
/// surfaces as an error on the Dart stream instead.
pub async fn start_node(config: NodeConfig, events: StreamSink<NodeEvent>) -> anyhow::Result<()> {
    bridge::start(config, events).await
}

/// Identity of the running node. Fails if the node has not been started.
pub async fn local_identity() -> anyhow::Result<LocalIdentity> {
    with_node(|node| async move { Ok(node.identity()) }).await
}

/// Stops discovery, closes every session and releases the listening port.
pub async fn stop_node() -> anyhow::Result<()> {
    bridge::stop().await
}

/// Turns LAN advertisement on or off without stopping the node.
pub async fn set_discoverable(discoverable: bool) -> anyhow::Result<()> {
    with_node(move |node| async move { node.set_discoverable(discoverable) }).await
}

/// Changes the advertised device name.
pub async fn rename_device(name: String) -> anyhow::Result<()> {
    with_node(move |node| async move { node.rename(&name) }).await
}

/// Snapshot of the peers currently visible on the network.
pub async fn list_peers() -> anyhow::Result<Vec<DeviceInfo>> {
    with_node(|node| async move { Ok(node.peers()) }).await
}

/// Probes `address` (`host` or `host:port`) directly, for networks where
/// multicast discovery is blocked.
pub async fn connect_manual(address: String) -> anyhow::Result<DeviceInfo> {
    with_node(move |node| async move { node.connect_manual(&address).await }).await
}

/// Host side: asks `peer_id` to become a display. Returns the session id.
pub async fn request_session(peer_id: String, mode: ShareMode) -> anyhow::Result<String> {
    with_node(move |node| async move { node.request_session(&peer_id, mode).await }).await
}

/// Host side: submits the PIN shown on the display device.
pub async fn submit_pin(session_id: String, pin: String) -> anyhow::Result<()> {
    with_node(move |node| async move { node.submit_pin(&session_id, pin).await }).await
}

/// Display side: accepts or declines an incoming request from a trusted host.
pub async fn respond_to_request(session_id: String, accept: bool) -> anyhow::Result<()> {
    with_node(move |node| async move { node.respond(&session_id, accept).await }).await
}

/// Sends an opaque signalling payload to the peer over the encrypted channel.
pub async fn send_signal(session_id: String, payload: String) -> anyhow::Result<()> {
    with_node(move |node| async move { node.send_signal(&session_id, payload).await }).await
}

/// Ends a session (or cancels a pending request).
pub async fn close_session(session_id: String) -> anyhow::Result<()> {
    with_node(move |node| async move { node.close_session(&session_id).await }).await
}

/// Devices that were paired before and may connect without a PIN.
pub async fn list_trusted() -> anyhow::Result<Vec<DeviceInfo>> {
    with_node(|node| async move { Ok(node.trusted()) }).await
}

/// Removes a device from the trusted list; it will need a PIN again.
pub async fn forget_trusted(id: String) -> anyhow::Result<()> {
    with_node(move |node| async move { node.forget_trusted(&id) }).await
}
