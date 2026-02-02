// Valtio + event-graph-walker Integration
//
// Synchronizes Valtio proxy state with event-graph-walker CRDT
// Similar to valtio-y but for eg-walker sequence CRDT

///|
/// Integration State
/// Manages bidirectional sync between Valtio and eg-walker Document
pub struct EgWalkerProxy {
  /// The Valtio proxy for reactive UI state
  proxy_state : ValtioProxy
  /// The underlying CRDT document
  doc : CRDTDocument
  /// Pending operations buffer for batching
  mut pending_ops : Array[CRDTOperation]
  /// Whether we're currently applying remote changes (prevent loops)
  mut is_applying_remote : Bool
  /// Subscription handle for cleanup
  mut subscription : ValtioSubscription?
  /// Whether undo/redo is enabled (uses UndoManager via crdt module FFI)
  undo_enabled : Bool
  /// JSON ops from last undo/redo call, for peer sync
  mut undo_sync_ops : String
}

///|
/// Constructor
/// Create a new EgWalker proxy with optional undo support
pub fn EgWalkerProxy::new(
  agent_id : String,
  undo_enabled? : Bool = false,
) -> EgWalkerProxy {
  let doc = if undo_enabled {
    create_document_with_undo(agent_id, 500)
  } else {
    create_document(agent_id)
  }
  let proxy_state = create_text_proxy("")
  {
    proxy_state,
    doc,
    pending_ops: [],
    is_applying_remote: false,
    subscription: None,
    undo_enabled,
    undo_sync_ops: "[]",
  }
}

///|
/// Text Proxy Creation
/// Create a Valtio proxy with text state
fn create_text_proxy(initial_text : String) -> ValtioProxy {
  let state = js_object()
  set_string(state, "text", initial_text)
  set_int(state, "cursor", 0)
  set_bool(state, "syncing", false)
  proxy(state)
}

///|
/// Initialization
/// Set up bidirectional sync between proxy and document
pub fn EgWalkerProxy::init(self : EgWalkerProxy) -> Unit {
  // Subscribe to proxy changes
  let sub = subscribe(self.proxy_state, fn() {
    if not(self.is_applying_remote) {
      self.handle_proxy_change()
    }
  })
  self.subscription = Some(sub)
}

///|
/// Proxy Change Handler
/// Called when Valtio proxy is mutated
fn EgWalkerProxy::handle_proxy_change(self : EgWalkerProxy) -> Unit {
  let new_text = get_string(self.proxy_state, "text")
  if self.undo_enabled {
    // Use UndoManager-integrated path: diff + record via crdt module
    let old_text = document_get_text(self.doc)
    if new_text == old_text {
      return
    }
    let ts = get_timestamp_ms()
    document_set_text_and_record(self.doc, new_text, ts)
  } else {
    // Original path: diff + apply to local CRDT document
    let old_text = document_to_text(self.doc)
    if new_text == old_text {
      return
    }
    let ops = calculate_diff(old_text, new_text)
    for op in ops {
      match op {
        DiffOp::Insert(pos, text) => {
          let crdt_op = document_insert(self.doc, pos, text)
          self.pending_ops.push(crdt_op)
        }
        DiffOp::Delete(pos, len) =>
          for i = 0; i < len; i = i + 1 {
            let crdt_op = document_delete(self.doc, pos)
            self.pending_ops.push(crdt_op)
          }
      }
    }
  }

  // Update cursor position
  let cursor = get_int(self.proxy_state, "cursor")
  set_int(self.proxy_state, "cursor", cursor)
}

///|
/// Remote Operation Handler
/// Apply remote CRDT operations to the proxy
pub fn EgWalkerProxy::apply_remote(
  self : EgWalkerProxy,
  op : CRDTOperation,
) -> Unit {
  self.is_applying_remote = true

  // Disable undo tracking during remote op application
  if self.undo_enabled {
    undo_manager_set_tracking(self.doc, false)
  }

  // Apply to CRDT document
  document_apply_remote(self.doc, op)

  // Re-enable undo tracking
  if self.undo_enabled {
    undo_manager_set_tracking(self.doc, true)
  }

  // Sync to Valtio proxy
  let new_text = if self.undo_enabled {
    document_get_text(self.doc)
  } else {
    document_to_text(self.doc)
  }
  set_string(self.proxy_state, "text", new_text)
  self.is_applying_remote = false
}

///|
/// Batch Remote Operations
/// Apply multiple remote operations efficiently
pub fn EgWalkerProxy::apply_remote_batch(
  self : EgWalkerProxy,
  ops : Array[CRDTOperation],
) -> Unit {
  self.is_applying_remote = true

  // Disable undo tracking during remote op application
  if self.undo_enabled {
    undo_manager_set_tracking(self.doc, false)
  }

  // Apply each operation
  for op in ops {
    document_apply_remote(self.doc, op)
  }

  // Re-enable undo tracking
  if self.undo_enabled {
    undo_manager_set_tracking(self.doc, true)
  }

  // Sync to Valtio proxy
  let new_text = if self.undo_enabled {
    document_get_text(self.doc)
  } else {
    document_to_text(self.doc)
  }
  set_string(self.proxy_state, "text", new_text)
  self.is_applying_remote = false
}

///|
/// Undo the last local operation group
/// Uses UndoManager via crdt module FFI when enabled
/// Returns JSON string of ops for peer sync (stored in undo_sync_ops)
pub fn EgWalkerProxy::undo(self : EgWalkerProxy) -> Unit {
  if not(self.undo_enabled) {
    return
  }
  self.is_applying_remote = true
  let ops_json = undo_manager_undo(self.doc)
  self.undo_sync_ops = ops_json
  // Update proxy text from document
  let new_text = document_get_text(self.doc)
  set_string(self.proxy_state, "text", new_text)
  self.is_applying_remote = false
}

///|
/// Redo the last undone operation group
/// Uses UndoManager via crdt module FFI when enabled
/// Returns JSON string of ops for peer sync (stored in undo_sync_ops)
pub fn EgWalkerProxy::redo(self : EgWalkerProxy) -> Unit {
  if not(self.undo_enabled) {
    return
  }
  self.is_applying_remote = true
  let ops_json = undo_manager_redo(self.doc)
  self.undo_sync_ops = ops_json
  // Update proxy text from document
  let new_text = document_get_text(self.doc)
  set_string(self.proxy_state, "text", new_text)
  self.is_applying_remote = false
}

///|
/// Check if undo is possible
pub fn EgWalkerProxy::can_undo(self : EgWalkerProxy) -> Bool {
  if not(self.undo_enabled) {
    return false
  }
  undo_manager_can_undo(self.doc)
}

///|
/// Check if redo is possible
pub fn EgWalkerProxy::can_redo(self : EgWalkerProxy) -> Bool {
  if not(self.undo_enabled) {
    return false
  }
  undo_manager_can_redo(self.doc)
}

///|
/// Get the last undo/redo sync ops JSON and clear it
pub fn EgWalkerProxy::get_undo_sync_ops(self : EgWalkerProxy) -> String {
  let ops = self.undo_sync_ops
  self.undo_sync_ops = "[]"
  ops
}

///|
/// Operation Access
/// Get pending operations for network sync
pub fn EgWalkerProxy::get_pending_ops(
  self : EgWalkerProxy,
) -> Array[CRDTOperation] {
  let ops = self.pending_ops
  self.pending_ops = []
  ops
}

///|
/// Get the current CRDT frontier as JSON
pub fn EgWalkerProxy::get_frontier_json(self : EgWalkerProxy) -> String {
  document_get_frontier(self.doc)
}

///|
/// Get the current CRDT frontier (RawVersions) as JSON
pub fn EgWalkerProxy::get_frontier_raw_json(self : EgWalkerProxy) -> String {
  document_get_frontier_raw(self.doc)
}

///|
/// Cleanup
/// Dispose of the proxy and clean up subscriptions
pub fn EgWalkerProxy::dispose(self : EgWalkerProxy) -> Unit {
  match self.subscription {
    Some(sub) => unsubscribe(sub)
    None => ()
  }
  self.subscription = None
}

///|
/// Diff Calculation
/// Calculate the difference between old and new text
priv enum DiffOp {
  Insert(Int, String)
  Delete(Int, Int) // position, length
}

///|
fn calculate_diff(old_text : String, new_text : String) -> Array[DiffOp] {
  let ops : Array[DiffOp] = []

  // Simple diff algorithm: find longest common prefix/suffix
  let mut i = 0
  let old_len = old_text.length()
  let new_len = new_text.length()

  // Find common prefix
  while i < old_len && i < new_len && old_text[i] == new_text[i] {
    i = i + 1
  }

  // Find common suffix
  let mut j = 0
  while j < old_len - i &&
        j < new_len - i &&
        old_text[old_len - 1 - j] == new_text[new_len - 1 - j] {
    j = j + 1
  }
  let old_middle_len = old_len - i - j
  let new_middle_len = new_len - i - j

  // Handle deletions
  if old_middle_len > 0 {
    ops.push(Delete(i, old_middle_len))
  }

  // Handle insertions
  if new_middle_len > 0 {
    let inserted = new_text[i:i + new_middle_len].to_string() catch { _ => "" }
    ops.push(Insert(i, inserted))
  }
  ops
}
