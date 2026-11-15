//! Length-prefixed framing for the TCP control channel.
//!
//! A frame is a 4-byte big-endian payload length followed by the payload.
//! Payloads larger than [`MAX_FRAME_LEN`] are rejected before any allocation.
//! Waiting for the *start* of a frame has no timeout (idleness is policed by
//! the session layer), but once a header has arrived the body must follow
//! within [`IO_TIMEOUT`]; writes are bounded by the same timeout.

use std::io;
use std::time::Duration;

use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};

/// Largest accepted frame payload (1 MiB). Signalling payloads are a few KiB.
pub const MAX_FRAME_LEN: usize = 1024 * 1024;

/// Upper bound for reading the rest of a started frame or writing a frame.
pub const IO_TIMEOUT: Duration = Duration::from_secs(10);

const HEADER_LEN: usize = 4;

#[derive(Debug, thiserror::Error)]
pub enum FrameError {
    #[error("connection closed by peer")]
    Closed,
    #[error("frame of {0} bytes exceeds the {MAX_FRAME_LEN} byte limit")]
    TooLarge(usize),
    #[error("timed out transferring a frame")]
    Timeout,
    #[error("i/o error: {0}")]
    Io(#[from] io::Error),
}

/// Reads one frame. Returns [`FrameError::Closed`] on a clean EOF between frames.
pub async fn read_frame<R: AsyncRead + Unpin>(reader: &mut R) -> Result<Vec<u8>, FrameError> {
    let mut header = [0u8; HEADER_LEN];
    let first = reader.read(&mut header).await?;
    if first == 0 {
        return Err(FrameError::Closed);
    }
    let body = async {
        reader.read_exact(&mut header[first..]).await?;
        let len = u32::from_be_bytes(header) as usize;
        if len > MAX_FRAME_LEN {
            return Err(FrameError::TooLarge(len));
        }
        let mut payload = vec![0u8; len];
        reader.read_exact(&mut payload).await?;
        Ok(payload)
    };
    tokio::time::timeout(IO_TIMEOUT, body)
        .await
        .map_err(|_| FrameError::Timeout)?
}

/// Writes one frame and flushes it.
pub async fn write_frame<W: AsyncWrite + Unpin>(
    writer: &mut W,
    payload: &[u8],
) -> Result<(), FrameError> {
    if payload.len() > MAX_FRAME_LEN {
        return Err(FrameError::TooLarge(payload.len()));
    }
    let mut buf = Vec::with_capacity(HEADER_LEN + payload.len());
    // Cannot truncate: MAX_FRAME_LEN fits in a u32.
    buf.extend_from_slice(&(payload.len() as u32).to_be_bytes());
    buf.extend_from_slice(payload);
    let write = async {
        writer.write_all(&buf).await?;
        writer.flush().await
    };
    tokio::time::timeout(IO_TIMEOUT, write)
        .await
        .map_err(|_| FrameError::Timeout)??;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn round_trips_frames() {
        let (mut a, mut b) = tokio::io::duplex(64);
        let writer = tokio::spawn(async move {
            write_frame(&mut a, b"hello").await.unwrap();
            write_frame(&mut a, b"").await.unwrap();
            write_frame(&mut a, &[7u8; 300]).await.unwrap();
        });
        assert_eq!(read_frame(&mut b).await.unwrap(), b"hello");
        assert_eq!(read_frame(&mut b).await.unwrap(), b"");
        assert_eq!(read_frame(&mut b).await.unwrap(), vec![7u8; 300]);
        writer.await.unwrap();
        assert!(matches!(read_frame(&mut b).await, Err(FrameError::Closed)));
    }

    #[tokio::test]
    async fn rejects_oversized_header() {
        let (mut a, mut b) = tokio::io::duplex(64);
        let len = (MAX_FRAME_LEN as u32 + 1).to_be_bytes();
        a.write_all(&len).await.unwrap();
        assert!(matches!(
            read_frame(&mut b).await,
            Err(FrameError::TooLarge(n)) if n == MAX_FRAME_LEN + 1
        ));
    }

    #[tokio::test]
    async fn refuses_to_write_oversized_frame() {
        let (mut a, _b) = tokio::io::duplex(64);
        let big = vec![0u8; MAX_FRAME_LEN + 1];
        assert!(matches!(
            write_frame(&mut a, &big).await,
            Err(FrameError::TooLarge(_))
        ));
    }

    #[tokio::test]
    async fn truncated_body_is_an_error() {
        let (mut a, mut b) = tokio::io::duplex(64);
        a.write_all(&10u32.to_be_bytes()).await.unwrap();
        a.write_all(b"abc").await.unwrap();
        drop(a);
        assert!(matches!(read_frame(&mut b).await, Err(FrameError::Io(_))));
    }

    #[tokio::test(start_paused = true)]
    async fn stalled_body_times_out() {
        let (mut a, mut b) = tokio::io::duplex(64);
        a.write_all(&10u32.to_be_bytes()).await.unwrap();
        let res = read_frame(&mut b).await;
        assert!(matches!(res, Err(FrameError::Timeout)));
        drop(a);
    }
}
