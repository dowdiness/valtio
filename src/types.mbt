// Valtio FFI Types for MoonBit
//
// External types for interacting with Valtio's JavaScript API

///| External Type Declarations
/// Foreign types representing Valtio's JavaScript objects

///|
/// A Valtio proxy object that tracks mutations
#external
///|
/// External handle for a Valtio proxy object.
pub type ValtioProxy

///|
/// An immutable snapshot of proxy state for rendering
#external
///|
/// External handle for a Valtio snapshot.
pub type ValtioSnapshot

///|
/// A subscription handle that can be used to unsubscribe
#external
///|
/// External handle for a Valtio subscription.
pub type ValtioSubscription

///|
/// A callback function for subscriptions
pub type SubscribeCallback = () -> Unit

///|
/// A callback function with operations parameter
pub type SubscribeOpsCallback = (ValtioProxy) -> Unit
