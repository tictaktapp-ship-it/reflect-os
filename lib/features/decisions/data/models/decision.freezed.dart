// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'decision.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Decision {

 String get id; String get title; String get state; String? get stakes;@JsonKey(name: 'initial_confidence') int? get initialConfidence;@JsonKey(name: 'category_name') String? get categoryName;@JsonKey(name: 'description_encrypted') String? get descriptionEncrypted;@JsonKey(name: 'health_state') String? get healthState;@JsonKey(name: 'decision_deadline') DateTime? get decisionDeadline;@JsonKey(name: 'created_at') DateTime get createdAt;@JsonKey(name: 'updated_at') DateTime get updatedAt;@JsonKey(name: 'requires_approval') bool get requiresApproval;@JsonKey(name: 'continuous') bool get isContinuous;@JsonKey(name: 'deadline_notification_enabled') bool get deadlineNotificationEnabled;@JsonKey(name: 'deadline_notification_offset_days') int? get deadlineNotificationOffsetDays;// Provenance — populated when this decision is a fork of another.
@JsonKey(name: 'source_decision_id') String? get sourceDecisionId;@JsonKey(name: 'shared_to_team_at') DateTime? get sharedToTeamAt;@JsonKey(name: 'shared_from_personal_at') DateTime? get sharedFromPersonalAt;// Raw DB value before decryption — used by the encryption verification UI.
@JsonKey(name: 'raw_description_encrypted', includeToJson: false) String? get rawDescriptionEncrypted;
/// Create a copy of Decision
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DecisionCopyWith<Decision> get copyWith => _$DecisionCopyWithImpl<Decision>(this as Decision, _$identity);

  /// Serializes this Decision to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Decision&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.stakes, stakes) || other.stakes == stakes)&&(identical(other.initialConfidence, initialConfidence) || other.initialConfidence == initialConfidence)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.descriptionEncrypted, descriptionEncrypted) || other.descriptionEncrypted == descriptionEncrypted)&&(identical(other.healthState, healthState) || other.healthState == healthState)&&(identical(other.decisionDeadline, decisionDeadline) || other.decisionDeadline == decisionDeadline)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.requiresApproval, requiresApproval) || other.requiresApproval == requiresApproval)&&(identical(other.isContinuous, isContinuous) || other.isContinuous == isContinuous)&&(identical(other.deadlineNotificationEnabled, deadlineNotificationEnabled) || other.deadlineNotificationEnabled == deadlineNotificationEnabled)&&(identical(other.deadlineNotificationOffsetDays, deadlineNotificationOffsetDays) || other.deadlineNotificationOffsetDays == deadlineNotificationOffsetDays)&&(identical(other.sourceDecisionId, sourceDecisionId) || other.sourceDecisionId == sourceDecisionId)&&(identical(other.sharedToTeamAt, sharedToTeamAt) || other.sharedToTeamAt == sharedToTeamAt)&&(identical(other.sharedFromPersonalAt, sharedFromPersonalAt) || other.sharedFromPersonalAt == sharedFromPersonalAt)&&(identical(other.rawDescriptionEncrypted, rawDescriptionEncrypted) || other.rawDescriptionEncrypted == rawDescriptionEncrypted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,title,state,stakes,initialConfidence,categoryName,descriptionEncrypted,healthState,decisionDeadline,createdAt,updatedAt,requiresApproval,isContinuous,deadlineNotificationEnabled,deadlineNotificationOffsetDays,sourceDecisionId,sharedToTeamAt,sharedFromPersonalAt,rawDescriptionEncrypted]);

@override
String toString() {
  return 'Decision(id: $id, title: $title, state: $state, stakes: $stakes, initialConfidence: $initialConfidence, categoryName: $categoryName, descriptionEncrypted: $descriptionEncrypted, healthState: $healthState, decisionDeadline: $decisionDeadline, createdAt: $createdAt, updatedAt: $updatedAt, requiresApproval: $requiresApproval, isContinuous: $isContinuous, deadlineNotificationEnabled: $deadlineNotificationEnabled, deadlineNotificationOffsetDays: $deadlineNotificationOffsetDays, sourceDecisionId: $sourceDecisionId, sharedToTeamAt: $sharedToTeamAt, sharedFromPersonalAt: $sharedFromPersonalAt, rawDescriptionEncrypted: $rawDescriptionEncrypted)';
}


}

/// @nodoc
abstract mixin class $DecisionCopyWith<$Res>  {
  factory $DecisionCopyWith(Decision value, $Res Function(Decision) _then) = _$DecisionCopyWithImpl;
@useResult
$Res call({
 String id, String title, String state, String? stakes,@JsonKey(name: 'initial_confidence') int? initialConfidence,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'description_encrypted') String? descriptionEncrypted,@JsonKey(name: 'health_state') String? healthState,@JsonKey(name: 'decision_deadline') DateTime? decisionDeadline,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt,@JsonKey(name: 'requires_approval') bool requiresApproval,@JsonKey(name: 'continuous') bool isContinuous,@JsonKey(name: 'deadline_notification_enabled') bool deadlineNotificationEnabled,@JsonKey(name: 'deadline_notification_offset_days') int? deadlineNotificationOffsetDays,@JsonKey(name: 'source_decision_id') String? sourceDecisionId,@JsonKey(name: 'shared_to_team_at') DateTime? sharedToTeamAt,@JsonKey(name: 'shared_from_personal_at') DateTime? sharedFromPersonalAt,@JsonKey(name: 'raw_description_encrypted', includeToJson: false) String? rawDescriptionEncrypted
});




}
/// @nodoc
class _$DecisionCopyWithImpl<$Res>
    implements $DecisionCopyWith<$Res> {
  _$DecisionCopyWithImpl(this._self, this._then);

  final Decision _self;
  final $Res Function(Decision) _then;

/// Create a copy of Decision
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? state = null,Object? stakes = freezed,Object? initialConfidence = freezed,Object? categoryName = freezed,Object? descriptionEncrypted = freezed,Object? healthState = freezed,Object? decisionDeadline = freezed,Object? createdAt = null,Object? updatedAt = null,Object? requiresApproval = null,Object? isContinuous = null,Object? deadlineNotificationEnabled = null,Object? deadlineNotificationOffsetDays = freezed,Object? sourceDecisionId = freezed,Object? sharedToTeamAt = freezed,Object? sharedFromPersonalAt = freezed,Object? rawDescriptionEncrypted = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,stakes: freezed == stakes ? _self.stakes : stakes // ignore: cast_nullable_to_non_nullable
as String?,initialConfidence: freezed == initialConfidence ? _self.initialConfidence : initialConfidence // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,descriptionEncrypted: freezed == descriptionEncrypted ? _self.descriptionEncrypted : descriptionEncrypted // ignore: cast_nullable_to_non_nullable
as String?,healthState: freezed == healthState ? _self.healthState : healthState // ignore: cast_nullable_to_non_nullable
as String?,decisionDeadline: freezed == decisionDeadline ? _self.decisionDeadline : decisionDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,requiresApproval: null == requiresApproval ? _self.requiresApproval : requiresApproval // ignore: cast_nullable_to_non_nullable
as bool,isContinuous: null == isContinuous ? _self.isContinuous : isContinuous // ignore: cast_nullable_to_non_nullable
as bool,deadlineNotificationEnabled: null == deadlineNotificationEnabled ? _self.deadlineNotificationEnabled : deadlineNotificationEnabled // ignore: cast_nullable_to_non_nullable
as bool,deadlineNotificationOffsetDays: freezed == deadlineNotificationOffsetDays ? _self.deadlineNotificationOffsetDays : deadlineNotificationOffsetDays // ignore: cast_nullable_to_non_nullable
as int?,sourceDecisionId: freezed == sourceDecisionId ? _self.sourceDecisionId : sourceDecisionId // ignore: cast_nullable_to_non_nullable
as String?,sharedToTeamAt: freezed == sharedToTeamAt ? _self.sharedToTeamAt : sharedToTeamAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sharedFromPersonalAt: freezed == sharedFromPersonalAt ? _self.sharedFromPersonalAt : sharedFromPersonalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rawDescriptionEncrypted: freezed == rawDescriptionEncrypted ? _self.rawDescriptionEncrypted : rawDescriptionEncrypted // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Decision].
extension DecisionPatterns on Decision {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Decision value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Decision() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Decision value)  $default,){
final _that = this;
switch (_that) {
case _Decision():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Decision value)?  $default,){
final _that = this;
switch (_that) {
case _Decision() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String state,  String? stakes, @JsonKey(name: 'initial_confidence')  int? initialConfidence, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'description_encrypted')  String? descriptionEncrypted, @JsonKey(name: 'health_state')  String? healthState, @JsonKey(name: 'decision_deadline')  DateTime? decisionDeadline, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'continuous')  bool isContinuous, @JsonKey(name: 'deadline_notification_enabled')  bool deadlineNotificationEnabled, @JsonKey(name: 'deadline_notification_offset_days')  int? deadlineNotificationOffsetDays, @JsonKey(name: 'source_decision_id')  String? sourceDecisionId, @JsonKey(name: 'shared_to_team_at')  DateTime? sharedToTeamAt, @JsonKey(name: 'shared_from_personal_at')  DateTime? sharedFromPersonalAt, @JsonKey(name: 'raw_description_encrypted', includeToJson: false)  String? rawDescriptionEncrypted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Decision() when $default != null:
return $default(_that.id,_that.title,_that.state,_that.stakes,_that.initialConfidence,_that.categoryName,_that.descriptionEncrypted,_that.healthState,_that.decisionDeadline,_that.createdAt,_that.updatedAt,_that.requiresApproval,_that.isContinuous,_that.deadlineNotificationEnabled,_that.deadlineNotificationOffsetDays,_that.sourceDecisionId,_that.sharedToTeamAt,_that.sharedFromPersonalAt,_that.rawDescriptionEncrypted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String state,  String? stakes, @JsonKey(name: 'initial_confidence')  int? initialConfidence, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'description_encrypted')  String? descriptionEncrypted, @JsonKey(name: 'health_state')  String? healthState, @JsonKey(name: 'decision_deadline')  DateTime? decisionDeadline, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'continuous')  bool isContinuous, @JsonKey(name: 'deadline_notification_enabled')  bool deadlineNotificationEnabled, @JsonKey(name: 'deadline_notification_offset_days')  int? deadlineNotificationOffsetDays, @JsonKey(name: 'source_decision_id')  String? sourceDecisionId, @JsonKey(name: 'shared_to_team_at')  DateTime? sharedToTeamAt, @JsonKey(name: 'shared_from_personal_at')  DateTime? sharedFromPersonalAt, @JsonKey(name: 'raw_description_encrypted', includeToJson: false)  String? rawDescriptionEncrypted)  $default,) {final _that = this;
switch (_that) {
case _Decision():
return $default(_that.id,_that.title,_that.state,_that.stakes,_that.initialConfidence,_that.categoryName,_that.descriptionEncrypted,_that.healthState,_that.decisionDeadline,_that.createdAt,_that.updatedAt,_that.requiresApproval,_that.isContinuous,_that.deadlineNotificationEnabled,_that.deadlineNotificationOffsetDays,_that.sourceDecisionId,_that.sharedToTeamAt,_that.sharedFromPersonalAt,_that.rawDescriptionEncrypted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String state,  String? stakes, @JsonKey(name: 'initial_confidence')  int? initialConfidence, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'description_encrypted')  String? descriptionEncrypted, @JsonKey(name: 'health_state')  String? healthState, @JsonKey(name: 'decision_deadline')  DateTime? decisionDeadline, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'updated_at')  DateTime updatedAt, @JsonKey(name: 'requires_approval')  bool requiresApproval, @JsonKey(name: 'continuous')  bool isContinuous, @JsonKey(name: 'deadline_notification_enabled')  bool deadlineNotificationEnabled, @JsonKey(name: 'deadline_notification_offset_days')  int? deadlineNotificationOffsetDays, @JsonKey(name: 'source_decision_id')  String? sourceDecisionId, @JsonKey(name: 'shared_to_team_at')  DateTime? sharedToTeamAt, @JsonKey(name: 'shared_from_personal_at')  DateTime? sharedFromPersonalAt, @JsonKey(name: 'raw_description_encrypted', includeToJson: false)  String? rawDescriptionEncrypted)?  $default,) {final _that = this;
switch (_that) {
case _Decision() when $default != null:
return $default(_that.id,_that.title,_that.state,_that.stakes,_that.initialConfidence,_that.categoryName,_that.descriptionEncrypted,_that.healthState,_that.decisionDeadline,_that.createdAt,_that.updatedAt,_that.requiresApproval,_that.isContinuous,_that.deadlineNotificationEnabled,_that.deadlineNotificationOffsetDays,_that.sourceDecisionId,_that.sharedToTeamAt,_that.sharedFromPersonalAt,_that.rawDescriptionEncrypted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Decision extends Decision {
  const _Decision({required this.id, required this.title, required this.state, this.stakes, @JsonKey(name: 'initial_confidence') this.initialConfidence, @JsonKey(name: 'category_name') this.categoryName, @JsonKey(name: 'description_encrypted') this.descriptionEncrypted, @JsonKey(name: 'health_state') this.healthState, @JsonKey(name: 'decision_deadline') this.decisionDeadline, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'updated_at') required this.updatedAt, @JsonKey(name: 'requires_approval') this.requiresApproval = false, @JsonKey(name: 'continuous') this.isContinuous = false, @JsonKey(name: 'deadline_notification_enabled') this.deadlineNotificationEnabled = false, @JsonKey(name: 'deadline_notification_offset_days') this.deadlineNotificationOffsetDays, @JsonKey(name: 'source_decision_id') this.sourceDecisionId, @JsonKey(name: 'shared_to_team_at') this.sharedToTeamAt, @JsonKey(name: 'shared_from_personal_at') this.sharedFromPersonalAt, @JsonKey(name: 'raw_description_encrypted', includeToJson: false) this.rawDescriptionEncrypted}): super._();
  factory _Decision.fromJson(Map<String, dynamic> json) => _$DecisionFromJson(json);

@override final  String id;
@override final  String title;
@override final  String state;
@override final  String? stakes;
@override@JsonKey(name: 'initial_confidence') final  int? initialConfidence;
@override@JsonKey(name: 'category_name') final  String? categoryName;
@override@JsonKey(name: 'description_encrypted') final  String? descriptionEncrypted;
@override@JsonKey(name: 'health_state') final  String? healthState;
@override@JsonKey(name: 'decision_deadline') final  DateTime? decisionDeadline;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime updatedAt;
@override@JsonKey(name: 'requires_approval') final  bool requiresApproval;
@override@JsonKey(name: 'continuous') final  bool isContinuous;
@override@JsonKey(name: 'deadline_notification_enabled') final  bool deadlineNotificationEnabled;
@override@JsonKey(name: 'deadline_notification_offset_days') final  int? deadlineNotificationOffsetDays;
// Provenance — populated when this decision is a fork of another.
@override@JsonKey(name: 'source_decision_id') final  String? sourceDecisionId;
@override@JsonKey(name: 'shared_to_team_at') final  DateTime? sharedToTeamAt;
@override@JsonKey(name: 'shared_from_personal_at') final  DateTime? sharedFromPersonalAt;
// Raw DB value before decryption — used by the encryption verification UI.
@override@JsonKey(name: 'raw_description_encrypted', includeToJson: false) final  String? rawDescriptionEncrypted;

/// Create a copy of Decision
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DecisionCopyWith<_Decision> get copyWith => __$DecisionCopyWithImpl<_Decision>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DecisionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Decision&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.state, state) || other.state == state)&&(identical(other.stakes, stakes) || other.stakes == stakes)&&(identical(other.initialConfidence, initialConfidence) || other.initialConfidence == initialConfidence)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.descriptionEncrypted, descriptionEncrypted) || other.descriptionEncrypted == descriptionEncrypted)&&(identical(other.healthState, healthState) || other.healthState == healthState)&&(identical(other.decisionDeadline, decisionDeadline) || other.decisionDeadline == decisionDeadline)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.requiresApproval, requiresApproval) || other.requiresApproval == requiresApproval)&&(identical(other.isContinuous, isContinuous) || other.isContinuous == isContinuous)&&(identical(other.deadlineNotificationEnabled, deadlineNotificationEnabled) || other.deadlineNotificationEnabled == deadlineNotificationEnabled)&&(identical(other.deadlineNotificationOffsetDays, deadlineNotificationOffsetDays) || other.deadlineNotificationOffsetDays == deadlineNotificationOffsetDays)&&(identical(other.sourceDecisionId, sourceDecisionId) || other.sourceDecisionId == sourceDecisionId)&&(identical(other.sharedToTeamAt, sharedToTeamAt) || other.sharedToTeamAt == sharedToTeamAt)&&(identical(other.sharedFromPersonalAt, sharedFromPersonalAt) || other.sharedFromPersonalAt == sharedFromPersonalAt)&&(identical(other.rawDescriptionEncrypted, rawDescriptionEncrypted) || other.rawDescriptionEncrypted == rawDescriptionEncrypted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,title,state,stakes,initialConfidence,categoryName,descriptionEncrypted,healthState,decisionDeadline,createdAt,updatedAt,requiresApproval,isContinuous,deadlineNotificationEnabled,deadlineNotificationOffsetDays,sourceDecisionId,sharedToTeamAt,sharedFromPersonalAt,rawDescriptionEncrypted]);

@override
String toString() {
  return 'Decision(id: $id, title: $title, state: $state, stakes: $stakes, initialConfidence: $initialConfidence, categoryName: $categoryName, descriptionEncrypted: $descriptionEncrypted, healthState: $healthState, decisionDeadline: $decisionDeadline, createdAt: $createdAt, updatedAt: $updatedAt, requiresApproval: $requiresApproval, isContinuous: $isContinuous, deadlineNotificationEnabled: $deadlineNotificationEnabled, deadlineNotificationOffsetDays: $deadlineNotificationOffsetDays, sourceDecisionId: $sourceDecisionId, sharedToTeamAt: $sharedToTeamAt, sharedFromPersonalAt: $sharedFromPersonalAt, rawDescriptionEncrypted: $rawDescriptionEncrypted)';
}


}

/// @nodoc
abstract mixin class _$DecisionCopyWith<$Res> implements $DecisionCopyWith<$Res> {
  factory _$DecisionCopyWith(_Decision value, $Res Function(_Decision) _then) = __$DecisionCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String state, String? stakes,@JsonKey(name: 'initial_confidence') int? initialConfidence,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'description_encrypted') String? descriptionEncrypted,@JsonKey(name: 'health_state') String? healthState,@JsonKey(name: 'decision_deadline') DateTime? decisionDeadline,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'updated_at') DateTime updatedAt,@JsonKey(name: 'requires_approval') bool requiresApproval,@JsonKey(name: 'continuous') bool isContinuous,@JsonKey(name: 'deadline_notification_enabled') bool deadlineNotificationEnabled,@JsonKey(name: 'deadline_notification_offset_days') int? deadlineNotificationOffsetDays,@JsonKey(name: 'source_decision_id') String? sourceDecisionId,@JsonKey(name: 'shared_to_team_at') DateTime? sharedToTeamAt,@JsonKey(name: 'shared_from_personal_at') DateTime? sharedFromPersonalAt,@JsonKey(name: 'raw_description_encrypted', includeToJson: false) String? rawDescriptionEncrypted
});




}
/// @nodoc
class __$DecisionCopyWithImpl<$Res>
    implements _$DecisionCopyWith<$Res> {
  __$DecisionCopyWithImpl(this._self, this._then);

  final _Decision _self;
  final $Res Function(_Decision) _then;

/// Create a copy of Decision
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? state = null,Object? stakes = freezed,Object? initialConfidence = freezed,Object? categoryName = freezed,Object? descriptionEncrypted = freezed,Object? healthState = freezed,Object? decisionDeadline = freezed,Object? createdAt = null,Object? updatedAt = null,Object? requiresApproval = null,Object? isContinuous = null,Object? deadlineNotificationEnabled = null,Object? deadlineNotificationOffsetDays = freezed,Object? sourceDecisionId = freezed,Object? sharedToTeamAt = freezed,Object? sharedFromPersonalAt = freezed,Object? rawDescriptionEncrypted = freezed,}) {
  return _then(_Decision(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,stakes: freezed == stakes ? _self.stakes : stakes // ignore: cast_nullable_to_non_nullable
as String?,initialConfidence: freezed == initialConfidence ? _self.initialConfidence : initialConfidence // ignore: cast_nullable_to_non_nullable
as int?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,descriptionEncrypted: freezed == descriptionEncrypted ? _self.descriptionEncrypted : descriptionEncrypted // ignore: cast_nullable_to_non_nullable
as String?,healthState: freezed == healthState ? _self.healthState : healthState // ignore: cast_nullable_to_non_nullable
as String?,decisionDeadline: freezed == decisionDeadline ? _self.decisionDeadline : decisionDeadline // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,requiresApproval: null == requiresApproval ? _self.requiresApproval : requiresApproval // ignore: cast_nullable_to_non_nullable
as bool,isContinuous: null == isContinuous ? _self.isContinuous : isContinuous // ignore: cast_nullable_to_non_nullable
as bool,deadlineNotificationEnabled: null == deadlineNotificationEnabled ? _self.deadlineNotificationEnabled : deadlineNotificationEnabled // ignore: cast_nullable_to_non_nullable
as bool,deadlineNotificationOffsetDays: freezed == deadlineNotificationOffsetDays ? _self.deadlineNotificationOffsetDays : deadlineNotificationOffsetDays // ignore: cast_nullable_to_non_nullable
as int?,sourceDecisionId: freezed == sourceDecisionId ? _self.sourceDecisionId : sourceDecisionId // ignore: cast_nullable_to_non_nullable
as String?,sharedToTeamAt: freezed == sharedToTeamAt ? _self.sharedToTeamAt : sharedToTeamAt // ignore: cast_nullable_to_non_nullable
as DateTime?,sharedFromPersonalAt: freezed == sharedFromPersonalAt ? _self.sharedFromPersonalAt : sharedFromPersonalAt // ignore: cast_nullable_to_non_nullable
as DateTime?,rawDescriptionEncrypted: freezed == rawDescriptionEncrypted ? _self.rawDescriptionEncrypted : rawDescriptionEncrypted // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
