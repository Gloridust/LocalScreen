//! Per-session state machines.
//!
//! Each session is one TCP connection driven by one task. The host
//! (initiator) and display (responder) flows below implement this exchange
//! after `Hello`/`Welcome` (see [`crate::core::wire`] for message fields and
//! [`crate::core::pairing`] for the cryptography):
//!
//! ```text
//! H → D  SessionRequest{mode, auth: pin | trusted{n_h}}
//!
//! trusted (both sides hold a secret for each other's id + key):
//! D → H  TrustChallenge{n_d, proof_d}
//! H → D  TrustProof{proof_h}            (or TrustFailed → PIN flow)
//! D → H  TrustAccepted                  (or PinRequired  → PIN flow)
//!        ... encrypted from here; D asks its user ...
//! D → H  Accept | Close{declined | timeout}
//!
//! PIN (otherwise):
//! D → H  PinRequired{attempts_left}     D shows the PIN
//!   per guess, a fresh SPAKE2 exchange:
//!   H → D  PinAttempt{msg_a}
//!   D → H  PinReply{msg_b}
//!   H → D  PinConfirm{mac_h, sig_h}
//!   D → H  PinRejected{attempts_left} | PinAccepted{mac_d, sig_d} | Close{pin_failed}
//!        ... encrypted from here, trust secret persisted on both sides ...
//!
//! established: Signal{payload} both ways, Ping/Pong keepalive, Close{reason}
//! ```

use std::convert::Infallible;
use std::net::SocketAddr;
use std::sync::Arc;

use tokio::sync::{mpsc, oneshot};
use tokio::time::Instant;

use crate::api::types::{CloseReason, NodeEvent, SessionRole, ShareMode};
use crate::core::channel::{ChannelError, OVERHEAD};
use crate::core::conn::{Conn, Incoming};
use crate::core::frame::{FrameError, MAX_FRAME_LEN};
use crate::core::identity;
use crate::core::node::Shared;
use crate::core::pairing::{
    display_respond, generate_pin, normalize_pin, random_nonce, trust_proof, trusted_session_keys,
    verify_trust_proof, HostAttempt, PairingError, PinGuard, PinKeys, Transcript,
};
use crate::core::wire::{AuthMethod, DeviceHello, Handshake, Secure, WireClose, WireError};
use crate::core::{NodeError, SessionFault};

/// Rough upper bound for a signalling payload (JSON escaping can shrink it).
pub const MAX_SIGNAL_BYTES: usize = MAX_FRAME_LEN - OVERHEAD - 64;

/// Extra time the host waits beyond the display's own deadline, so the
/// display's verdict normally arrives first.
const HOST_GRACE: std::time::Duration = std::time::Duration::from_secs(15);

pub(crate) type Reply = oneshot::Sender<Result<(), NodeError>>;

/// Messages from the API to a session task.
pub(crate) enum Command {
    Request(Request),
    /// Hang up; the sender is notified once the session is closed.
    Close(oneshot::Sender<()>),
}

pub(crate) enum Request {
    SubmitPin { pin: String, reply: Reply },
    Respond { accept: bool, reply: Reply },
    Signal { payload: String, reply: Reply },
}

impl Request {
    fn reply(self, result: Result<(), NodeError>) {
        let reply = match self {
            Self::SubmitPin { reply, .. }
            | Self::Respond { reply, .. }
            | Self::Signal { reply, .. } => reply,
        };
        // The caller may have given up waiting; nothing to do then.
        let _ = reply.send(result);
    }

    /// Rejects a request that does not apply to the current phase.
    fn reject(self) {
        let why = match &self {
            Self::SubmitPin { .. } => "this session is not waiting for a PIN",
            Self::Respond { .. } => "this session is not waiting for an answer",
            Self::Signal { .. } => "the session is not established yet",
        };
        self.reply(Err(NodeError::InvalidState(why)));
    }
}

/// How a session ended, from this side's point of view.
#[derive(Debug)]
enum End {
    Local,
    Shutdown,
    Declined,
    Timeout,
    PinFailed,
    Remote(WireClose),
    Fault(SessionFault),
}

impl From<SessionFault> for End {
    fn from(fault: SessionFault) -> Self {
        Self::Fault(fault)
    }
}

macro_rules! end_from_fault {
    ($($error:ty),*) => {$(
        impl From<$error> for End {
            fn from(error: $error) -> Self {
                Self::Fault(error.into())
            }
        }
    )*};
}
end_from_fault!(FrameError, ChannelError, WireError, PairingError);

fn protocol(what: &'static str) -> End {
    End::Fault(SessionFault::Protocol(what))
}

/// A flow only ever ends with an [`End`].
type Flow = Result<Infallible, End>;

enum Input {
    Message(Incoming),
    Request(Request),
    Deadline,
}

enum Wake {
    Shutdown,
    Command(Option<Command>),
    Frame(Result<Vec<u8>, SessionFault>),
    Deadline,
    Ping,
    Idle,
}

async fn sleep_until_opt(deadline: Option<Instant>) {
    match deadline {
        Some(deadline) => tokio::time::sleep_until(deadline).await,
        None => std::future::pending().await,
    }
}

pub(crate) struct Session {
    shared: Arc<Shared>,
    id: String,
    role: SessionRole,
    mode: ShareMode,
    peer: DeviceHello,
    addr: SocketAddr,
    conn: Conn,
    commands: mpsc::Receiver<Command>,
    close_waiters: Vec<oneshot::Sender<()>>,
}

impl Session {
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(
        shared: Arc<Shared>,
        id: String,
        role: SessionRole,
        mode: ShareMode,
        peer: DeviceHello,
        addr: SocketAddr,
        conn: Conn,
        commands: mpsc::Receiver<Command>,
    ) -> Self {
        Self {
            shared,
            id,
            role,
            mode,
            peer,
            addr,
            conn,
            commands,
            close_waiters: Vec::new(),
        }
    }

    /// Drives the session to completion and reports how it ended.
    pub(crate) async fn run(mut self, transcript: Transcript) {
        let flow = match self.role {
            SessionRole::Host => self.host(transcript).await,
            SessionRole::Display => self.display(transcript).await,
        };
        let end = match flow {
            Err(end) => end,
            Ok(never) => match never {},
        };
        self.finish(end).await;
    }

    // ----- shared plumbing -------------------------------------------------

    fn emit(&self, event: NodeEvent) {
        self.shared.events.emit(event);
    }

    fn emit_established(&self) {
        log::info!("session {} established with {}", self.id, self.peer.id);
        self.emit(NodeEvent::SessionEstablished {
            session_id: self.id.clone(),
            peer: self.shared.peer_info(&self.peer, self.addr),
            role: self.role,
            mode: self.mode,
        });
    }

    /// Next input for the current phase. Handles hang-ups, shutdown,
    /// keepalives and peer `Close` messages itself.
    async fn next(&mut self, deadline: Option<Instant>) -> Result<Input, End> {
        loop {
            let timings = self.shared.timings;
            let keepalive = self.conn.is_encrypted();
            let ping_at = self.conn.last_tx() + timings.keepalive_interval;
            let idle_at = self.conn.last_rx() + timings.idle_timeout;
            let wake = tokio::select! {
                biased;
                () = self.shared.shutdown.cancelled() => Wake::Shutdown,
                command = self.commands.recv() => Wake::Command(command),
                frame = self.conn.recv_raw() => Wake::Frame(frame),
                () = sleep_until_opt(deadline) => Wake::Deadline,
                () = tokio::time::sleep_until(ping_at), if keepalive => Wake::Ping,
                () = tokio::time::sleep_until(idle_at), if keepalive => Wake::Idle,
            };
            match wake {
                Wake::Shutdown | Wake::Command(None) => return Err(End::Shutdown),
                Wake::Command(Some(Command::Close(done))) => {
                    self.close_waiters.push(done);
                    return Err(End::Local);
                }
                Wake::Command(Some(Command::Request(request))) => {
                    return Ok(Input::Request(request))
                }
                Wake::Frame(frame) => match self.conn.decode(&frame?)? {
                    Incoming::Plain(Handshake::Close { reason }, _)
                    | Incoming::Secure(Secure::Close { reason }) => {
                        return Err(End::Remote(reason))
                    }
                    Incoming::Secure(Secure::Ping) => self.conn.send_secure(&Secure::Pong).await?,
                    Incoming::Secure(Secure::Pong) => {}
                    other => return Ok(Input::Message(other)),
                },
                Wake::Deadline => return Ok(Input::Deadline),
                Wake::Ping => self.conn.send_secure(&Secure::Ping).await?,
                Wake::Idle => return Err(SessionFault::Idle.into()),
            }
        }
    }

    /// Next handshake message, which must arrive within the step timeout.
    async fn step(&mut self) -> Result<Incoming, End> {
        let deadline = Instant::now() + self.shared.timings.step_timeout;
        loop {
            match self.next(Some(deadline)).await? {
                Input::Message(message) => return Ok(message),
                Input::Request(request) => request.reject(),
                Input::Deadline => return Err(SessionFault::Timeout.into()),
            }
        }
    }

    /// Sends a reply-bearing message, failing the request if sending fails.
    async fn send_for(&mut self, message: &Secure, request_reply: Reply) -> Result<(), End> {
        match self.conn.send_secure(message).await {
            Ok(()) => {
                let _ = request_reply.send(Ok(()));
                Ok(())
            }
            Err(e) => {
                let _ = request_reply.send(Err(NodeError::SessionEnded));
                Err(e.into())
            }
        }
    }

    async fn finish(mut self, end: End) {
        let (farewell, reason) = match &end {
            End::Local | End::Shutdown => (Some(WireClose::Hangup), CloseReason::LocalHangup),
            End::Declined => (Some(WireClose::Declined), CloseReason::LocalHangup),
            End::Timeout => (Some(WireClose::Timeout), CloseReason::Timeout),
            End::PinFailed => (Some(WireClose::PinFailed), CloseReason::PinFailed),
            End::Remote(close) => (None, close.remote_reason()),
            End::Fault(fault) => (
                fault.is_protocol().then_some(WireClose::Error),
                CloseReason::NetworkError,
            ),
        };
        match &end {
            End::Fault(fault) => {
                log::warn!("session {} with {} failed: {fault}", self.id, self.peer.id)
            }
            other => log::info!("session {} with {} ended: {other:?}", self.id, self.peer.id),
        }
        if let Some(farewell) = farewell {
            self.conn.send_farewell(farewell).await;
        }
        self.shared.unregister_session(&self.id);
        self.commands.close();
        while let Ok(command) = self.commands.try_recv() {
            match command {
                Command::Request(request) => request.reply(Err(NodeError::SessionEnded)),
                Command::Close(done) => self.close_waiters.push(done),
            }
        }
        self.emit(NodeEvent::SessionClosed {
            session_id: self.id.clone(),
            reason,
        });
        for waiter in self.close_waiters.drain(..) {
            let _ = waiter.send(());
        }
        self.conn.linger(self.shared.timings.linger).await;
    }

    // ----- host ------------------------------------------------------------

    async fn host(&mut self, mut transcript: Transcript) -> Flow {
        let secret = self.shared.trust_secret(&self.peer);
        let nonce_host = secret.map(|_| random_nonce());
        let auth = match nonce_host {
            Some(nonce) => AuthMethod::Trusted { nonce },
            None => AuthMethod::Pin,
        };
        let raw = self
            .conn
            .send_plain(&Handshake::SessionRequest {
                mode: self.mode.into(),
                auth,
            })
            .await?;
        transcript.absorb(&raw);
        let base = transcript.finish();

        if let (Some(secret), Some(nonce_host)) = (secret, nonce_host) {
            match self.step().await? {
                Incoming::Plain(Handshake::TrustChallenge { nonce, proof }, _) => {
                    let valid = verify_trust_proof(
                        &secret,
                        &base,
                        &nonce_host,
                        &nonce,
                        SessionRole::Display,
                        &proof,
                    );
                    if valid {
                        let proof =
                            trust_proof(&secret, &base, &nonce_host, &nonce, SessionRole::Host)?;
                        self.conn
                            .send_plain(&Handshake::TrustProof { proof })
                            .await?;
                        match self.step().await? {
                            Incoming::Plain(Handshake::TrustAccepted, _) => {
                                let keys =
                                    trusted_session_keys(&secret, &base, &nonce_host, &nonce)?;
                                self.conn.enable_encryption(keys, SessionRole::Host);
                                self.shared.refresh_trusted(&self.peer, self.addr);
                                return self.host_await_answer().await;
                            }
                            Incoming::Plain(Handshake::PinRequired { .. }, _) => {
                                log::info!("display {} rejected our trust proof", self.peer.id);
                            }
                            _ => return Err(protocol("expected the trust verdict")),
                        }
                    } else {
                        log::info!("trust proof of {} did not verify", self.peer.id);
                        self.conn.send_plain(&Handshake::TrustFailed).await?;
                        self.expect_pin_required().await?;
                    }
                }
                Incoming::Plain(Handshake::PinRequired { .. }, _) => {}
                _ => return Err(protocol("expected a trust challenge or PIN request")),
            }
        } else {
            self.expect_pin_required().await?;
        }
        self.host_pin(&base).await
    }

    async fn expect_pin_required(&mut self) -> Result<(), End> {
        match self.step().await? {
            Incoming::Plain(Handshake::PinRequired { .. }, _) => Ok(()),
            _ => Err(protocol("expected a PIN request")),
        }
    }

    /// Trusted flow: wait for the display user's answer.
    async fn host_await_answer(&mut self) -> Flow {
        let deadline = Instant::now() + self.shared.timings.request_timeout + HOST_GRACE;
        loop {
            match self.next(Some(deadline)).await? {
                Input::Deadline => return Err(End::Timeout),
                Input::Request(request) => request.reject(),
                Input::Message(Incoming::Secure(Secure::Accept)) => {
                    self.emit_established();
                    return self.established().await;
                }
                Input::Message(_) => return Err(protocol("unexpected message awaiting answer")),
            }
        }
    }

    /// PIN flow: one SPAKE2 exchange per `submit_pin`.
    async fn host_pin(&mut self, base: &[u8; 32]) -> Flow {
        self.emit(NodeEvent::PinRequired {
            session_id: self.id.clone(),
        });
        let deadline = Instant::now() + self.shared.timings.pin_lifetime + HOST_GRACE;
        let mut attempt: Option<HostAttempt> = None;
        let mut confirming: Option<PinKeys> = None;
        loop {
            match self.next(Some(deadline)).await? {
                Input::Deadline => return Err(End::Timeout),
                Input::Request(Request::SubmitPin { pin, reply }) => {
                    if attempt.is_some() || confirming.is_some() {
                        let _ = reply.send(Err(NodeError::InvalidState(
                            "a PIN attempt is already in progress",
                        )));
                        continue;
                    }
                    let Some(pin) = normalize_pin(&pin) else {
                        let _ = reply.send(Err(NodeError::InvalidPin));
                        continue;
                    };
                    let started =
                        HostAttempt::start(&pin, self.shared.identity.id(), &self.peer.id);
                    let message = Handshake::PinAttempt {
                        spake: started.message().to_vec(),
                    };
                    if let Err(e) = self.conn.send_plain(&message).await {
                        let _ = reply.send(Err(NodeError::SessionEnded));
                        return Err(e.into());
                    }
                    let _ = reply.send(Ok(()));
                    attempt = Some(started);
                }
                Input::Request(request) => request.reject(),
                Input::Message(Incoming::Plain(Handshake::PinReply { spake }, _)) => {
                    let Some(started) = attempt.take() else {
                        return Err(protocol("unexpected PIN reply"));
                    };
                    let keys = started.finish(base, &spake)?;
                    let mac = keys.mac(SessionRole::Host)?;
                    let signature = self
                        .shared
                        .identity
                        .sign(&keys.signing_payload(SessionRole::Host));
                    self.conn
                        .send_plain(&Handshake::PinConfirm { mac, signature })
                        .await?;
                    confirming = Some(keys);
                }
                Input::Message(Incoming::Plain(Handshake::PinRejected { attempts_left }, _)) => {
                    if confirming.take().is_none() {
                        return Err(protocol("unexpected PIN rejection"));
                    }
                    self.emit(NodeEvent::PinRejected {
                        session_id: self.id.clone(),
                        attempts_left,
                    });
                }
                Input::Message(Incoming::Plain(Handshake::PinAccepted { mac, signature }, _)) => {
                    let Some(keys) = confirming.take() else {
                        return Err(protocol("unexpected PIN acceptance"));
                    };
                    if !keys.verify_mac(SessionRole::Display, &mac) {
                        return Err(protocol("display failed key confirmation"));
                    }
                    let payload = keys.signing_payload(SessionRole::Display);
                    if !identity::verify(&self.peer.public_key, &payload, &signature) {
                        return Err(protocol("display identity signature is invalid"));
                    }
                    self.conn
                        .enable_encryption(keys.session_keys(), SessionRole::Host);
                    self.shared
                        .remember_trusted(&self.peer, self.addr, keys.trust_secret());
                    self.emit_established();
                    return self.established().await;
                }
                Input::Message(_) => return Err(protocol("unexpected message during pairing")),
            }
        }
    }

    // ----- display ---------------------------------------------------------

    async fn display(&mut self, mut transcript: Transcript) -> Flow {
        let (mode, auth) = match self.step().await? {
            Incoming::Plain(Handshake::SessionRequest { mode, auth }, raw) => {
                transcript.absorb(&raw);
                (mode, auth)
            }
            _ => return Err(protocol("expected a session request")),
        };
        self.mode = mode.into();
        let base = transcript.finish();

        if let AuthMethod::Trusted { nonce: nonce_host } = auth {
            if let Some(secret) = self.shared.trust_secret(&self.peer) {
                let nonce = random_nonce();
                let proof = trust_proof(&secret, &base, &nonce_host, &nonce, SessionRole::Display)?;
                self.conn
                    .send_plain(&Handshake::TrustChallenge { nonce, proof })
                    .await?;
                match self.step().await? {
                    Incoming::Plain(Handshake::TrustProof { proof }, _)
                        if verify_trust_proof(
                            &secret,
                            &base,
                            &nonce_host,
                            &nonce,
                            SessionRole::Host,
                            &proof,
                        ) =>
                    {
                        self.conn.send_plain(&Handshake::TrustAccepted).await?;
                        let keys = trusted_session_keys(&secret, &base, &nonce_host, &nonce)?;
                        self.conn.enable_encryption(keys, SessionRole::Display);
                        self.shared.refresh_trusted(&self.peer, self.addr);
                        return self.display_await_answer().await;
                    }
                    Incoming::Plain(Handshake::TrustProof { .. } | Handshake::TrustFailed, _) => {
                        log::info!("trust with {} failed; falling back to PIN", self.peer.id);
                    }
                    _ => return Err(protocol("expected a trust proof")),
                }
            }
        }
        self.display_pin(&base).await
    }

    /// Trusted flow: ask the local user.
    async fn display_await_answer(&mut self) -> Flow {
        self.emit(NodeEvent::IncomingRequest {
            session_id: self.id.clone(),
            peer: self.shared.peer_info(&self.peer, self.addr),
            mode: self.mode,
            pin: None,
        });
        let deadline = Instant::now() + self.shared.timings.request_timeout;
        loop {
            match self.next(Some(deadline)).await? {
                Input::Deadline => return Err(End::Timeout),
                Input::Request(Request::Respond {
                    accept: true,
                    reply,
                }) => {
                    self.send_for(&Secure::Accept, reply).await?;
                    self.emit_established();
                    return self.established().await;
                }
                Input::Request(Request::Respond {
                    accept: false,
                    reply,
                }) => {
                    let _ = reply.send(Ok(()));
                    return Err(End::Declined);
                }
                Input::Request(request) => request.reject(),
                Input::Message(_) => return Err(protocol("unexpected message awaiting answer")),
            }
        }
    }

    /// PIN flow: show a PIN and verify up to five guesses within its lifetime.
    async fn display_pin(&mut self, base: &[u8; 32]) -> Flow {
        let pin = generate_pin();
        let mut guard = PinGuard::new(self.shared.timings.pin_lifetime);
        self.emit(NodeEvent::IncomingRequest {
            session_id: self.id.clone(),
            peer: self.shared.peer_info(&self.peer, self.addr),
            mode: self.mode,
            pin: Some(pin.clone()),
        });
        self.conn
            .send_plain(&Handshake::PinRequired {
                attempts_left: guard.attempts_left(),
            })
            .await?;
        let mut pending: Option<PinKeys> = None;
        loop {
            match self.next(Some(guard.deadline())).await? {
                Input::Deadline => return Err(End::PinFailed),
                Input::Request(Request::Respond {
                    accept: false,
                    reply,
                }) => {
                    let _ = reply.send(Ok(()));
                    return Err(End::Declined);
                }
                Input::Request(Request::Respond {
                    accept: true,
                    reply,
                }) => {
                    let _ = reply.send(Err(NodeError::InvalidState(
                        "this request is accepted by entering the PIN on the host",
                    )));
                }
                Input::Request(request) => request.reject(),
                Input::Message(Incoming::Plain(Handshake::PinAttempt { spake }, _)) => {
                    if pending.is_some() {
                        return Err(protocol("overlapping PIN attempts"));
                    }
                    let (reply, keys) = display_respond(
                        &pin,
                        &self.peer.id,
                        self.shared.identity.id(),
                        base,
                        &spake,
                    )?;
                    self.conn
                        .send_plain(&Handshake::PinReply { spake: reply })
                        .await?;
                    pending = Some(keys);
                }
                Input::Message(Incoming::Plain(Handshake::PinConfirm { mac, signature }, _)) => {
                    let Some(keys) = pending.take() else {
                        return Err(protocol("PIN confirmation without an attempt"));
                    };
                    if !keys.verify_mac(SessionRole::Host, &mac) {
                        let attempts_left = guard.record_failure();
                        log::info!(
                            "wrong PIN from {}; {attempts_left} attempts left",
                            self.peer.id
                        );
                        if attempts_left == 0 {
                            return Err(End::PinFailed);
                        }
                        self.conn
                            .send_plain(&Handshake::PinRejected { attempts_left })
                            .await?;
                        continue;
                    }
                    let payload = keys.signing_payload(SessionRole::Host);
                    if !identity::verify(&self.peer.public_key, &payload, &signature) {
                        return Err(protocol("host identity signature is invalid"));
                    }
                    let mac = keys.mac(SessionRole::Display)?;
                    let signature = self
                        .shared
                        .identity
                        .sign(&keys.signing_payload(SessionRole::Display));
                    self.conn
                        .send_plain(&Handshake::PinAccepted { mac, signature })
                        .await?;
                    self.conn
                        .enable_encryption(keys.session_keys(), SessionRole::Display);
                    self.shared
                        .remember_trusted(&self.peer, self.addr, keys.trust_secret());
                    self.emit_established();
                    return self.established().await;
                }
                Input::Message(_) => return Err(protocol("unexpected message during pairing")),
            }
        }
    }

    // ----- established -----------------------------------------------------

    async fn established(&mut self) -> Flow {
        loop {
            match self.next(None).await? {
                Input::Request(Request::Signal { payload, reply }) => {
                    let message = Secure::Signal { payload };
                    match self.conn.send_secure(&message).await {
                        Ok(()) => {
                            let _ = reply.send(Ok(()));
                        }
                        Err(SessionFault::Frame(FrameError::TooLarge(_))) => {
                            let _ = reply.send(Err(NodeError::PayloadTooLarge(MAX_SIGNAL_BYTES)));
                        }
                        Err(e) => {
                            let _ = reply.send(Err(NodeError::SessionEnded));
                            return Err(e.into());
                        }
                    }
                }
                Input::Request(request @ (Request::SubmitPin { .. } | Request::Respond { .. })) => {
                    request.reply(Err(NodeError::InvalidState(
                        "the session is already established",
                    )));
                }
                Input::Message(Incoming::Secure(Secure::Signal { payload })) => {
                    self.emit(NodeEvent::Signal {
                        session_id: self.id.clone(),
                        payload,
                    });
                }
                Input::Message(_) => return Err(protocol("unexpected message in session")),
                Input::Deadline => {}
            }
        }
    }
}
