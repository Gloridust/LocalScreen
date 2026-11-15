//! The LocalScreen node: listener, discovery, peers, trust and sessions.
//!
//! [`Node`] is a cheap, cloneable handle and can be instantiated any number
//! of times in one process (the bridge keeps a single global one; the tests
//! run several on loopback with mDNS disabled).

use std::collections::HashMap;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{mpsc, oneshot, Semaphore};
use tokio_util::sync::CancellationToken;
use tokio_util::task::TaskTracker;

use crate::api::types::{
    DeviceInfo, DeviceKind, LocalIdentity, NodeConfig, NodeEvent, SessionRole, ShareMode,
};
use crate::core::conn::Conn;
use crate::core::discovery::{parse_service, Advertisement, Discovery, Receiver};
use crate::core::identity::Identity;
use crate::core::net;
use crate::core::pairing::Transcript;
use crate::core::peers::{PeerRecord, PeerTable};
use crate::core::session::{Command, Reply, Request, Session};
use crate::core::store::{StoreError, TrustStore, TrustedDevice};
use crate::core::wire::{
    kind_from_str, kind_to_str, sanitize_name, DeviceHello, Handshake, Purpose,
};
use crate::core::{lock, EventSink, NodeError, SessionFault, DEFAULT_PORT, PROTOCOL_VERSION};

/// Simultaneous inbound connections accepted before new ones are refused.
const MAX_INBOUND: usize = 32;
/// Queued API commands per session.
const COMMAND_QUEUE: usize = 16;
/// How long [`Node::shutdown`] waits for tasks to wind down.
const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(5);
/// Name used when the configured one is empty.
const FALLBACK_NAME: &str = "LocalScreen";

/// Protocol timers. Defaults match the product spec; tests shorten them.
#[derive(Debug, Clone, Copy)]
pub struct Timings {
    /// How long a displayed PIN stays valid.
    pub pin_lifetime: Duration,
    /// How long a trusted request waits for the display user.
    pub request_timeout: Duration,
    /// Bound for each automatic handshake round trip.
    pub step_timeout: Duration,
    /// Bound for establishing the TCP connection (per address).
    pub connect_timeout: Duration,
    /// Idle time after which an encrypted channel sends a ping.
    pub keepalive_interval: Duration,
    /// Silence after which an encrypted channel is considered dead.
    pub idle_timeout: Duration,
    /// How long a closing connection waits for the peer's FIN.
    pub linger: Duration,
}

impl Default for Timings {
    fn default() -> Self {
        Self {
            pin_lifetime: Duration::from_secs(60),
            request_timeout: Duration::from_secs(60),
            step_timeout: Duration::from_secs(10),
            connect_timeout: Duration::from_secs(5),
            keepalive_interval: Duration::from_secs(15),
            idle_timeout: Duration::from_secs(45),
            linger: Duration::from_secs(1),
        }
    }
}

/// How to start a node.
#[derive(Debug, Clone)]
pub struct NodeOptions {
    pub config: NodeConfig,
    /// Run mDNS advertisement/browsing. Disabled in tests.
    pub mdns: bool,
    /// Listen address; all IPv4 interfaces by default.
    pub bind_ip: Ipv4Addr,
    /// Port tried first when `config.port == 0` before any free port.
    pub default_port: Option<u16>,
    pub timings: Timings,
}

impl NodeOptions {
    /// Production defaults: mDNS on, all interfaces, prefer [`DEFAULT_PORT`].
    pub fn new(config: NodeConfig) -> Self {
        Self {
            config,
            mdns: true,
            bind_ip: Ipv4Addr::UNSPECIFIED,
            default_port: Some(DEFAULT_PORT),
            timings: Timings::default(),
        }
    }
}

struct Settings {
    name: String,
    discoverable: bool,
}

pub(crate) struct SessionHandle {
    commands: mpsc::Sender<Command>,
}

/// State shared by the node handle and all of its tasks.
pub(crate) struct Shared {
    pub(crate) identity: Identity,
    pub(crate) timings: Timings,
    pub(crate) events: Arc<dyn EventSink>,
    pub(crate) shutdown: CancellationToken,
    kind: DeviceKind,
    platform: String,
    port: u16,
    tracker: TaskTracker,
    settings: Mutex<Settings>,
    store: Mutex<TrustStore>,
    peers: Mutex<PeerTable>,
    sessions: Mutex<HashMap<String, SessionHandle>>,
    discovery: Mutex<Option<Discovery>>,
}

/// Handle to a running node.
#[derive(Clone)]
pub struct Node {
    shared: Arc<Shared>,
}

fn new_session_id() -> String {
    hex::encode(&crate::core::pairing::random_nonce()[..12])
}

fn unix_now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

async fn bind(options: &NodeOptions) -> Result<TcpListener, NodeError> {
    let ip = IpAddr::V4(options.bind_ip);
    let port = options.config.port;
    if port != 0 {
        return TcpListener::bind((ip, port))
            .await
            .map_err(|source| NodeError::Bind { port, source });
    }
    if let Some(preferred) = options.default_port {
        match TcpListener::bind((ip, preferred)).await {
            Ok(listener) => return Ok(listener),
            Err(e) => log::info!("port {preferred} unavailable ({e}); using a free port"),
        }
    }
    TcpListener::bind((ip, 0))
        .await
        .map_err(|source| NodeError::Bind { port: 0, source })
}

impl Node {
    /// Loads (or creates) the identity and trust store, starts listening and,
    /// if enabled, mDNS. Returns once the listener is bound.
    pub async fn start(
        options: NodeOptions,
        events: Arc<dyn EventSink>,
    ) -> Result<Self, NodeError> {
        let config = &options.config;
        let dir = PathBuf::from(&config.storage_dir);
        std::fs::create_dir_all(&dir).map_err(|e| StoreError::io(&dir, e))?;
        let identity = Identity::load_or_create(&dir)?;
        let store = TrustStore::open(&dir)?;
        let listener = bind(&options).await?;
        let port = listener.local_addr()?.port();
        let name = match sanitize_name(&config.device_name) {
            name if name.is_empty() => FALLBACK_NAME.to_owned(),
            name => name,
        };

        let shared = Arc::new(Shared {
            identity,
            timings: options.timings,
            events,
            shutdown: CancellationToken::new(),
            kind: config.device_kind,
            platform: config.platform.clone(),
            port,
            tracker: TaskTracker::new(),
            settings: Mutex::new(Settings {
                name,
                discoverable: config.discoverable,
            }),
            store: Mutex::new(store),
            peers: Mutex::new(PeerTable::default()),
            sessions: Mutex::new(HashMap::new()),
            discovery: Mutex::new(None),
        });
        if options.mdns {
            shared.start_discovery();
        }
        shared
            .tracker
            .spawn(accept_loop(Arc::clone(&shared), listener));
        log::info!("node {} listening on port {port}", shared.identity.id());
        Ok(Self { shared })
    }

    fn ensure_running(&self) -> Result<(), NodeError> {
        if self.shared.shutdown.is_cancelled() {
            return Err(NodeError::NotRunning);
        }
        Ok(())
    }

    /// Stops discovery, hangs up every session and releases the port.
    pub async fn shutdown(&self) {
        if self.shared.shutdown.is_cancelled() {
            return;
        }
        self.shared.shutdown.cancel();
        let discovery = lock(&self.shared.discovery).take();
        if let Some(discovery) = discovery {
            discovery.shutdown();
        }
        self.shared.tracker.close();
        if tokio::time::timeout(SHUTDOWN_TIMEOUT, self.shared.tracker.wait())
            .await
            .is_err()
        {
            log::warn!("some node tasks did not stop in time");
        }
        log::info!("node {} stopped", self.shared.identity.id());
    }

    pub fn identity(&self) -> LocalIdentity {
        LocalIdentity {
            id: self.shared.identity.id().to_owned(),
            name: lock(&self.shared.settings).name.clone(),
            port: self.shared.port,
            addresses: net::lan_ipv4_addresses()
                .iter()
                .map(Ipv4Addr::to_string)
                .collect(),
        }
    }

    pub fn set_discoverable(&self, discoverable: bool) -> Result<(), NodeError> {
        self.ensure_running()?;
        lock(&self.shared.settings).discoverable = discoverable;
        self.shared.update_advertisement()
    }

    pub fn rename(&self, name: &str) -> Result<(), NodeError> {
        self.ensure_running()?;
        let name = sanitize_name(name);
        if name.is_empty() {
            return Err(NodeError::InvalidName);
        }
        lock(&self.shared.settings).name = name;
        self.shared.update_advertisement()
    }

    pub fn peers(&self) -> Vec<DeviceInfo> {
        let peers = lock(&self.shared.peers).list();
        let store = lock(&self.shared.store);
        peers
            .iter()
            .map(|p| p.to_device_info(store.contains(&p.id)))
            .collect()
    }

    /// Probes `address` with an unauthenticated `Hello`, remembers the peer
    /// and emits `PeerFound`.
    pub async fn connect_manual(&self, address: &str) -> Result<DeviceInfo, NodeError> {
        self.ensure_running()?;
        let addrs = net::resolve(address, DEFAULT_PORT).await?;
        let dialed = self.shared.dial(&addrs, Purpose::Info).await?;
        dialed.conn.linger(self.shared.timings.linger).await;
        let record = lock(&self.shared.peers).upsert_manual(PeerRecord {
            id: dialed.device.id.clone(),
            name: dialed.device.name.clone(),
            kind: dialed.device.device_kind(),
            platform: dialed.device.platform.clone(),
            addresses: vec![dialed.addr.ip()],
            port: dialed.addr.port(),
        });
        let info = record.to_device_info(lock(&self.shared.store).contains(&record.id));
        self.shared
            .events
            .emit(NodeEvent::PeerFound { peer: info.clone() });
        Ok(info)
    }

    /// Connects to `peer_id`, performs `Hello`, and hands the connection to a
    /// host session task. Pairing continues asynchronously via events.
    pub async fn request_session(
        &self,
        peer_id: &str,
        mode: ShareMode,
    ) -> Result<String, NodeError> {
        self.ensure_running()?;
        let addrs = self
            .shared
            .addresses_of(peer_id)
            .ok_or_else(|| NodeError::UnknownPeer(peer_id.to_owned()))?;
        let dialed = self.shared.dial(&addrs, Purpose::Session).await?;
        if dialed.device.id != peer_id {
            return Err(NodeError::PeerMismatch {
                expected: peer_id.to_owned(),
                actual: dialed.device.id,
            });
        }
        let (id, commands) = self.shared.register_session();
        let session = Session::new(
            Arc::clone(&self.shared),
            id.clone(),
            SessionRole::Host,
            mode,
            dialed.device,
            dialed.addr,
            dialed.conn,
            commands,
        );
        self.shared.tracker.spawn(session.run(dialed.transcript));
        Ok(id)
    }

    async fn request(
        &self,
        session_id: &str,
        make: impl FnOnce(Reply) -> Request,
    ) -> Result<(), NodeError> {
        let sender = self.shared.session_sender(session_id)?;
        let (reply, response) = oneshot::channel();
        sender
            .send(Command::Request(make(reply)))
            .await
            .map_err(|_| NodeError::SessionEnded)?;
        response.await.map_err(|_| NodeError::SessionEnded)?
    }

    pub async fn submit_pin(&self, session_id: &str, pin: String) -> Result<(), NodeError> {
        self.request(session_id, |reply| Request::SubmitPin { pin, reply })
            .await
    }

    pub async fn respond(&self, session_id: &str, accept: bool) -> Result<(), NodeError> {
        self.request(session_id, |reply| Request::Respond { accept, reply })
            .await
    }

    pub async fn send_signal(&self, session_id: &str, payload: String) -> Result<(), NodeError> {
        self.request(session_id, |reply| Request::Signal { payload, reply })
            .await
    }

    /// Hangs up (or cancels) a session; returns once it is closed.
    pub async fn close_session(&self, session_id: &str) -> Result<(), NodeError> {
        let sender = self.shared.session_sender(session_id)?;
        let (done, closed) = oneshot::channel();
        if sender.send(Command::Close(done)).await.is_ok() {
            // An error only means the session ended on its own meanwhile.
            let _ = closed.await;
        }
        Ok(())
    }

    pub fn trusted(&self) -> Vec<DeviceInfo> {
        let devices = lock(&self.shared.store).list();
        let peers = lock(&self.shared.peers);
        devices
            .into_iter()
            .map(|d| match peers.get(&d.id) {
                Some(peer) => peer.to_device_info(true),
                None => DeviceInfo {
                    kind: kind_from_str(&d.kind),
                    id: d.id,
                    name: d.name,
                    platform: d.platform,
                    addresses: d.addresses,
                    port: d.port,
                    trusted: true,
                },
            })
            .collect()
    }

    pub fn forget_trusted(&self, id: &str) -> Result<(), NodeError> {
        let removed = lock(&self.shared.store).remove(id)?;
        if removed {
            self.shared.emit_peer_if_visible(id);
        }
        Ok(())
    }
}

/// Result of an outbound `Hello`/`Welcome` exchange.
struct Dialed {
    conn: Conn,
    device: DeviceHello,
    addr: SocketAddr,
    transcript: Transcript,
}

impl Shared {
    fn advertisement(&self) -> (Advertisement, bool) {
        let settings = lock(&self.settings);
        (
            Advertisement {
                name: settings.name.clone(),
                kind: self.kind,
                platform: self.platform.clone(),
            },
            settings.discoverable,
        )
    }

    fn start_discovery(self: &Arc<Self>) {
        match Discovery::start(self.identity.id(), self.port) {
            Ok((discovery, events)) => {
                *lock(&self.discovery) = Some(discovery);
                if let Err(e) = self.update_advertisement() {
                    log::warn!("cannot advertise over mDNS: {e}");
                }
                self.tracker.spawn(browse_loop(Arc::clone(self), events));
            }
            Err(e) => log::warn!("mDNS unavailable ({e}); only manual connections will work"),
        }
    }

    /// Applies the current name/discoverable settings to mDNS.
    fn update_advertisement(&self) -> Result<(), NodeError> {
        let (ad, discoverable) = self.advertisement();
        let mut discovery = lock(&self.discovery);
        let Some(discovery) = discovery.as_mut() else {
            return Ok(());
        };
        if discoverable {
            discovery.advertise(&ad)?;
        } else {
            discovery.withdraw()?;
        }
        Ok(())
    }

    fn on_service_event(&self, event: mdns_sd::ServiceEvent) {
        match event {
            mdns_sd::ServiceEvent::ServiceResolved(service) => {
                let Some(record) = parse_service(&service, self.identity.id()) else {
                    return;
                };
                let changed =
                    lock(&self.peers).upsert_discovered(&service.fullname, record.clone());
                if changed {
                    let trusted = lock(&self.store).contains(&record.id);
                    self.events.emit(NodeEvent::PeerFound {
                        peer: record.to_device_info(trusted),
                    });
                }
            }
            mdns_sd::ServiceEvent::ServiceRemoved(_, fullname) => {
                let removed = lock(&self.peers).remove_discovered(&fullname);
                if let Some(id) = removed {
                    self.events.emit(NodeEvent::PeerLost { id });
                }
            }
            _ => {}
        }
    }

    pub(crate) fn local_hello(&self) -> DeviceHello {
        DeviceHello {
            id: self.identity.id().to_owned(),
            name: lock(&self.settings).name.clone(),
            kind: kind_to_str(self.kind).to_owned(),
            platform: self.platform.clone(),
            port: self.port,
            public_key: self.identity.public_key(),
        }
    }

    /// Bridge-facing description of a session peer.
    pub(crate) fn peer_info(&self, hello: &DeviceHello, addr: SocketAddr) -> DeviceInfo {
        let trusted = lock(&self.store).contains(&hello.id);
        let mut addresses = vec![addr.ip()];
        if let Some(record) = lock(&self.peers).get(&hello.id) {
            addresses.extend(record.addresses.iter().filter(|a| **a != addr.ip()));
        }
        DeviceInfo {
            id: hello.id.clone(),
            name: hello.name.clone(),
            kind: hello.device_kind(),
            platform: hello.platform.clone(),
            addresses: addresses.iter().map(IpAddr::to_string).collect(),
            port: hello.port,
            trusted,
        }
    }

    pub(crate) fn trust_secret(&self, hello: &DeviceHello) -> Option<[u8; 32]> {
        lock(&self.store).secret_for(&hello.id, &hello.public_key)
    }

    /// Persists the trust secret from a successful PIN pairing.
    pub(crate) fn remember_trusted(&self, hello: &DeviceHello, addr: SocketAddr, secret: [u8; 32]) {
        let device = TrustedDevice {
            id: hello.id.clone(),
            public_key: hello.public_key,
            secret,
            name: hello.name.clone(),
            kind: hello.kind.clone(),
            platform: hello.platform.clone(),
            addresses: vec![addr.ip().to_string()],
            port: hello.port,
            paired_at: unix_now(),
        };
        if let Err(e) = lock(&self.store).upsert(device) {
            log::warn!("cannot persist trust for {}: {e}", hello.id);
        }
        self.emit_peer_if_visible(&hello.id);
    }

    /// Refreshes cached details of a trusted peer after a trusted reconnect.
    pub(crate) fn refresh_trusted(&self, hello: &DeviceHello, addr: SocketAddr) {
        let result = lock(&self.store).refresh(
            &hello.id,
            &hello.name,
            vec![addr.ip().to_string()],
            hello.port,
        );
        if let Err(e) = result {
            log::warn!("cannot update trusted device {}: {e}", hello.id);
        }
    }

    /// Re-emits `PeerFound` for a visible peer whose trust state changed.
    fn emit_peer_if_visible(&self, id: &str) {
        let record = lock(&self.peers).get(id).cloned();
        if let Some(record) = record {
            let trusted = lock(&self.store).contains(id);
            self.events.emit(NodeEvent::PeerFound {
                peer: record.to_device_info(trusted),
            });
        }
    }

    /// Where `peer_id` can be reached: visible peers first, then the
    /// last-known address of a trusted device.
    fn addresses_of(&self, peer_id: &str) -> Option<Vec<SocketAddr>> {
        if let Some(peer) = lock(&self.peers).get(peer_id) {
            return Some(
                peer.addresses
                    .iter()
                    .map(|ip| SocketAddr::new(*ip, peer.port))
                    .collect(),
            );
        }
        let store = lock(&self.store);
        let device = store.get(peer_id)?;
        let addrs: Vec<SocketAddr> = device
            .addresses
            .iter()
            .filter_map(|a| a.parse::<IpAddr>().ok())
            .map(|ip| SocketAddr::new(ip, device.port))
            .collect();
        (!addrs.is_empty()).then_some(addrs)
    }

    fn register_session(&self) -> (String, mpsc::Receiver<Command>) {
        let (commands, receiver) = mpsc::channel(COMMAND_QUEUE);
        let id = new_session_id();
        lock(&self.sessions).insert(id.clone(), SessionHandle { commands });
        (id, receiver)
    }

    pub(crate) fn unregister_session(&self, id: &str) {
        lock(&self.sessions).remove(id);
    }

    fn session_sender(&self, id: &str) -> Result<mpsc::Sender<Command>, NodeError> {
        lock(&self.sessions)
            .get(id)
            .map(|h| h.commands.clone())
            .ok_or_else(|| NodeError::UnknownSession(id.to_owned()))
    }

    /// Connects to the first reachable address and exchanges `Hello`/`Welcome`.
    async fn dial(&self, addrs: &[SocketAddr], purpose: Purpose) -> Result<Dialed, NodeError> {
        let mut connected = None;
        for addr in addrs {
            match tokio::time::timeout(self.timings.connect_timeout, TcpStream::connect(addr)).await
            {
                Ok(Ok(stream)) => {
                    connected = Some((stream, *addr));
                    break;
                }
                Ok(Err(e)) => log::debug!("connect to {addr} failed: {e}"),
                Err(_) => log::debug!("connect to {addr} timed out"),
            }
        }
        let Some((stream, addr)) = connected else {
            let list: Vec<String> = addrs.iter().map(SocketAddr::to_string).collect();
            return Err(NodeError::Unreachable(list.join(", ")));
        };
        let mut conn = Conn::new(stream);
        let hello = Handshake::Hello {
            version: PROTOCOL_VERSION,
            purpose,
            device: self.local_hello(),
        };
        let hello_raw = conn.send_plain(&hello).await?;
        let (welcome, welcome_raw) = conn.recv_plain(self.timings.step_timeout).await?;
        let Handshake::Welcome { version, device } = welcome else {
            return Err(SessionFault::Protocol("expected welcome").into());
        };
        if version != PROTOCOL_VERSION {
            return Err(SessionFault::Version(version).into());
        }
        let device = device.validated().map_err(SessionFault::from)?;
        if device.id == self.identity.id() {
            return Err(NodeError::SelfConnect);
        }
        let mut transcript = Transcript::new();
        transcript.absorb(&hello_raw);
        transcript.absorb(&welcome_raw);
        Ok(Dialed {
            conn,
            device,
            addr,
            transcript,
        })
    }
}

async fn browse_loop(shared: Arc<Shared>, events: Receiver<mdns_sd::ServiceEvent>) {
    loop {
        let event = tokio::select! {
            () = shared.shutdown.cancelled() => break,
            event = events.recv_async() => match event {
                Ok(event) => event,
                Err(_) => break,
            },
        };
        shared.on_service_event(event);
    }
}

async fn accept_loop(shared: Arc<Shared>, listener: TcpListener) {
    let limit = Arc::new(Semaphore::new(MAX_INBOUND));
    loop {
        let accepted = tokio::select! {
            () = shared.shutdown.cancelled() => break,
            accepted = listener.accept() => accepted,
        };
        match accepted {
            Ok((stream, addr)) => {
                let Ok(permit) = Arc::clone(&limit).try_acquire_owned() else {
                    log::warn!("too many connections; refusing {addr}");
                    continue;
                };
                let task_shared = Arc::clone(&shared);
                shared.tracker.spawn(async move {
                    let _permit = permit;
                    if let Err(e) = handle_inbound(task_shared, stream, addr).await {
                        log::debug!("inbound connection from {addr} failed: {e}");
                    }
                });
            }
            Err(e) => {
                log::warn!("accept failed: {e}");
                tokio::time::sleep(Duration::from_millis(200)).await;
            }
        }
    }
    // Dropping the listener here releases the port.
}

/// Answers `Hello`; for session requests, runs the display state machine.
async fn handle_inbound(
    shared: Arc<Shared>,
    stream: TcpStream,
    addr: SocketAddr,
) -> Result<(), SessionFault> {
    let mut conn = Conn::new(stream);
    let (hello, hello_raw) = conn.recv_plain(shared.timings.step_timeout).await?;
    let Handshake::Hello {
        version,
        purpose,
        device,
    } = hello
    else {
        return Err(SessionFault::Protocol("expected hello"));
    };
    let welcome = Handshake::Welcome {
        version: PROTOCOL_VERSION,
        device: shared.local_hello(),
    };
    let welcome_raw = conn.send_plain(&welcome).await?;
    if version != PROTOCOL_VERSION {
        return Err(SessionFault::Version(version));
    }
    let device = device.validated()?;
    if device.id == shared.identity.id() {
        return Err(SessionFault::Protocol("connection from this device itself"));
    }
    match purpose {
        Purpose::Info => {
            conn.linger(shared.timings.linger).await;
            Ok(())
        }
        Purpose::Session => {
            let mut transcript = Transcript::new();
            transcript.absorb(&hello_raw);
            transcript.absorb(&welcome_raw);
            let (id, commands) = shared.register_session();
            Session::new(
                Arc::clone(&shared),
                id,
                SessionRole::Display,
                ShareMode::Mirror,
                device,
                addr,
                conn,
                commands,
            )
            .run(transcript)
            .await;
            Ok(())
        }
    }
}
