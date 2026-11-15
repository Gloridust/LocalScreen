//! Public surface exposed to Dart through flutter_rust_bridge.
//!
//! Everything under `api` is a thin, stable facade. Real logic lives in the
//! sibling `core` modules so it can be tested without the bridge.

pub mod node;
pub mod types;
