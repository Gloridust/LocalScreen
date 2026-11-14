//! Where the node delivers [`NodeEvent`]s.

use crate::api::types::NodeEvent;

/// Receiver of node events.
///
/// The bridge implements this for the Dart `StreamSink`; tests use an
/// unbounded tokio channel. Implementations must not block.
pub trait EventSink: Send + Sync + 'static {
    fn emit(&self, event: NodeEvent);
}

impl EventSink for tokio::sync::mpsc::UnboundedSender<NodeEvent> {
    fn emit(&self, event: NodeEvent) {
        // A dropped receiver just means nobody is listening any more.
        let _ = self.send(event);
    }
}
