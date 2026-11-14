// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NodeEvent {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'NodeEvent()';
}


}

/// @nodoc
class $NodeEventCopyWith<$Res>  {
$NodeEventCopyWith(NodeEvent _, $Res Function(NodeEvent) __);
}


/// Adds pattern-matching-related methods to [NodeEvent].
extension NodeEventPatterns on NodeEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( NodeEvent_PeerFound value)?  peerFound,TResult Function( NodeEvent_PeerLost value)?  peerLost,TResult Function( NodeEvent_IncomingRequest value)?  incomingRequest,TResult Function( NodeEvent_PinRequired value)?  pinRequired,TResult Function( NodeEvent_PinRejected value)?  pinRejected,TResult Function( NodeEvent_SessionEstablished value)?  sessionEstablished,TResult Function( NodeEvent_Signal value)?  signal,TResult Function( NodeEvent_SessionClosed value)?  sessionClosed,required TResult orElse(),}){
final _that = this;
switch (_that) {
case NodeEvent_PeerFound() when peerFound != null:
return peerFound(_that);case NodeEvent_PeerLost() when peerLost != null:
return peerLost(_that);case NodeEvent_IncomingRequest() when incomingRequest != null:
return incomingRequest(_that);case NodeEvent_PinRequired() when pinRequired != null:
return pinRequired(_that);case NodeEvent_PinRejected() when pinRejected != null:
return pinRejected(_that);case NodeEvent_SessionEstablished() when sessionEstablished != null:
return sessionEstablished(_that);case NodeEvent_Signal() when signal != null:
return signal(_that);case NodeEvent_SessionClosed() when sessionClosed != null:
return sessionClosed(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( NodeEvent_PeerFound value)  peerFound,required TResult Function( NodeEvent_PeerLost value)  peerLost,required TResult Function( NodeEvent_IncomingRequest value)  incomingRequest,required TResult Function( NodeEvent_PinRequired value)  pinRequired,required TResult Function( NodeEvent_PinRejected value)  pinRejected,required TResult Function( NodeEvent_SessionEstablished value)  sessionEstablished,required TResult Function( NodeEvent_Signal value)  signal,required TResult Function( NodeEvent_SessionClosed value)  sessionClosed,}){
final _that = this;
switch (_that) {
case NodeEvent_PeerFound():
return peerFound(_that);case NodeEvent_PeerLost():
return peerLost(_that);case NodeEvent_IncomingRequest():
return incomingRequest(_that);case NodeEvent_PinRequired():
return pinRequired(_that);case NodeEvent_PinRejected():
return pinRejected(_that);case NodeEvent_SessionEstablished():
return sessionEstablished(_that);case NodeEvent_Signal():
return signal(_that);case NodeEvent_SessionClosed():
return sessionClosed(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( NodeEvent_PeerFound value)?  peerFound,TResult? Function( NodeEvent_PeerLost value)?  peerLost,TResult? Function( NodeEvent_IncomingRequest value)?  incomingRequest,TResult? Function( NodeEvent_PinRequired value)?  pinRequired,TResult? Function( NodeEvent_PinRejected value)?  pinRejected,TResult? Function( NodeEvent_SessionEstablished value)?  sessionEstablished,TResult? Function( NodeEvent_Signal value)?  signal,TResult? Function( NodeEvent_SessionClosed value)?  sessionClosed,}){
final _that = this;
switch (_that) {
case NodeEvent_PeerFound() when peerFound != null:
return peerFound(_that);case NodeEvent_PeerLost() when peerLost != null:
return peerLost(_that);case NodeEvent_IncomingRequest() when incomingRequest != null:
return incomingRequest(_that);case NodeEvent_PinRequired() when pinRequired != null:
return pinRequired(_that);case NodeEvent_PinRejected() when pinRejected != null:
return pinRejected(_that);case NodeEvent_SessionEstablished() when sessionEstablished != null:
return sessionEstablished(_that);case NodeEvent_Signal() when signal != null:
return signal(_that);case NodeEvent_SessionClosed() when sessionClosed != null:
return sessionClosed(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( DeviceInfo peer)?  peerFound,TResult Function( String id)?  peerLost,TResult Function( String sessionId,  DeviceInfo peer,  ShareMode mode,  String? pin)?  incomingRequest,TResult Function( String sessionId)?  pinRequired,TResult Function( String sessionId,  int attemptsLeft)?  pinRejected,TResult Function( String sessionId,  DeviceInfo peer,  SessionRole role,  ShareMode mode)?  sessionEstablished,TResult Function( String sessionId,  String payload)?  signal,TResult Function( String sessionId,  CloseReason reason)?  sessionClosed,required TResult orElse(),}) {final _that = this;
switch (_that) {
case NodeEvent_PeerFound() when peerFound != null:
return peerFound(_that.peer);case NodeEvent_PeerLost() when peerLost != null:
return peerLost(_that.id);case NodeEvent_IncomingRequest() when incomingRequest != null:
return incomingRequest(_that.sessionId,_that.peer,_that.mode,_that.pin);case NodeEvent_PinRequired() when pinRequired != null:
return pinRequired(_that.sessionId);case NodeEvent_PinRejected() when pinRejected != null:
return pinRejected(_that.sessionId,_that.attemptsLeft);case NodeEvent_SessionEstablished() when sessionEstablished != null:
return sessionEstablished(_that.sessionId,_that.peer,_that.role,_that.mode);case NodeEvent_Signal() when signal != null:
return signal(_that.sessionId,_that.payload);case NodeEvent_SessionClosed() when sessionClosed != null:
return sessionClosed(_that.sessionId,_that.reason);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( DeviceInfo peer)  peerFound,required TResult Function( String id)  peerLost,required TResult Function( String sessionId,  DeviceInfo peer,  ShareMode mode,  String? pin)  incomingRequest,required TResult Function( String sessionId)  pinRequired,required TResult Function( String sessionId,  int attemptsLeft)  pinRejected,required TResult Function( String sessionId,  DeviceInfo peer,  SessionRole role,  ShareMode mode)  sessionEstablished,required TResult Function( String sessionId,  String payload)  signal,required TResult Function( String sessionId,  CloseReason reason)  sessionClosed,}) {final _that = this;
switch (_that) {
case NodeEvent_PeerFound():
return peerFound(_that.peer);case NodeEvent_PeerLost():
return peerLost(_that.id);case NodeEvent_IncomingRequest():
return incomingRequest(_that.sessionId,_that.peer,_that.mode,_that.pin);case NodeEvent_PinRequired():
return pinRequired(_that.sessionId);case NodeEvent_PinRejected():
return pinRejected(_that.sessionId,_that.attemptsLeft);case NodeEvent_SessionEstablished():
return sessionEstablished(_that.sessionId,_that.peer,_that.role,_that.mode);case NodeEvent_Signal():
return signal(_that.sessionId,_that.payload);case NodeEvent_SessionClosed():
return sessionClosed(_that.sessionId,_that.reason);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( DeviceInfo peer)?  peerFound,TResult? Function( String id)?  peerLost,TResult? Function( String sessionId,  DeviceInfo peer,  ShareMode mode,  String? pin)?  incomingRequest,TResult? Function( String sessionId)?  pinRequired,TResult? Function( String sessionId,  int attemptsLeft)?  pinRejected,TResult? Function( String sessionId,  DeviceInfo peer,  SessionRole role,  ShareMode mode)?  sessionEstablished,TResult? Function( String sessionId,  String payload)?  signal,TResult? Function( String sessionId,  CloseReason reason)?  sessionClosed,}) {final _that = this;
switch (_that) {
case NodeEvent_PeerFound() when peerFound != null:
return peerFound(_that.peer);case NodeEvent_PeerLost() when peerLost != null:
return peerLost(_that.id);case NodeEvent_IncomingRequest() when incomingRequest != null:
return incomingRequest(_that.sessionId,_that.peer,_that.mode,_that.pin);case NodeEvent_PinRequired() when pinRequired != null:
return pinRequired(_that.sessionId);case NodeEvent_PinRejected() when pinRejected != null:
return pinRejected(_that.sessionId,_that.attemptsLeft);case NodeEvent_SessionEstablished() when sessionEstablished != null:
return sessionEstablished(_that.sessionId,_that.peer,_that.role,_that.mode);case NodeEvent_Signal() when signal != null:
return signal(_that.sessionId,_that.payload);case NodeEvent_SessionClosed() when sessionClosed != null:
return sessionClosed(_that.sessionId,_that.reason);case _:
  return null;

}
}

}

/// @nodoc


class NodeEvent_PeerFound extends NodeEvent {
  const NodeEvent_PeerFound({required this.peer}): super._();
  

 final  DeviceInfo peer;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_PeerFoundCopyWith<NodeEvent_PeerFound> get copyWith => _$NodeEvent_PeerFoundCopyWithImpl<NodeEvent_PeerFound>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_PeerFound&&(identical(other.peer, peer) || other.peer == peer));
}


@override
int get hashCode {
    return Object.hash(runtimeType,peer);
}

@override
String toString() {
    return 'NodeEvent.peerFound(peer: $peer)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_PeerFoundCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_PeerFoundCopyWith(NodeEvent_PeerFound value, $Res Function(NodeEvent_PeerFound) _then) = _$NodeEvent_PeerFoundCopyWithImpl;
@useResult
$Res call({
 DeviceInfo peer
});




}
/// @nodoc
class _$NodeEvent_PeerFoundCopyWithImpl<$Res>
    implements $NodeEvent_PeerFoundCopyWith<$Res> {
  _$NodeEvent_PeerFoundCopyWithImpl(this._self, this._then);

  final NodeEvent_PeerFound _self;
  final $Res Function(NodeEvent_PeerFound) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? peer = null,}) {
  return _then(NodeEvent_PeerFound(
peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as DeviceInfo,
  ));
}


}

/// @nodoc


class NodeEvent_PeerLost extends NodeEvent {
  const NodeEvent_PeerLost({required this.id}): super._();
  

 final  String id;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_PeerLostCopyWith<NodeEvent_PeerLost> get copyWith => _$NodeEvent_PeerLostCopyWithImpl<NodeEvent_PeerLost>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_PeerLost&&(identical(other.id, id) || other.id == id));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id);
}

@override
String toString() {
    return 'NodeEvent.peerLost(id: $id)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_PeerLostCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_PeerLostCopyWith(NodeEvent_PeerLost value, $Res Function(NodeEvent_PeerLost) _then) = _$NodeEvent_PeerLostCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$NodeEvent_PeerLostCopyWithImpl<$Res>
    implements $NodeEvent_PeerLostCopyWith<$Res> {
  _$NodeEvent_PeerLostCopyWithImpl(this._self, this._then);

  final NodeEvent_PeerLost _self;
  final $Res Function(NodeEvent_PeerLost) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(NodeEvent_PeerLost(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NodeEvent_IncomingRequest extends NodeEvent {
  const NodeEvent_IncomingRequest({required this.sessionId, required this.peer, required this.mode, this.pin}): super._();
  

 final  String sessionId;
 final  DeviceInfo peer;
 final  ShareMode mode;
 final  String? pin;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_IncomingRequestCopyWith<NodeEvent_IncomingRequest> get copyWith => _$NodeEvent_IncomingRequestCopyWithImpl<NodeEvent_IncomingRequest>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_IncomingRequest&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.peer, peer) || other.peer == peer)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.pin, pin) || other.pin == pin));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,peer,mode,pin);
}

@override
String toString() {
    return 'NodeEvent.incomingRequest(sessionId: $sessionId, peer: $peer, mode: $mode, pin: $pin)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_IncomingRequestCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_IncomingRequestCopyWith(NodeEvent_IncomingRequest value, $Res Function(NodeEvent_IncomingRequest) _then) = _$NodeEvent_IncomingRequestCopyWithImpl;
@useResult
$Res call({
 String sessionId, DeviceInfo peer, ShareMode mode, String? pin
});




}
/// @nodoc
class _$NodeEvent_IncomingRequestCopyWithImpl<$Res>
    implements $NodeEvent_IncomingRequestCopyWith<$Res> {
  _$NodeEvent_IncomingRequestCopyWithImpl(this._self, this._then);

  final NodeEvent_IncomingRequest _self;
  final $Res Function(NodeEvent_IncomingRequest) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? peer = null,Object? mode = null,Object? pin = freezed,}) {
  return _then(NodeEvent_IncomingRequest(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as DeviceInfo,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ShareMode,pin: freezed == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class NodeEvent_PinRequired extends NodeEvent {
  const NodeEvent_PinRequired({required this.sessionId}): super._();
  

 final  String sessionId;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_PinRequiredCopyWith<NodeEvent_PinRequired> get copyWith => _$NodeEvent_PinRequiredCopyWithImpl<NodeEvent_PinRequired>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_PinRequired&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId);
}

@override
String toString() {
    return 'NodeEvent.pinRequired(sessionId: $sessionId)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_PinRequiredCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_PinRequiredCopyWith(NodeEvent_PinRequired value, $Res Function(NodeEvent_PinRequired) _then) = _$NodeEvent_PinRequiredCopyWithImpl;
@useResult
$Res call({
 String sessionId
});




}
/// @nodoc
class _$NodeEvent_PinRequiredCopyWithImpl<$Res>
    implements $NodeEvent_PinRequiredCopyWith<$Res> {
  _$NodeEvent_PinRequiredCopyWithImpl(this._self, this._then);

  final NodeEvent_PinRequired _self;
  final $Res Function(NodeEvent_PinRequired) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,}) {
  return _then(NodeEvent_PinRequired(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NodeEvent_PinRejected extends NodeEvent {
  const NodeEvent_PinRejected({required this.sessionId, required this.attemptsLeft}): super._();
  

 final  String sessionId;
 final  int attemptsLeft;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_PinRejectedCopyWith<NodeEvent_PinRejected> get copyWith => _$NodeEvent_PinRejectedCopyWithImpl<NodeEvent_PinRejected>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_PinRejected&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.attemptsLeft, attemptsLeft) || other.attemptsLeft == attemptsLeft));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,attemptsLeft);
}

@override
String toString() {
    return 'NodeEvent.pinRejected(sessionId: $sessionId, attemptsLeft: $attemptsLeft)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_PinRejectedCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_PinRejectedCopyWith(NodeEvent_PinRejected value, $Res Function(NodeEvent_PinRejected) _then) = _$NodeEvent_PinRejectedCopyWithImpl;
@useResult
$Res call({
 String sessionId, int attemptsLeft
});




}
/// @nodoc
class _$NodeEvent_PinRejectedCopyWithImpl<$Res>
    implements $NodeEvent_PinRejectedCopyWith<$Res> {
  _$NodeEvent_PinRejectedCopyWithImpl(this._self, this._then);

  final NodeEvent_PinRejected _self;
  final $Res Function(NodeEvent_PinRejected) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? attemptsLeft = null,}) {
  return _then(NodeEvent_PinRejected(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,attemptsLeft: null == attemptsLeft ? _self.attemptsLeft : attemptsLeft // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class NodeEvent_SessionEstablished extends NodeEvent {
  const NodeEvent_SessionEstablished({required this.sessionId, required this.peer, required this.role, required this.mode}): super._();
  

 final  String sessionId;
 final  DeviceInfo peer;
 final  SessionRole role;
 final  ShareMode mode;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_SessionEstablishedCopyWith<NodeEvent_SessionEstablished> get copyWith => _$NodeEvent_SessionEstablishedCopyWithImpl<NodeEvent_SessionEstablished>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_SessionEstablished&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.peer, peer) || other.peer == peer)&&(identical(other.role, role) || other.role == role)&&(identical(other.mode, mode) || other.mode == mode));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,peer,role,mode);
}

@override
String toString() {
    return 'NodeEvent.sessionEstablished(sessionId: $sessionId, peer: $peer, role: $role, mode: $mode)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_SessionEstablishedCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_SessionEstablishedCopyWith(NodeEvent_SessionEstablished value, $Res Function(NodeEvent_SessionEstablished) _then) = _$NodeEvent_SessionEstablishedCopyWithImpl;
@useResult
$Res call({
 String sessionId, DeviceInfo peer, SessionRole role, ShareMode mode
});




}
/// @nodoc
class _$NodeEvent_SessionEstablishedCopyWithImpl<$Res>
    implements $NodeEvent_SessionEstablishedCopyWith<$Res> {
  _$NodeEvent_SessionEstablishedCopyWithImpl(this._self, this._then);

  final NodeEvent_SessionEstablished _self;
  final $Res Function(NodeEvent_SessionEstablished) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? peer = null,Object? role = null,Object? mode = null,}) {
  return _then(NodeEvent_SessionEstablished(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,peer: null == peer ? _self.peer : peer // ignore: cast_nullable_to_non_nullable
as DeviceInfo,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as SessionRole,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ShareMode,
  ));
}


}

/// @nodoc


class NodeEvent_Signal extends NodeEvent {
  const NodeEvent_Signal({required this.sessionId, required this.payload}): super._();
  

 final  String sessionId;
 final  String payload;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_SignalCopyWith<NodeEvent_Signal> get copyWith => _$NodeEvent_SignalCopyWithImpl<NodeEvent_Signal>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_Signal&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.payload, payload) || other.payload == payload));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,payload);
}

@override
String toString() {
    return 'NodeEvent.signal(sessionId: $sessionId, payload: $payload)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_SignalCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_SignalCopyWith(NodeEvent_Signal value, $Res Function(NodeEvent_Signal) _then) = _$NodeEvent_SignalCopyWithImpl;
@useResult
$Res call({
 String sessionId, String payload
});




}
/// @nodoc
class _$NodeEvent_SignalCopyWithImpl<$Res>
    implements $NodeEvent_SignalCopyWith<$Res> {
  _$NodeEvent_SignalCopyWithImpl(this._self, this._then);

  final NodeEvent_Signal _self;
  final $Res Function(NodeEvent_Signal) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? payload = null,}) {
  return _then(NodeEvent_Signal(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class NodeEvent_SessionClosed extends NodeEvent {
  const NodeEvent_SessionClosed({required this.sessionId, required this.reason}): super._();
  

 final  String sessionId;
 final  CloseReason reason;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NodeEvent_SessionClosedCopyWith<NodeEvent_SessionClosed> get copyWith => _$NodeEvent_SessionClosedCopyWithImpl<NodeEvent_SessionClosed>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is NodeEvent_SessionClosed&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sessionId,reason);
}

@override
String toString() {
    return 'NodeEvent.sessionClosed(sessionId: $sessionId, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $NodeEvent_SessionClosedCopyWith<$Res> implements $NodeEventCopyWith<$Res> {
  factory $NodeEvent_SessionClosedCopyWith(NodeEvent_SessionClosed value, $Res Function(NodeEvent_SessionClosed) _then) = _$NodeEvent_SessionClosedCopyWithImpl;
@useResult
$Res call({
 String sessionId, CloseReason reason
});




}
/// @nodoc
class _$NodeEvent_SessionClosedCopyWithImpl<$Res>
    implements $NodeEvent_SessionClosedCopyWith<$Res> {
  _$NodeEvent_SessionClosedCopyWithImpl(this._self, this._then);

  final NodeEvent_SessionClosed _self;
  final $Res Function(NodeEvent_SessionClosed) _then;

/// Create a copy of NodeEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sessionId = null,Object? reason = null,}) {
  return _then(NodeEvent_SessionClosed(
sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as CloseReason,
  ));
}


}

// dart format on
