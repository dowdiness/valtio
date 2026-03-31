// Valtio FFI Types for MoonBit
//
// External types for interacting with Valtio's JavaScript API

///| External Type Declarations
/// Foreign types representing Valtio's JavaScript objects

///|
/// External handle for a Valtio proxy object.
#external
pub type ValtioProxy

///|
/// External handle for a Valtio snapshot.
#external
pub type ValtioSnapshot

///|
/// External handle for a Valtio subscription.
#external
pub type ValtioSubscription

///|
/// A callback function for subscriptions
pub type SubscribeCallback = () -> Unit

///|
/// A callback function with operations parameter
pub type SubscribeOpsCallback = (ValtioProxy) -> Unit
