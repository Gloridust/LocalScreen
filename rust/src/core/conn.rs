//! A framed TCP connection that switches to encrypted frames mid-stream.
//!
//! A background reader task turns the read half into a queue of raw frames,
//! so the session loop can `select!` on frames, commands and timers without
//! cancelling a half-read frame. Frames are decoded in the session task,
//! which knows exactly when the connection switches from plaintext
//! [`Handshake`] to encrypted [`Secure`] messages.

use std::time::Duration;

use tokio::io::AsyncWriteExt;
use tokio::net::tcp::OwnedWriteHalf;
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use tokio::time::Instant;

use crate::api::types::SessionRole;
use crate::core::channel::{Opener, Sealer, SessionKeys, OVERHEAD};
use crate::core::frame::{read_frame, write_frame, FrameError, MAX_FRAME_LEN};
use crate::core::wire::{self, Handshake, Secure, WireClose};
use crate::core::SessionFault;

const FRAME_QUEUE: usize = 8;

/// A decoded incoming frame.
#[derive(Debug)]
pub enum Incoming {
    /// Plaintext handshake message with its raw bytes (for the transcript).
    Plain(Handshake, Vec<u8>),
    Secure(Secure),
}

pub struct Conn {
    writer: OwnedWriteHalf,
    frames: mpsc::Receiver<Result<Vec<u8>, FrameError>>,
    reader: JoinHandle<()>,
    crypto: Option<(Sealer, Opener)>,
    last_rx: Instant,
    last_tx: Instant,
}

impl Drop for Conn {
    fn drop(&mut self) {
        self.reader.abort();
    }
}

impl Conn {
    /// Wraps a connected stream. Must be called inside a tokio runtime.
    pub fn new(stream: TcpStream) -> Self {
        if let Err(e) = stream.set_nodelay(true) {
            log::debug!("cannot set TCP_NODELAY: {e}");
        }
        let (mut read_half, writer) = stream.into_split();
        let (tx, frames) = mpsc::channel(FRAME_QUEUE);
        let reader = tokio::spawn(async move {
            loop {
                let frame = read_frame(&mut read_half).await;
                let failed = frame.is_err();
                if tx.send(frame).await.is_err() || failed {
                    break;
                }
            }
        });
        let now = Instant::now();
        Self {
            writer,
            frames,
            reader,
            crypto: None,
            last_rx: now,
            last_tx: now,
        }
    }

    pub fn is_encrypted(&self) -> bool {
        self.crypto.is_some()
    }

    pub fn last_rx(&self) -> Instant {
        self.last_rx
    }

    pub fn last_tx(&self) -> Instant {
        self.last_tx
    }

    /// Switches both directions to encrypted frames.
    pub fn enable_encryption(&mut self, keys: SessionKeys, role: SessionRole) {
        self.crypto = Some(keys.into_channel(role));
    }

    /// Sends a plaintext handshake message; returns its bytes for the transcript.
    pub async fn send_plain(&mut self, message: &Handshake) -> Result<Vec<u8>, SessionFault> {
        if self.crypto.is_some() {
            return Err(SessionFault::Protocol("plaintext after encryption"));
        }
        let bytes = wire::encode(message)?;
        write_frame(&mut self.writer, &bytes).await?;
        self.last_tx = Instant::now();
        Ok(bytes)
    }

    /// Seals and sends a message on the encrypted channel.
    pub async fn send_secure(&mut self, message: &Secure) -> Result<(), SessionFault> {
        let Some((sealer, _)) = self.crypto.as_mut() else {
            return Err(SessionFault::Protocol(
                "encrypted message before key agreement",
            ));
        };
        let plaintext = wire::encode(message)?;
        // Checked before sealing so an oversized message does not consume a
        // counter value and desynchronise the channel.
        if plaintext.len() + OVERHEAD > MAX_FRAME_LEN {
            return Err(FrameError::TooLarge(plaintext.len() + OVERHEAD).into());
        }
        let frame = sealer.seal(&plaintext)?;
        write_frame(&mut self.writer, &frame).await?;
        self.last_tx = Instant::now();
        Ok(())
    }

    /// Waits for the next raw frame. Cancel-safe.
    pub async fn recv_raw(&mut self) -> Result<Vec<u8>, SessionFault> {
        let frame = match self.frames.recv().await {
            Some(frame) => frame?,
            None => return Err(FrameError::Closed.into()),
        };
        self.last_rx = Instant::now();
        Ok(frame)
    }

    /// Decodes a raw frame according to the current phase.
    pub fn decode(&mut self, frame: &[u8]) -> Result<Incoming, SessionFault> {
        match self.crypto.as_mut() {
            Some((_, opener)) => {
                let plaintext = opener.open(frame)?;
                Ok(Incoming::Secure(wire::decode(&plaintext)?))
            }
            None => Ok(Incoming::Plain(wire::decode(frame)?, frame.to_vec())),
        }
    }

    /// Waits for one plaintext handshake message (used before a session exists).
    pub async fn recv_plain(
        &mut self,
        timeout: Duration,
    ) -> Result<(Handshake, Vec<u8>), SessionFault> {
        let frame = tokio::time::timeout(timeout, self.recv_raw())
            .await
            .map_err(|_| SessionFault::Timeout)??;
        match self.decode(&frame)? {
            Incoming::Plain(message, raw) => Ok((message, raw)),
            Incoming::Secure(_) => Err(SessionFault::Protocol("unexpected encrypted frame")),
        }
    }

    /// Best-effort goodbye before closing.
    pub async fn send_farewell(&mut self, reason: WireClose) {
        let sent = if self.is_encrypted() {
            self.send_secure(&Secure::Close { reason }).await
        } else {
            self.send_plain(&Handshake::Close { reason })
                .await
                .map(drop)
        };
        if let Err(e) = sent {
            log::debug!("could not send close: {e}");
        }
    }

    /// Half-closes, then waits up to `linger` for the peer to close too, so a
    /// just-sent goodbye is not destroyed by a TCP reset.
    pub async fn linger(mut self, linger: Duration) {
        if self.writer.shutdown().await.is_err() {
            return;
        }
        let drain = async { while let Some(Ok(_)) = self.frames.recv().await {} };
        let _ = tokio::time::timeout(linger, drain).await;
    }
}
