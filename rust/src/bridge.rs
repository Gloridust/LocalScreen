//! Glue between the flutter_rust_bridge facade and the core node.
//!
//! - All core work runs on a dedicated multi-threaded tokio runtime owned
//!   here, so node tasks (listener, sessions, discovery) never depend on the
//!   lifetime or flavour of the executor frb uses to poll `async fn`s.
//! - A single global [`Node`] backs the Dart API. `start` replaces a running
//!   node cleanly (useful after a Flutter hot restart), `stop` is idempotent.

use std::future::Future;
use std::sync::{Arc, OnceLock};

use anyhow::{anyhow, Context};
use tokio::runtime::Runtime;
use tokio::sync::Mutex;

use crate::api::types::{NodeConfig, NodeEvent};
use crate::core::{EventSink, Node, NodeError, NodeOptions};
use crate::frb_generated::StreamSink;

static RUNTIME: OnceLock<Option<Runtime>> = OnceLock::new();
static NODE: Mutex<Option<Node>> = Mutex::const_new(None);

fn runtime() -> anyhow::Result<&'static Runtime> {
    RUNTIME
        .get_or_init(|| {
            tokio::runtime::Builder::new_multi_thread()
                .worker_threads(2)
                .thread_name("localscreen-core")
                .enable_all()
                .build()
                .map_err(|e| log::error!("cannot create the core runtime: {e}"))
                .ok()
        })
        .as_ref()
        .ok_or_else(|| anyhow!("the core runtime could not be created"))
}

/// Runs `work` on the core runtime and waits for it.
async fn on_runtime<T, F>(work: F) -> anyhow::Result<T>
where
    T: Send + 'static,
    F: Future<Output = anyhow::Result<T>> + Send + 'static,
{
    runtime()?
        .spawn(work)
        .await
        .context("core task panicked or was cancelled")?
}

/// Forwards node events into the Dart stream.
struct DartSink(StreamSink<NodeEvent>);

impl EventSink for DartSink {
    fn emit(&self, event: NodeEvent) {
        if self.0.add(event).is_err() {
            log::debug!("Dart event stream is closed; dropping event");
        }
    }
}

pub async fn start(config: NodeConfig, events: StreamSink<NodeEvent>) -> anyhow::Result<()> {
    on_runtime(async move {
        let mut slot = NODE.lock().await;
        if let Some(previous) = slot.take() {
            previous.shutdown().await;
        }
        let node = Node::start(NodeOptions::new(config), Arc::new(DartSink(events))).await?;
        *slot = Some(node);
        Ok(())
    })
    .await
}

pub async fn stop() -> anyhow::Result<()> {
    on_runtime(async move {
        let node = NODE.lock().await.take();
        if let Some(node) = node {
            node.shutdown().await;
        }
        Ok(())
    })
    .await
}

/// Runs `work` against the global node, failing if it is not running.
pub async fn with_node<T, F, Fut>(work: F) -> anyhow::Result<T>
where
    T: Send + 'static,
    F: FnOnce(Node) -> Fut + Send + 'static,
    Fut: Future<Output = Result<T, NodeError>> + Send,
{
    on_runtime(async move {
        let node = NODE.lock().await.clone().ok_or(NodeError::NotRunning)?;
        Ok(work(node).await?)
    })
    .await
}
