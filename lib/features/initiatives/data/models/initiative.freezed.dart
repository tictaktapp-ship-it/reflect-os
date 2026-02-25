// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'initiative.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Initiative {

 String get id;@JsonKey(name: 'workspace_id') String get workspaceId; String get name;@JsonKey(name: 'description_encrypted') String? get descriptionEncrypted;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime get updatedAt;
/// Create a copy of Initiative
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InitiativeCopyWith<Initiative> get copyWith => _$InitiativeCopyWithImpl<Initiative>(this as Initiative, _$identity);

  /// Serializes this Initiative to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Initiative&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.descriptionEncrypted, descriptionEncrypted) || other.descriptionEncrypted == descriptionEncrypted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,descriptionEncrypted,createdAt,updatedAt);

@override
String toString() {
  return 'Initiative(id: $id, workspaceId: $workspaceId, name: $name, descriptionEncrypted: $descriptionEncrypted, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $InitiativeCopyWith<$Res>  {
  factory $InitiativeCopyWith(Initiative value, $Res Function(Initiative) _then) = _$InitiativeCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'workspace_id') String workspaceId, String name,@JsonKey(name: 'description_encrypted') String? descriptionEncrypted,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class _$InitiativeCopyWithImpl<$Res>
    implements $InitiativeCopyWith<$Res> {
  _$InitiativeCopyWithImpl(this._self, this._then);

  final Initiative _self;
  final $Res Function(Initiative) _then;

/// Create a copy of Initiative
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? descriptionEncrypted = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,descriptionEncrypted: freezed == descriptionEncrypted ? _self.descriptionEncrypted : descriptionEncrypted // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [Initiative].
extension InitiativePatterns on Initiative {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Initiative value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Initiative() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Initiative value)  $default,){
final _that = this;
switch (_that) {
case _Initiative():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Initiative value)?  $default,){
final _that = this;
switch (_that) {
case _Initiative() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'workspace_id')  String workspaceId,  String name, @JsonKey(name: 'description_encrypted')  String? descriptionEncrypted, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Initiative() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.descriptionEncrypted,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'workspace_id')  String workspaceId,  String name, @JsonKey(name: 'description_encrypted')  String? descriptionEncrypted, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Initiative():
return $default(_that.id,_that.workspaceId,_that.name,_that.descriptionEncrypted,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'workspace_id')  String workspaceId,  String name, @JsonKey(name: 'description_encrypted')  String? descriptionEncrypted, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Initiative() when $default != null:
return $default(_that.id,_that.workspaceId,_that.name,_that.descriptionEncrypted,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Initiative implements Initiative {
  const _Initiative({required this.id, @JsonKey(name: 'workspace_id') required this.workspaceId, required this.name, @JsonKey(name: 'description_encrypted') this.descriptionEncrypted, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt});
  factory _Initiative.fromJson(Map<String, dynamic> json) => _$InitiativeFromJson(json);

@override final  String id;
@override@JsonKey(name: 'workspace_id') final  String workspaceId;
@override final  String name;
@override@JsonKey(name: 'description_encrypted') final  String? descriptionEncrypted;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;

/// Create a copy of Initiative
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InitiativeCopyWith<_Initiative> get copyWith => __$InitiativeCopyWithImpl<_Initiative>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InitiativeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Initiative&&(identical(other.id, id) || other.id == id)&&(identical(other.workspaceId, workspaceId) || other.workspaceId == workspaceId)&&(identical(other.name, name) || other.name == name)&&(identical(other.descriptionEncrypted, descriptionEncrypted) || other.descriptionEncrypted == descriptionEncrypted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,workspaceId,name,descriptionEncrypted,createdAt,updatedAt);

@override
String toString() {
  return 'Initiative(id: $id, workspaceId: $workspaceId, name: $name, descriptionEncrypted: $descriptionEncrypted, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$InitiativeCopyWith<$Res> implements $InitiativeCopyWith<$Res> {
  factory _$InitiativeCopyWith(_Initiative value, $Res Function(_Initiative) _then) = __$InitiativeCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'workspace_id') String workspaceId, String name,@JsonKey(name: 'description_encrypted') String? descriptionEncrypted,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class __$InitiativeCopyWithImpl<$Res>
    implements _$InitiativeCopyWith<$Res> {
  __$InitiativeCopyWithImpl(this._self, this._then);

  final _Initiative _self;
  final $Res Function(_Initiative) _then;

/// Create a copy of Initiative
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? workspaceId = null,Object? name = null,Object? descriptionEncrypted = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Initiative(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,workspaceId: null == workspaceId ? _self.workspaceId : workspaceId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,descriptionEncrypted: freezed == descriptionEncrypted ? _self.descriptionEncrypted : descriptionEncrypted // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
