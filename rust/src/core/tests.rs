//! In-process integration tests: several nodes on loopback, mDNS disabled.

use std::net::Ipv4Addr;
use std::sync::Arc;
use std::time::Duration;

use tempfile::TempDir;
use tokio::net::TcpStream;
use tokio::sync::mpsc;

use crate::api::types::{
    CloseReason, DeviceInfo, DeviceKind, NodeConfig, NodeEvent, SessionRole, ShareMode,
};
use crate::core::conn::Conn;
use crate::core::identity::Identity;
use crate::core::wire::{AuthMethod, DeviceHello, Handshake, Purpose, WireMode};
use crate::core::{Node, NodeError, NodeOptions, Timings, PROTOCOL_VERSION};

const EVENT_TIMEOUT: Duration = Duration::from_secs(10);

struct TestNode {
    node: Node,
    events: mpsc::UnboundedReceiver<NodeEvent>,
    dir: TempDir,
    name: String,
    timings: Timings,
}

fn options(dir: &TempDir, name: &str, timings: Timings, port: u16) -> NodeOptions {
    NodeOptions {
        config: NodeConfig {
            device_name: name.to_owned(),
            device_kind: DeviceKind::Laptop,
            platform: "linux".into(),
            storage_dir: dir.path().to_string_lossy().into_owned(),
            discoverable: true,
            port,
        },
        mdns: false,
        bind_ip: Ipv4Addr::LOCALHOST,
        default_port: None,
        timings,
    }
}

impl TestNode {
    async fn start(name: &str) -> Self {
        Self::start_with(name, Timings::default()).await
    }

    async fn start_with(name: &str, timings: Timings) -> Self {
        Self::start_in(tempfile::tempdir().unwrap(), name, timings).await
    }

    async fn start_in(dir: TempDir, name: &str, timings: Timings) -> Self {
        let (tx, events) = mpsc::unbounded_channel();
        let node = Node::start(options(&dir, name, timings, 0), Arc::new(tx))
            .await
            .unwrap();
        Self {
            node,
            events,
            dir,
            name: name.to_owned(),
            timings,
        }
    }

    /// Stops the node and starts a new one on the same storage directory.
    async fn restart(self) -> Self {
        self.node.shutdown().await;
        Self::start_in(self.dir, &self.name, self.timings).await
    }

    fn id(&self) -> String {
        self.node.identity().id
    }

    fn addr(&self) -> String {
        format!("127.0.0.1:{}", self.node.identity().port)
    }

    /// Waits for the first event `f` accepts, skipping others.
    async fn expect<T>(&mut self, mut f: impl FnMut(&NodeEvent) -> Option<T>) -> T {
        let deadline = tokio::time::Instant::now() + EVENT_TIMEOUT;
        loop {
            let event = tokio::time::timeout_at(deadline, self.events.recv())
                .await
                .unwrap_or_else(|_| panic!("{}: timed out waiting for an event", self.name))
                .expect("event channel closed");
            if let Some(found) = f(&event) {
                return found;
            }
        }
    }

    /// Asserts no event `f` accepts arrives within `wait`.
    async fn expect_none(&mut self, wait: Duration, mut f: impl FnMut(&NodeEvent) -> bool) {
        let deadline = tokio::time::Instant::now() + wait;
        while let Ok(Some(event)) = tokio::time::timeout_at(deadline, self.events.recv()).await {
            assert!(!f(&event), "{}: unexpected event {event:?}", self.name);
        }
    }
}

macro_rules! expect_event {
    ($node:expr, $pat:pat $(if $guard:expr)? => $out:expr) => {
        $node
            .expect(|event| match event {
                $pat $(if $guard)? => Some($out),
                _ => None,
            })
            .await
    };
    ($node:expr, $pat:pat $(if $guard:expr)?) => {
        expect_event!($node, $pat $(if $guard)? => ())
    };
}

fn wrong(pin: &str) -> String {
    pin.chars()
        .map(|c| {
            if c == '9' {
                '0'
            } else {
                char::from(c as u8 + 1)
            }
        })
        .collect()
}

struct Pending {
    hs: String,
    ds: String,
    pin: Option<String>,
    /// The host as the display's `IncomingRequest` described it.
    host_peer: DeviceInfo,
}

/// Host requests a session and the display sees the request.
async fn request_full(host: &mut TestNode, display: &mut TestNode, mode: ShareMode) -> Pending {
    let peer = host.node.connect_manual(&display.addr()).await.unwrap();
    let hs = host.node.request_session(&peer.id, mode).await.unwrap();
    let host_id = host.id();
    let (ds, pin, host_peer) = expect_event!(display,
        NodeEvent::IncomingRequest { session_id, pin, peer, mode: m }
            if *m == mode && peer.id == host_id
            => (session_id.clone(), pin.clone(), peer.clone()));
    if pin.is_some() {
        // The host UI only offers PIN entry after this event.
        expect_event!(host, NodeEvent::PinRequired { session_id } if *session_id == hs);
    }
    Pending {
        hs,
        ds,
        pin,
        host_peer,
    }
}

/// Returns (host session, display session, PIN or None).
async fn request(
    host: &mut TestNode,
    display: &mut TestNode,
    mode: ShareMode,
) -> (String, String, Option<String>) {
    let pending = request_full(host, display, mode).await;
    (pending.hs, pending.ds, pending.pin)
}

async fn expect_established(node: &mut TestNode, sid: &str, role: SessionRole) -> DeviceInfo {
    expect_event!(node,
        NodeEvent::SessionEstablished { session_id, role: r, peer, .. }
            if session_id == sid && *r == role => peer.clone())
}

async fn expect_closed(node: &mut TestNode, sid: &str) -> CloseReason {
    expect_event!(node,
        NodeEvent::SessionClosed { session_id, reason } if session_id == sid => *reason)
}

/// Full PIN pairing; returns the established (host, display) session ids.
async fn pair(host: &mut TestNode, display: &mut TestNode) -> (String, String) {
    let (hs, ds, pin) = request(host, display, ShareMode::Extend).await;
    let pin = pin.expect("first contact must require a PIN");
    host.node.submit_pin(&hs, pin).await.unwrap();
    let display_peer = expect_established(host, &hs, SessionRole::Host).await;
    let host_peer = expect_established(display, &ds, SessionRole::Display).await;
    assert!(display_peer.trusted && host_peer.trusted);
    (hs, ds)
}

async fn hang_up(closer: &mut TestNode, cs: &str, other: &mut TestNode, os: &str) {
    closer.node.close_session(cs).await.unwrap();
    assert_eq!(expect_closed(closer, cs).await, CloseReason::LocalHangup);
    assert_eq!(expect_closed(other, os).await, CloseReason::RemoteHangup);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn manual_connect_exchanges_identity() {
    let mut host = TestNode::start("Host").await;
    let display = TestNode::start("Display").await;
    let peer = host.node.connect_manual(&display.addr()).await.unwrap();
    assert_eq!(peer.id, display.id());
    assert_eq!(peer.name, "Display");
    assert_eq!(peer.kind, DeviceKind::Laptop);
    assert_eq!(peer.platform, "linux");
    assert_eq!(peer.port, display.node.identity().port);
    assert_eq!(peer.addresses, vec!["127.0.0.1".to_owned()]);
    assert!(!peer.trusted);
    let found = expect_event!(host, NodeEvent::PeerFound { peer } => peer.clone());
    assert_eq!(found.id, display.id());
    assert_eq!(host.node.peers().len(), 1);
    assert!(display.node.peers().is_empty());

    let own = host.node.connect_manual(&host.addr()).await;
    assert!(matches!(own, Err(NodeError::SelfConnect)), "{own:?}");
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn pin_pairing_succeeds_and_persists_trust() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let pending = request_full(&mut host, &mut display, ShareMode::Extend).await;
    assert!(!pending.host_peer.trusted);
    let (hs, ds) = (pending.hs, pending.ds);
    host.node
        .submit_pin(&hs, pending.pin.unwrap())
        .await
        .unwrap();
    // The display is visible to the host, so its trust change is announced
    // (before the session is reported established).
    let display_id = display.id();
    expect_event!(host, NodeEvent::PeerFound { peer } if peer.id == display_id && peer.trusted);
    let peer = expect_established(&mut host, &hs, SessionRole::Host).await;
    assert_eq!(peer.id, display_id);
    let peer = expect_established(&mut display, &ds, SessionRole::Display).await;
    assert_eq!(peer.name, "Host");
    assert!(host.node.peers()[0].trusted);
    let host_trusted = host.node.trusted();
    assert_eq!(host_trusted.len(), 1);
    assert_eq!(host_trusted[0].id, display.id());
    let display_trusted = display.node.trusted();
    assert_eq!(display_trusted.len(), 1);
    assert_eq!(display_trusted[0].id, host.id());
    assert_eq!(display_trusted[0].name, "Host");

    hang_up(&mut host, &hs, &mut display, &ds).await;
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn wrong_pin_then_success() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    let pin = pin.unwrap();

    assert!(matches!(
        host.node.submit_pin(&hs, "12".into()).await,
        Err(NodeError::InvalidPin)
    ));
    host.node.submit_pin(&hs, wrong(&pin)).await.unwrap();
    let left = expect_event!(host,
        NodeEvent::PinRejected { session_id, attempts_left } if *session_id == hs => *attempts_left);
    assert_eq!(left, 4);
    host.node.submit_pin(&hs, pin).await.unwrap();
    expect_established(&mut host, &hs, SessionRole::Host).await;
    expect_established(&mut display, &ds, SessionRole::Display).await;
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn pin_exhaustion_closes_both_sides() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    let bad = wrong(&pin.unwrap());
    for expected_left in (1..=4u8).rev() {
        host.node.submit_pin(&hs, bad.clone()).await.unwrap();
        let left = expect_event!(host,
            NodeEvent::PinRejected { session_id, attempts_left } if *session_id == hs
                => *attempts_left);
        assert_eq!(left, expected_left);
    }
    host.node.submit_pin(&hs, bad).await.unwrap();
    assert_eq!(expect_closed(&mut host, &hs).await, CloseReason::PinFailed);
    assert_eq!(
        expect_closed(&mut display, &ds).await,
        CloseReason::PinFailed
    );
    assert!(host.node.trusted().is_empty());
    assert!(display.node.trusted().is_empty());
    assert!(matches!(
        host.node.submit_pin(&hs, "000000".into()).await,
        Err(NodeError::UnknownSession(_))
    ));
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn pin_expiry_fails_pairing() {
    let timings = Timings {
        pin_lifetime: Duration::from_millis(300),
        ..Timings::default()
    };
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start_with("Display", timings).await;
    let (hs, ds, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    assert!(pin.is_some());
    assert_eq!(
        expect_closed(&mut display, &ds).await,
        CloseReason::PinFailed
    );
    assert_eq!(expect_closed(&mut host, &hs).await, CloseReason::PinFailed);
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn trusted_reconnect_after_restart_and_accept() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    hang_up(&mut host, &hs, &mut display, &ds).await;

    // Identity and trust survive a restart of both nodes.
    let (host_id, display_id) = (host.id(), display.id());
    let mut host = host.restart().await;
    let mut display = display.restart().await;
    assert_eq!((host.id(), display.id()), (host_id, display_id));
    assert_eq!(host.node.trusted().len(), 1);

    let (hs, ds, pin) = request(&mut host, &mut display, ShareMode::Extend).await;
    assert_eq!(pin, None, "trusted host must not need a PIN");
    host.expect_none(
        Duration::from_millis(200),
        |e| matches!(e, NodeEvent::PinRequired { session_id } if *session_id == hs),
    )
    .await;
    assert!(matches!(
        host.node.respond(&hs, true).await,
        Err(NodeError::InvalidState(_))
    ));
    display.node.respond(&ds, true).await.unwrap();
    let peer = expect_established(&mut host, &hs, SessionRole::Host).await;
    assert!(peer.trusted);
    let peer = expect_established(&mut display, &ds, SessionRole::Display).await;
    assert!(peer.trusted);
    hang_up(&mut display, &ds, &mut host, &hs).await;
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn trusted_request_can_be_declined() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    hang_up(&mut host, &hs, &mut display, &ds).await;

    let (hs, ds, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    assert_eq!(pin, None);
    display.node.respond(&ds, false).await.unwrap();
    assert_eq!(expect_closed(&mut host, &hs).await, CloseReason::Declined);
    assert_eq!(
        expect_closed(&mut display, &ds).await,
        CloseReason::LocalHangup
    );
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn unanswered_trusted_request_times_out() {
    let timings = Timings {
        request_timeout: Duration::from_millis(300),
        ..Timings::default()
    };
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start_with("Display", timings).await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    hang_up(&mut host, &hs, &mut display, &ds).await;

    let (hs, ds, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    assert_eq!(pin, None);
    assert_eq!(expect_closed(&mut display, &ds).await, CloseReason::Timeout);
    assert_eq!(expect_closed(&mut host, &hs).await, CloseReason::Timeout);
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn forgotten_trust_falls_back_to_pin() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    hang_up(&mut host, &hs, &mut display, &ds).await;

    // Only the display forgets: the host still offers trust, which must fail
    // over to a PIN gracefully.
    display.node.forget_trusted(&host.id()).unwrap();
    assert!(display.node.trusted().is_empty());
    let (hs, _, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    // Re-pairing restores trust on both sides.
    host.node
        .submit_pin(&hs, pin.expect("PIN fallback"))
        .await
        .unwrap();
    expect_established(&mut host, &hs, SessionRole::Host).await;
    assert_eq!(display.node.trusted().len(), 1);

    // Now the host forgets: it no longer offers trust, so a PIN is needed.
    host.node.close_session(&hs).await.unwrap();
    let display_id = display.id();
    host.node.forget_trusted(&display_id).unwrap();
    expect_event!(host, NodeEvent::PeerFound { peer } if peer.id == display_id && !peer.trusted);
    let (_, _, pin) = request(&mut host, &mut display, ShareMode::Mirror).await;
    assert!(pin.is_some());
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn signals_flow_both_ways_in_order() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;

    for i in 0..5 {
        host.node
            .send_signal(&hs, format!("{{\"offer\":{i}}}"))
            .await
            .unwrap();
    }
    for i in 0..5 {
        let payload = expect_event!(display,
            NodeEvent::Signal { session_id, payload } if *session_id == ds => payload.clone());
        assert_eq!(payload, format!("{{\"offer\":{i}}}"));
    }
    let sdp = "v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\n\"quoted\" ünïcode".to_owned();
    display.node.send_signal(&ds, sdp.clone()).await.unwrap();
    let payload = expect_event!(host,
        NodeEvent::Signal { session_id, payload } if *session_id == hs => payload.clone());
    assert_eq!(payload, sdp);

    let too_big = "x".repeat(crate::core::frame::MAX_FRAME_LEN);
    assert!(matches!(
        host.node.send_signal(&hs, too_big).await,
        Err(NodeError::PayloadTooLarge(_))
    ));
    // The channel is still usable after a rejected payload.
    host.node.send_signal(&hs, "after".into()).await.unwrap();
    let payload = expect_event!(display,
        NodeEvent::Signal { session_id, payload } if *session_id == ds => payload.clone());
    assert_eq!(payload, "after");
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn hangup_from_host() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    hang_up(&mut host, &hs, &mut display, &ds).await;
    assert!(matches!(
        host.node.send_signal(&hs, "x".into()).await,
        Err(NodeError::UnknownSession(_))
    ));
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn hangup_from_display() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    hang_up(&mut display, &ds, &mut host, &hs).await;
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn pending_request_can_be_cancelled_by_either_side() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;

    let (hs, ds, _) = request(&mut host, &mut display, ShareMode::Mirror).await;
    hang_up(&mut host, &hs, &mut display, &ds).await;

    let (hs, ds, _) = request(&mut host, &mut display, ShareMode::Mirror).await;
    hang_up(&mut display, &ds, &mut host, &hs).await;

    // Declining a PIN request also works (dismissing the PIN card).
    let (hs, ds, _) = request(&mut host, &mut display, ShareMode::Mirror).await;
    display.node.respond(&ds, false).await.unwrap();
    assert_eq!(expect_closed(&mut host, &hs).await, CloseReason::Declined);
    assert_eq!(
        expect_closed(&mut display, &ds).await,
        CloseReason::LocalHangup
    );
    host.node.shutdown().await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn concurrent_sessions_are_independent() {
    let mut host = TestNode::start("Host").await;
    let mut first = TestNode::start("First").await;
    let mut second = TestNode::start("Second").await;
    let (h1, d1, p1) = request(&mut host, &mut first, ShareMode::Extend).await;
    let (h2, d2, p2) = request(&mut host, &mut second, ShareMode::Mirror).await;
    assert_ne!(h1, h2);
    host.node.submit_pin(&h2, p2.unwrap()).await.unwrap();
    host.node.submit_pin(&h1, p1.unwrap()).await.unwrap();
    expect_established(&mut first, &d1, SessionRole::Display).await;
    expect_established(&mut second, &d2, SessionRole::Display).await;
    expect_established(&mut host, &h1, SessionRole::Host).await;
    host.node.send_signal(&h1, "to-first".into()).await.unwrap();
    host.node
        .send_signal(&h2, "to-second".into())
        .await
        .unwrap();
    let got = expect_event!(first, NodeEvent::Signal { payload, .. } => payload.clone());
    assert_eq!(got, "to-first");
    let got = expect_event!(second, NodeEvent::Signal { payload, .. } => payload.clone());
    assert_eq!(got, "to-second");

    hang_up(&mut first, &d1, &mut host, &h1).await;
    host.node.send_signal(&h2, "still-up".into()).await.unwrap();
    let got = expect_event!(second, NodeEvent::Signal { payload, .. } => payload.clone());
    assert_eq!(got, "still-up");
    for node in [&host, &first, &second] {
        node.node.shutdown().await;
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn invalid_calls_are_rejected() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    assert!(matches!(
        host.node
            .request_session("0123456789abcdef", ShareMode::Mirror)
            .await,
        Err(NodeError::UnknownPeer(_))
    ));
    assert!(matches!(
        host.node.close_session("nope").await,
        Err(NodeError::UnknownSession(_))
    ));
    assert!(matches!(
        host.node.rename("  "),
        Err(NodeError::InvalidName)
    ));
    host.node.rename("Renamed").unwrap();
    assert_eq!(host.node.identity().name, "Renamed");
    host.node.set_discoverable(false).unwrap();

    let pending = request_full(&mut host, &mut display, ShareMode::Mirror).await;
    let (hs, ds) = (pending.hs, pending.ds);
    // The display sees the renamed host.
    assert_eq!(pending.host_peer.name, "Renamed");
    assert!(matches!(
        host.node.send_signal(&hs, "early".into()).await,
        Err(NodeError::InvalidState(_))
    ));
    assert!(matches!(
        display.node.submit_pin(&ds, "123456".into()).await,
        Err(NodeError::InvalidState(_))
    ));
    assert!(matches!(
        display.node.respond(&ds, true).await,
        Err(NodeError::InvalidState(_))
    ));
    host.node.shutdown().await;
    assert!(matches!(
        host.node.connect_manual(&display.addr()).await,
        Err(NodeError::NotRunning)
    ));
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn dropped_connection_reports_network_error() {
    let mut display = TestNode::start("Display").await;
    // A hand-rolled host that vanishes in the middle of pairing.
    let identity = Identity::generate();
    let stream = TcpStream::connect(display.addr()).await.unwrap();
    let mut conn = Conn::new(stream);
    let hello = DeviceHello {
        id: identity.id().to_owned(),
        name: "Ghost".into(),
        kind: "phone".into(),
        platform: "android".into(),
        port: 1,
        public_key: identity.public_key(),
    };
    conn.send_plain(&Handshake::Hello {
        version: PROTOCOL_VERSION,
        purpose: Purpose::Session,
        device: hello,
    })
    .await
    .unwrap();
    let (welcome, _) = conn.recv_plain(Duration::from_secs(5)).await.unwrap();
    assert!(matches!(welcome, Handshake::Welcome { .. }));
    conn.send_plain(&Handshake::SessionRequest {
        mode: WireMode::Mirror,
        auth: AuthMethod::Pin,
    })
    .await
    .unwrap();
    let ds = expect_event!(display,
        NodeEvent::IncomingRequest { session_id, peer, .. } if peer.name == "Ghost"
            => session_id.clone());
    drop(conn);
    assert_eq!(
        expect_closed(&mut display, &ds).await,
        CloseReason::NetworkError
    );
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn forged_identity_is_rejected() {
    let mut display = TestNode::start("Display").await;
    let identity = Identity::generate();
    let stream = TcpStream::connect(display.addr()).await.unwrap();
    let mut conn = Conn::new(stream);
    let hello = DeviceHello {
        id: "0123456789abcdef".into(),
        name: "Liar".into(),
        kind: "phone".into(),
        platform: "android".into(),
        port: 1,
        public_key: identity.public_key(),
    };
    conn.send_plain(&Handshake::Hello {
        version: PROTOCOL_VERSION,
        purpose: Purpose::Session,
        device: hello,
    })
    .await
    .unwrap();
    // The display answers Welcome, then drops the connection.
    let _ = conn.recv_plain(Duration::from_secs(5)).await;
    assert!(conn.recv_plain(Duration::from_secs(5)).await.is_err());
    display
        .expect_none(Duration::from_millis(200), |e| {
            matches!(e, NodeEvent::IncomingRequest { .. })
        })
        .await;
    display.node.shutdown().await;
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn shutdown_hangs_up_and_releases_port() {
    let mut host = TestNode::start("Host").await;
    let mut display = TestNode::start("Display").await;
    let (hs, ds) = pair(&mut host, &mut display).await;
    let port = display.node.identity().port;

    display.node.shutdown().await;
    assert_eq!(
        expect_closed(&mut display, &ds).await,
        CloseReason::LocalHangup
    );
    assert_eq!(
        expect_closed(&mut host, &hs).await,
        CloseReason::RemoteHangup
    );

    let dir = tempfile::tempdir().unwrap();
    let (tx, _rx) = mpsc::unbounded_channel();
    let again = Node::start(
        options(&dir, "Again", Timings::default(), port),
        Arc::new(tx),
    )
    .await
    .expect("port must be free after shutdown");
    assert_eq!(again.identity().port, port);
    again.shutdown().await;
    host.node.shutdown().await;
}

/// Real mDNS on this machine's interfaces. Ignored by default because it
/// needs working multicast; run with `cargo test -- --ignored mdns`.
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
#[ignore]
async fn mdns_discovery_smoke() {
    async fn start_mdns(name: &str) -> TestNode {
        let dir = tempfile::tempdir().unwrap();
        let (tx, events) = mpsc::unbounded_channel();
        let mut opts = options(&dir, name, Timings::default(), 0);
        opts.mdns = true;
        opts.bind_ip = Ipv4Addr::UNSPECIFIED;
        let node = Node::start(opts, Arc::new(tx)).await.unwrap();
        TestNode {
            node,
            events,
            dir,
            name: name.to_owned(),
            timings: Timings::default(),
        }
    }
    let mut host = start_mdns("Mdns Host").await;
    let mut display = start_mdns("Mdns Display").await;
    let display_id = display.id();
    let peer = expect_event!(host, NodeEvent::PeerFound { peer } if peer.id == display_id
        => peer.clone());
    assert_eq!(peer.name, "Mdns Display");
    assert!(!peer.addresses.is_empty());

    display.node.rename("Renamed Display").unwrap();
    expect_event!(host, NodeEvent::PeerFound { peer }
        if peer.id == display_id && peer.name == "Renamed Display");

    // Pair over the discovered address.
    let hs = host
        .node
        .request_session(&display_id, ShareMode::Mirror)
        .await
        .unwrap();
    let (ds, pin) = expect_event!(display,
        NodeEvent::IncomingRequest { session_id, pin: Some(pin), .. }
            => (session_id.clone(), pin.clone()));
    expect_event!(host, NodeEvent::PinRequired { session_id } if *session_id == hs);
    host.node.submit_pin(&hs, pin).await.unwrap();
    expect_established(&mut host, &hs, SessionRole::Host).await;
    expect_established(&mut display, &ds, SessionRole::Display).await;

    display.node.set_discoverable(false).unwrap();
    expect_event!(host, NodeEvent::PeerLost { id } if *id == display_id);
    host.node.shutdown().await;
    display.node.shutdown().await;
}
