// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationItem {

 String get id;@JsonKey(name: 'workspace_id') String get workspaceId; String get type;@JsonKey(name: 'related_entity_type') String? get relatedEntityType;@JsonKey(name: 'related_entity_id') String? get relatedEntityId;@JsonKey(name: 'scheduled_for') DateTime get scheduledFor; String get status;
/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationItemCopyWith<NotificationItem> get copyWith => _$NotificationItemCopyWithImpl<NotificationItem>(this as NotificationItem, _$identity);

  /// Serializes this NotificationItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationItem&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.relatedEntityType, relatedEntityType) || other.relatedEntityType == relatedEntityType)&&(identical(other.relatedEntityId, relatedEntityId) || other.relatedEntityId == relatedEntityId)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,type,relatedEntityType,relatedEntityId,scheduledFor,status);

@override
String toString() {
  return 'NotificationItem(id: $id, workspaceId: $workspaceId, type: $type, relatedEntityType: $relatedEntityType, relatedEntityId: $relatedEntityId, scheduledFor: $scheduledFor, status: $status)';
}


}

/// @nodoc
abstract mixin class $NotificationItemCopyWith<$Res>  {
  factory $NotificationItemCopyWith(NotificationItem value, $Res Function(NotificationItem) _then) = _$NotificationItemCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'workspace_id') String workspaceId, String type,@JsonKey(name: 'related_entity_type') String? relatedEntityType,@JsonKey(name: 'related_entity_id') String? relatedEntityId,@JsonKey(name: 'scheduled_for') DateTime scheduledFor, String status
});




}
/// @nodoc
class _$NotificationItemCopyWithImpl<$Res>
    implements $NotificationItemCopyWith<$Res> {
  _$NotificationItemCopyWithImpl(this._self, this._then);

  final NotificationItem _self;
  final $Res Function(NotificationItem) _then;

/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? type = null,Object? relatedEntityType = freezed,Object? relatedEntityId = freezed,Object? scheduledFor = null,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,relatedEntityType: freezed == relatedEntityType ? _self.relatedEntityType : relatedEntityType // ignore: cast_nullable_to_non_nullable
as String?,relatedEntityId: freezed == relatedEntityId ? _self.relatedEntityId : relatedEntityId // ignore: cast_nullable_to_non_nullable
as String?,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationItem].
extension NotificationItemPatterns on NotificationItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationItem() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationItem value)  $default,){
final _that = this;
switch (_that) {
case _NotificationItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationItem value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationItem() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'workspace_id')  String workspaceId,  String type, @JsonKey(name: 'related_entity_type')  String? relatedEntityType, @JsonKey(name: 'related_entity_id')  String? relatedEntityId, @JsonKey(name: 'scheduled_for')  DateTime scheduledFor,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationItem() when $default != null:
return $default(_that.id,_that.workspaceId,_that.type,_that.relatedEntityType,_that.relatedEntityId,_that.scheduledFor,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'workspace_id')  String workspaceId,  String type, @JsonKey(name: 'related_entity_type')  String? relatedEntityType, @JsonKey(name: 'related_entity_id')  String? relatedEntityId, @JsonKey(name: 'scheduled_for')  DateTime scheduledFor,  String status)  $default,) {final _that = this;
switch (_that) {
case _NotificationItem():
return $default(_that.id,_that.workspaceId,_that.type,_that.relatedEntityType,_that.relatedEntityId,_that.scheduledFor,_that.status);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'workspace_id')  String workspaceId,  String type, @JsonKey(name: 'related_entity_type')  String? relatedEntityType, @JsonKey(name: 'related_entity_id')  String? relatedEntityId, @JsonKey(name: 'scheduled_for')  DateTime scheduledFor,  String status)?  $default,) {final _that = this;
switch (_that) {
case _NotificationItem() when $default != null:
return $default(_that.id,_that.workspaceId,_that.type,_that.relatedEntityType,_that.relatedEntityId,_that.scheduledFor,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationItem implements NotificationItem {
  const _NotificationItem({required this.id, @JsonKey(name: 'workspace_id') required this.workspaceId, required this.type, @JsonKey(name: 'related_entity_type') this.relatedEntityType, @JsonKey(name: 'related_entity_id') this.relatedEntityId, @JsonKey(name: 'scheduled_for') required this.scheduledFor, required this.status});
  factory _NotificationItem.fromJson(Map<String, dynamic> json) => _$NotificationItemFromJson(json);

@override final  String id;
@override@JsonKey(name: 'workspace_id') final  String workspaceId;
@override final  String type;
@override@JsonKey(name: 'related_entity_type') final  String? relatedEntityType;
@override@JsonKey(name: 'related_entity_id') final  String? relatedEntityId;
@override@JsonKey(name: 'scheduled_for') final  DateTime scheduledFor;
@override final  String status;

/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationItemCopyWith<_NotificationItem> get copyWith => __$NotificationItemCopyWithImpl<_NotificationItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationItem&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.type, type) || other.type == type)&&(identical(other.relatedEntityType, relatedEntityType) || other.relatedEntityType == relatedEntityType)&&(identical(other.relatedEntityId, relatedEntityId) || other.relatedEntityId == relatedEntityId)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,type,relatedEntityType,relatedEntityId,scheduledFor,status);

@override
String toString() {
  return 'NotificationItem(id: $id, workspaceId: $workspaceId, type: $type, relatedEntityType: $relatedEntityType, relatedEntityId: $relatedEntityId, scheduledFor: $scheduledFor, status: $status)';
}


}

/// @nodoc
abstract mixin class _$NotificationItemCopyWith<$Res> implements $NotificationItemCopyWith<$Res> {
  factory _$NotificationItemCopyWith(_NotificationItem value, $Res Function(_NotificationItem) _then) = __$NotificationItemCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'workspace_id') String workspaceId, String type,@JsonKey(name: 'related_entity_type') String? relatedEntityType,@JsonKey(name: 'related_entity_id') String? relatedEntityId,@JsonKey(name: 'scheduled_for') DateTime scheduledFor, String status
});




}
/// @nodoc
class __$NotificationItemCopyWithImpl<$Res>
    implements _$NotificationItemCopyWith<$Res> {
  __$NotificationItemCopyWithImpl(this._self, this._then);

  final _NotificationItem _self;
  final $Res Function(_NotificationItem) _then;

/// Create a copy of NotificationItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? type = null,Object? relatedEntityType = freezed,Object? relatedEntityId = freezed,Object? scheduledFor = null,Object? status = null,}) {
  return _then(_NotificationItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,relatedEntityType: freezed == relatedEntityType ? _self.relatedEntityType : relatedEntityType // ignore: cast_nullable_to_non_nullable
as String?,relatedEntityId: freezed == relatedEntityId ? _self.relatedEntityId : relatedEntityId // ignore: cast_nullable_to_non_nullable
as String?,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
