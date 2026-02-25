// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'outcome_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OutcomeUpdate {

 String get id;@JsonKey(name: 'decision_id') String get decisionId;@JsonKey(name: 'checkpoint_id') String? get checkpointId;@JsonKey(name: 'recorded_by_user_id') String get recordedByUserId;@JsonKey(name: 'outcome_text_encrypted') String? get outcomeTextEncrypted;@JsonKey(name: 'outcome_quality_score') int get outcomeQualityScore;@JsonKey(name: 'outcome_state') String? get outcomeState;@JsonKey(name: 'lessons_learned_encrypted') String? get lessonsLearnedEncrypted;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime get updatedAt;
/// Create a copy of OutcomeUpdate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OutcomeUpdateCopyWith<OutcomeUpdate> get copyWith => _$OutcomeUpdateCopyWithImpl<OutcomeUpdate>(this as OutcomeUpdate, _$identity);

  /// Serializes this OutcomeUpdate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OutcomeUpdate&&(identical(other.id, id) || other.id == id)&&(identical(other.decisionId, decisionId) || other.decisionId == decisionId)&&(identical(other.checkpointId, checkpointId) || other.checkpointId == checkpointId)&&(identical(other.recordedByUserId, recordedByUserId) || other.recordedByUserId == recordedByUserId)&&(identical(other.outcomeTextEncrypted, outcomeTextEncrypted) || other.outcomeTextEncrypted == outcomeTextEncrypted)&&(identical(other.outcomeQualityScore, outcomeQualityScore) || other.outcomeQualityScore == outcomeQualityScore)&&(identical(other.outcomeState, outcomeState) || other.outcomeState == outcomeState)&&(identical(other.lessonsLearnedEncrypted, lessonsLearnedEncrypted) || other.lessonsLearnedEncrypted == lessonsLearnedEncrypted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,decisionId,checkpointId,recordedByUserId,outcomeTextEncrypted,outcomeQualityScore,outcomeState,lessonsLearnedEncrypted,createdAt,updatedAt);

@override
String toString() {
  return 'OutcomeUpdate(id: $id, decisionId: $decisionId, checkpointId: $checkpointId, recordedByUserId: $recordedByUserId, outcomeTextEncrypted: $outcomeTextEncrypted, outcomeQualityScore: $outcomeQualityScore, outcomeState: $outcomeState, lessonsLearnedEncrypted: $lessonsLearnedEncrypted, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OutcomeUpdateCopyWith<$Res>  {
  factory $OutcomeUpdateCopyWith(OutcomeUpdate value, $Res Function(OutcomeUpdate) _then) = _$OutcomeUpdateCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'decision_id') String decisionId,@JsonKey(name: 'checkpoint_id') String? checkpointId,@JsonKey(name: 'recorded_by_user_id') String recordedByUserId,@JsonKey(name: 'outcome_text_encrypted') String? outcomeTextEncrypted,@JsonKey(name: 'outcome_quality_score') int outcomeQualityScore,@JsonKey(name: 'outcome_state') String? outcomeState,@JsonKey(name: 'lessons_learned_encrypted') String? lessonsLearnedEncrypted,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class _$OutcomeUpdateCopyWithImpl<$Res>
    implements $OutcomeUpdateCopyWith<$Res> {
  _$OutcomeUpdateCopyWithImpl(this._self, this._then);

  final OutcomeUpdate _self;
  final $Res Function(OutcomeUpdate) _then;

/// Create a copy of OutcomeUpdate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? decisionId = null,Object? checkpointId = freezed,Object? recordedByUserId = null,Object? outcomeTextEncrypted = freezed,Object? outcomeQualityScore = null,Object? outcomeState = freezed,Object? lessonsLearnedEncrypted = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,decisionId: null == decisionId ? _self.decisionId : decisionId // ignore: cast_nullable_to_non_nullable
as String,checkpointId: freezed == checkpointId ? _self.checkpointId : checkpointId // ignore: cast_nullable_to_non_nullable
as String?,recordedByUserId: null == recordedByUserId ? _self.recordedByUserId : recordedByUserId // ignore: cast_nullable_to_non_nullable
as String,outcomeTextEncrypted: freezed == outcomeTextEncrypted ? _self.outcomeTextEncrypted : outcomeTextEncrypted // ignore: cast_nullable_to_non_nullable
as String?,outcomeQualityScore: null == outcomeQualityScore ? _self.outcomeQualityScore : outcomeQualityScore // ignore: cast_nullable_to_non_nullable
as int,outcomeState: freezed == outcomeState ? _self.outcomeState : outcomeState // ignore: cast_nullable_to_non_nullable
as String?,lessonsLearnedEncrypted: freezed == lessonsLearnedEncrypted ? _self.lessonsLearnedEncrypted : lessonsLearnedEncrypted // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [OutcomeUpdate].
extension OutcomeUpdatePatterns on OutcomeUpdate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OutcomeUpdate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OutcomeUpdate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OutcomeUpdate value)  $default,){
final _that = this;
switch (_that) {
case _OutcomeUpdate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OutcomeUpdate value)?  $default,){
final _that = this;
switch (_that) {
case _OutcomeUpdate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'decision_id')  String decisionId, @JsonKey(name: 'checkpoint_id')  String? checkpointId, @JsonKey(name: 'recorded_by_user_id')  String recordedByUserId, @JsonKey(name: 'outcome_text_encrypted')  String? outcomeTextEncrypted, @JsonKey(name: 'outcome_quality_score')  int outcomeQualityScore, @JsonKey(name: 'outcome_state')  String? outcomeState, @JsonKey(name: 'lessons_learned_encrypted')  String? lessonsLearnedEncrypted, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OutcomeUpdate() when $default != null:
return $default(_that.id,_that.decisionId,_that.checkpointId,_that.recordedByUserId,_that.outcomeTextEncrypted,_that.outcomeQualityScore,_that.outcomeState,_that.lessonsLearnedEncrypted,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'decision_id')  String decisionId, @JsonKey(name: 'checkpoint_id')  String? checkpointId, @JsonKey(name: 'recorded_by_user_id')  String recordedByUserId, @JsonKey(name: 'outcome_text_encrypted')  String? outcomeTextEncrypted, @JsonKey(name: 'outcome_quality_score')  int outcomeQualityScore, @JsonKey(name: 'outcome_state')  String? outcomeState, @JsonKey(name: 'lessons_learned_encrypted')  String? lessonsLearnedEncrypted, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OutcomeUpdate():
return $default(_that.id,_that.decisionId,_that.checkpointId,_that.recordedByUserId,_that.outcomeTextEncrypted,_that.outcomeQualityScore,_that.outcomeState,_that.lessonsLearnedEncrypted,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'decision_id')  String decisionId, @JsonKey(name: 'checkpoint_id')  String? checkpointId, @JsonKey(name: 'recorded_by_user_id')  String recordedByUserId, @JsonKey(name: 'outcome_text_encrypted')  String? outcomeTextEncrypted, @JsonKey(name: 'outcome_quality_score')  int outcomeQualityScore, @JsonKey(name: 'outcome_state')  String? outcomeState, @JsonKey(name: 'lessons_learned_encrypted')  String? lessonsLearnedEncrypted, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OutcomeUpdate() when $default != null:
return $default(_that.id,_that.decisionId,_that.checkpointId,_that.recordedByUserId,_that.outcomeTextEncrypted,_that.outcomeQualityScore,_that.outcomeState,_that.lessonsLearnedEncrypted,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OutcomeUpdate implements OutcomeUpdate {
  const _OutcomeUpdate({required this.id, @JsonKey(name: 'decision_id') required this.decisionId, @JsonKey(name: 'checkpoint_id') this.checkpointId, @JsonKey(name: 'recorded_by_user_id') required this.recordedByUserId, @JsonKey(name: 'outcome_text_encrypted') this.outcomeTextEncrypted, @JsonKey(name: 'outcome_quality_score') required this.outcomeQualityScore, @JsonKey(name: 'outcome_state') this.outcomeState, @JsonKey(name: 'lessons_learned_encrypted') this.lessonsLearnedEncrypted, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt});
  factory _OutcomeUpdate.fromJson(Map<String, dynamic> json) => _$OutcomeUpdateFromJson(json);

@override final  String id;
@override@JsonKey(name: 'decision_id') final  String decisionId;
@override@JsonKey(name: 'checkpoint_id') final  String? checkpointId;
@override@JsonKey(name: 'recorded_by_user_id') final  String recordedByUserId;
@override@JsonKey(name: 'outcome_text_encrypted') final  String? outcomeTextEncrypted;
@override@JsonKey(name: 'outcome_quality_score') final  int outcomeQualityScore;
@override@JsonKey(name: 'outcome_state') final  String? outcomeState;
@override@JsonKey(name: 'lessons_learned_encrypted') final  String? lessonsLearnedEncrypted;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;

/// Create a copy of OutcomeUpdate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OutcomeUpdateCopyWith<_OutcomeUpdate> get copyWith => __$OutcomeUpdateCopyWithImpl<_OutcomeUpdate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OutcomeUpdateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OutcomeUpdate&&(identical(other.id, id) || other.id == id)&&(identical(other.decisionId, decisionId) || other.decisionId == decisionId)&&(identical(other.checkpointId, checkpointId) || other.checkpointId == checkpointId)&&(identical(other.recordedByUserId, recordedByUserId) || other.recordedByUserId == recordedByUserId)&&(identical(other.outcomeTextEncrypted, outcomeTextEncrypted) || other.outcomeTextEncrypted == outcomeTextEncrypted)&&(identical(other.outcomeQualityScore, outcomeQualityScore) || other.outcomeQualityScore == outcomeQualityScore)&&(identical(other.outcomeState, outcomeState) || other.outcomeState == outcomeState)&&(identical(other.lessonsLearnedEncrypted, lessonsLearnedEncrypted) || other.lessonsLearnedEncrypted == lessonsLearnedEncrypted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,decisionId,checkpointId,recordedByUserId,outcomeTextEncrypted,outcomeQualityScore,outcomeState,lessonsLearnedEncrypted,createdAt,updatedAt);

@override
String toString() {
  return 'OutcomeUpdate(id: $id, decisionId: $decisionId, checkpointId: $checkpointId, recordedByUserId: $recordedByUserId, outcomeTextEncrypted: $outcomeTextEncrypted, outcomeQualityScore: $outcomeQualityScore, outcomeState: $outcomeState, lessonsLearnedEncrypted: $lessonsLearnedEncrypted, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OutcomeUpdateCopyWith<$Res> implements $OutcomeUpdateCopyWith<$Res> {
  factory _$OutcomeUpdateCopyWith(_OutcomeUpdate value, $Res Function(_OutcomeUpdate) _then) = __$OutcomeUpdateCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'decision_id') String decisionId,@JsonKey(name: 'checkpoint_id') String? checkpointId,@JsonKey(name: 'recorded_by_user_id') String recordedByUserId,@JsonKey(name: 'outcome_text_encrypted') String? outcomeTextEncrypted,@JsonKey(name: 'outcome_quality_score') int outcomeQualityScore,@JsonKey(name: 'outcome_state') String? outcomeState,@JsonKey(name: 'lessons_learned_encrypted') String? lessonsLearnedEncrypted,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt
});




}
/// @nodoc
class __$OutcomeUpdateCopyWithImpl<$Res>
    implements _$OutcomeUpdateCopyWith<$Res> {
  __$OutcomeUpdateCopyWithImpl(this._self, this._then);

  final _OutcomeUpdate _self;
  final $Res Function(_OutcomeUpdate) _then;

/// Create a copy of OutcomeUpdate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? decisionId = null,Object? checkpointId = freezed,Object? recordedByUserId = null,Object? outcomeTextEncrypted = freezed,Object? outcomeQualityScore = null,Object? outcomeState = freezed,Object? lessonsLearnedEncrypted = freezed,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_OutcomeUpdate(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,decisionId: null == decisionId ? _self.decisionId : decisionId // ignore: cast_nullable_to_non_nullable
as String,checkpointId: freezed == checkpointId ? _self.checkpointId : checkpointId // ignore: cast_nullable_to_non_nullable
as String?,recordedByUserId: null == recordedByUserId ? _self.recordedByUserId : recordedByUserId // ignore: cast_nullable_to_non_nullable
as String,outcomeTextEncrypted: freezed == outcomeTextEncrypted ? _self.outcomeTextEncrypted : outcomeTextEncrypted // ignore: cast_nullable_to_non_nullable
as String?,outcomeQualityScore: null == outcomeQualityScore ? _self.outcomeQualityScore : outcomeQualityScore // ignore: cast_nullable_to_non_nullable
as int,outcomeState: freezed == outcomeState ? _self.outcomeState : outcomeState // ignore: cast_nullable_to_non_nullable
as String?,lessonsLearnedEncrypted: freezed == lessonsLearnedEncrypted ? _self.lessonsLearnedEncrypted : lessonsLearnedEncrypted // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
