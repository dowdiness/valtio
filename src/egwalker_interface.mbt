// EgWalker CRDT Interface for Valtio Integration
//
// Defines the interface types needed for integration without direct dependency

///|
/// CRDT Operation Type
/// Represents a single CRDT operation
#external
pub type CRDTOperation

///|
/// CRDT Document Type
/// Represents the event-graph-walker Document
#external
pub type CRDTDocument

///|
/// Operation Creation
/// Create CRDT operations through JavaScript FFI
pub extern "js" fn create_document(agent_id : String) -> CRDTDocument =
  #|(agent_id) => {
  #|  const { Document } = require('./egwalker_crdt.js');
  #|  return new Document(agent_id);
  #|}

///|
pub extern "js" fn document_insert(
  doc : CRDTDocument,
  position : Int,
  text : String,
) -> CRDTOperation =
  #|(doc, position, text) => {
  #|  return doc.insert(position, text);
  #|}

///|
pub extern "js" fn document_delete(
  doc : CRDTDocument,
  position : Int,
) -> CRDTOperation =
  #|(doc, position) => {
  #|  return doc.delete(position);
  #|}

///|
pub extern "js" fn document_to_text(doc : CRDTDocument) -> String =
  #|(doc) => {
  #|  return doc.to_text();
  #|}

///|
pub extern "js" fn document_apply_remote(
  doc : CRDTDocument,
  op : CRDTOperation,
) -> Unit =
  #|(doc, op) => {
  #|  doc.apply_remote(op);
  #|}

///|
pub extern "js" fn document_get_frontier(doc : CRDTDocument) -> String =
  #|(doc) => {
  #|  return JSON.stringify(doc.get_frontier_array());
  #|}

///|
pub extern "js" fn document_get_frontier_raw(doc : CRDTDocument) -> String =
  #|(doc) => {
  #|  return JSON.stringify(doc.get_frontier_raw());
  #|}

///|
/// Operation Serialization
/// Convert operations to/from JSON for network sync
pub extern "js" fn operation_to_json(op : CRDTOperation) -> String =
  #|(op) => {
  #|  return JSON.stringify(op);
  #|}

///|
pub extern "js" fn operation_from_json(json : String) -> CRDTOperation =
  #|(json) => {
  #|  return JSON.parse(json);
  #|}

// ============================================================
// UndoManager-integrated CRDT operations via crdt module FFI
// ============================================================

///|
/// Create a document with UndoManager support
/// Calls crdt module's create_editor_with_undo which sets up both
/// the ParsedEditor and the UndoManager in the crdt module's global state
pub extern "js" fn create_document_with_undo(
  agent_id : String,
  capture_timeout_ms : Int,
) -> CRDTDocument =
  #|(agent_id, capture_timeout_ms) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  const handle = crdt.create_editor_with_undo(agent_id, capture_timeout_ms);
  #|  return { __undo_handle: handle, __agent_id: agent_id };
  #|}

///|
/// Set text and record changes for undo (diff-based)
pub extern "js" fn document_set_text_and_record(
  doc : CRDTDocument,
  new_text : String,
  timestamp_ms : Int,
) -> Unit =
  #|(doc, new_text, timestamp_ms) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  crdt.set_text_and_record(doc.__undo_handle, new_text, timestamp_ms);
  #|}

///|
/// Undo the last operation group via the crdt module's UndoManager
/// Returns JSON string of ops for peer sync
pub extern "js" fn undo_manager_undo(doc : CRDTDocument) -> String =
  #|(doc) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  return crdt.undo_manager_undo(doc.__undo_handle);
  #|}

///|
/// Redo the last undone operation group via the crdt module's UndoManager
/// Returns JSON string of ops for peer sync
pub extern "js" fn undo_manager_redo(doc : CRDTDocument) -> String =
  #|(doc) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  return crdt.undo_manager_redo(doc.__undo_handle);
  #|}

///|
/// Check if undo is possible
pub extern "js" fn undo_manager_can_undo(doc : CRDTDocument) -> Bool =
  #|(doc) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  return crdt.undo_manager_can_undo(doc.__undo_handle);
  #|}

///|
/// Check if redo is possible
pub extern "js" fn undo_manager_can_redo(doc : CRDTDocument) -> Bool =
  #|(doc) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  return crdt.undo_manager_can_redo(doc.__undo_handle);
  #|}

///|
/// Enable or disable undo tracking
/// Use false before applying remote ops, true after
pub extern "js" fn undo_manager_set_tracking(
  doc : CRDTDocument,
  enabled : Bool,
) -> Unit =
  #|(doc, enabled) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  crdt.undo_manager_set_tracking(doc.__undo_handle, enabled);
  #|}

///|
/// Clear both undo and redo stacks
pub extern "js" fn undo_manager_clear(doc : CRDTDocument) -> Unit =
  #|(doc) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  crdt.undo_manager_clear(doc.__undo_handle);
  #|}

///|
/// Get the current text from the crdt module's editor
pub extern "js" fn document_get_text(doc : CRDTDocument) -> String =
  #|(doc) => {
  #|  const crdt = require('./egwalker_crdt.js');
  #|  return crdt.get_text(doc.__undo_handle);
  #|}

///|
/// Get current timestamp in milliseconds
pub extern "js" fn get_timestamp_ms() -> Int =
  #|() => {
  #|  return Date.now();
  #|}
