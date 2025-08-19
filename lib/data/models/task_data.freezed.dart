// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TaskData _$TaskDataFromJson(Map<String, dynamic> json) {
  return _TaskData.fromJson(json);
}

/// @nodoc
mixin _$TaskData {
  // Identity
  String get taskId => throw _privateConstructorUsedError;
  String get taskName => throw _privateConstructorUsedError; // Timestamps
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get dueDate => throw _privateConstructorUsedError; // Status
  bool get completed => throw _privateConstructorUsedError;
  bool get photoRequired =>
      throw _privateConstructorUsedError; // Completion metadata
  String? get completedBy => throw _privateConstructorUsedError;
  String? get completedByUserId => throw _privateConstructorUsedError;
  String? get completedByUserName => throw _privateConstructorUsedError;
  String? get completedByUserEmail => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get completedAt => throw _privateConstructorUsedError; // Content
  String? get notes => throw _privateConstructorUsedError;
  String? get photoUrl =>
      throw _privateConstructorUsedError; // Canonical image field
  String? get proofImageUrl =>
      throw _privateConstructorUsedError; // Legacy alias (kept for compatibility)
  String? get description =>
      throw _privateConstructorUsedError; // Legacy/aux text for migration
  String? get notCompletedReason =>
      throw _privateConstructorUsedError; // Carry-forward fields
  bool get isCarryForward => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get originalDate => throw _privateConstructorUsedError;
  String? get originalChecklistId => throw _privateConstructorUsedError;
  String? get originalTaskId => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get carriedIntoDate => throw _privateConstructorUsedError;
  bool get carryForwardAttempted =>
      throw _privateConstructorUsedError; // Analytics / flags
  bool get excludedFromMetrics => throw _privateConstructorUsedError;
  bool get resolvedLate => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get resolvedAt => throw _privateConstructorUsedError; // Optional denormalized fields to enable collectionGroup queries
  String? get organizationId => throw _privateConstructorUsedError;
  String? get locationId => throw _privateConstructorUsedError;
  String? get checklistId => throw _privateConstructorUsedError;
  String? get checklistName => throw _privateConstructorUsedError;
  String? get shiftId => throw _privateConstructorUsedError;
  String? get templateId => throw _privateConstructorUsedError;
  String? get dateString => throw _privateConstructorUsedError;

  /// Serializes this TaskData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskDataCopyWith<TaskData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskDataCopyWith<$Res> {
  factory $TaskDataCopyWith(TaskData value, $Res Function(TaskData) then) =
      _$TaskDataCopyWithImpl<$Res, TaskData>;
  @useResult
  $Res call({
    String taskId,
    String taskName,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime dueDate,
    bool completed,
    bool photoRequired,
    String? completedBy,
    String? completedByUserId,
    String? completedByUserName,
    String? completedByUserEmail,
    @TimestampConverter() DateTime? completedAt,
    String? notes,
    String? photoUrl,
    String? proofImageUrl,
    String? description,
    String? notCompletedReason,
    bool isCarryForward,
    @TimestampConverter() DateTime? originalDate,
    String? originalChecklistId,
    String? originalTaskId,
    @TimestampConverter() DateTime? carriedIntoDate,
    bool carryForwardAttempted,
    bool excludedFromMetrics,
    bool resolvedLate,
    @TimestampConverter() DateTime? resolvedAt,
    String? organizationId,
    String? locationId,
    String? checklistId,
    String? checklistName,
    String? shiftId,
    String? templateId,
    String? dateString,
  });
}

/// @nodoc
class _$TaskDataCopyWithImpl<$Res, $Val extends TaskData>
    implements $TaskDataCopyWith<$Res> {
  _$TaskDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskName = null,
    Object? createdAt = null,
    Object? dueDate = null,
    Object? completed = null,
    Object? photoRequired = null,
    Object? completedBy = freezed,
    Object? completedByUserId = freezed,
    Object? completedByUserName = freezed,
    Object? completedByUserEmail = freezed,
    Object? completedAt = freezed,
    Object? notes = freezed,
    Object? photoUrl = freezed,
    Object? proofImageUrl = freezed,
    Object? description = freezed,
    Object? notCompletedReason = freezed,
    Object? isCarryForward = null,
    Object? originalDate = freezed,
    Object? originalChecklistId = freezed,
    Object? originalTaskId = freezed,
    Object? carriedIntoDate = freezed,
    Object? carryForwardAttempted = null,
    Object? excludedFromMetrics = null,
    Object? resolvedLate = null,
    Object? resolvedAt = freezed,
    Object? organizationId = freezed,
    Object? locationId = freezed,
    Object? checklistId = freezed,
    Object? checklistName = freezed,
    Object? shiftId = freezed,
    Object? templateId = freezed,
    Object? dateString = freezed,
  }) {
    return _then(
      _value.copyWith(
            taskId:
                null == taskId
                    ? _value.taskId
                    : taskId // ignore: cast_nullable_to_non_nullable
                        as String,
            taskName:
                null == taskName
                    ? _value.taskName
                    : taskName // ignore: cast_nullable_to_non_nullable
                        as String,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            dueDate:
                null == dueDate
                    ? _value.dueDate
                    : dueDate // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            completed:
                null == completed
                    ? _value.completed
                    : completed // ignore: cast_nullable_to_non_nullable
                        as bool,
            photoRequired:
                null == photoRequired
                    ? _value.photoRequired
                    : photoRequired // ignore: cast_nullable_to_non_nullable
                        as bool,
            completedBy:
                freezed == completedBy
                    ? _value.completedBy
                    : completedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            completedByUserId:
                freezed == completedByUserId
                    ? _value.completedByUserId
                    : completedByUserId // ignore: cast_nullable_to_non_nullable
                        as String?,
            completedByUserName:
                freezed == completedByUserName
                    ? _value.completedByUserName
                    : completedByUserName // ignore: cast_nullable_to_non_nullable
                        as String?,
            completedByUserEmail:
                freezed == completedByUserEmail
                    ? _value.completedByUserEmail
                    : completedByUserEmail // ignore: cast_nullable_to_non_nullable
                        as String?,
            completedAt:
                freezed == completedAt
                    ? _value.completedAt
                    : completedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            notes:
                freezed == notes
                    ? _value.notes
                    : notes // ignore: cast_nullable_to_non_nullable
                        as String?,
            photoUrl:
                freezed == photoUrl
                    ? _value.photoUrl
                    : photoUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            proofImageUrl:
                freezed == proofImageUrl
                    ? _value.proofImageUrl
                    : proofImageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            notCompletedReason:
                freezed == notCompletedReason
                    ? _value.notCompletedReason
                    : notCompletedReason // ignore: cast_nullable_to_non_nullable
                        as String?,
            isCarryForward:
                null == isCarryForward
                    ? _value.isCarryForward
                    : isCarryForward // ignore: cast_nullable_to_non_nullable
                        as bool,
            originalDate:
                freezed == originalDate
                    ? _value.originalDate
                    : originalDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            originalChecklistId:
                freezed == originalChecklistId
                    ? _value.originalChecklistId
                    : originalChecklistId // ignore: cast_nullable_to_non_nullable
                        as String?,
            originalTaskId:
                freezed == originalTaskId
                    ? _value.originalTaskId
                    : originalTaskId // ignore: cast_nullable_to_non_nullable
                        as String?,
            carriedIntoDate:
                freezed == carriedIntoDate
                    ? _value.carriedIntoDate
                    : carriedIntoDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            carryForwardAttempted:
                null == carryForwardAttempted
                    ? _value.carryForwardAttempted
                    : carryForwardAttempted // ignore: cast_nullable_to_non_nullable
                        as bool,
            excludedFromMetrics:
                null == excludedFromMetrics
                    ? _value.excludedFromMetrics
                    : excludedFromMetrics // ignore: cast_nullable_to_non_nullable
                        as bool,
            resolvedLate:
                null == resolvedLate
                    ? _value.resolvedLate
                    : resolvedLate // ignore: cast_nullable_to_non_nullable
                        as bool,
            resolvedAt:
                freezed == resolvedAt
                    ? _value.resolvedAt
                    : resolvedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            organizationId:
                freezed == organizationId
                    ? _value.organizationId
                    : organizationId // ignore: cast_nullable_to_non_nullable
                        as String?,
            locationId:
                freezed == locationId
                    ? _value.locationId
                    : locationId // ignore: cast_nullable_to_non_nullable
                        as String?,
            checklistId:
                freezed == checklistId
                    ? _value.checklistId
                    : checklistId // ignore: cast_nullable_to_non_nullable
                        as String?,
            checklistName:
                freezed == checklistName
                    ? _value.checklistName
                    : checklistName // ignore: cast_nullable_to_non_nullable
                        as String?,
            shiftId:
                freezed == shiftId
                    ? _value.shiftId
                    : shiftId // ignore: cast_nullable_to_non_nullable
                        as String?,
            templateId:
                freezed == templateId
                    ? _value.templateId
                    : templateId // ignore: cast_nullable_to_non_nullable
                        as String?,
            dateString:
                freezed == dateString
                    ? _value.dateString
                    : dateString // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TaskDataImplCopyWith<$Res>
    implements $TaskDataCopyWith<$Res> {
  factory _$$TaskDataImplCopyWith(
    _$TaskDataImpl value,
    $Res Function(_$TaskDataImpl) then,
  ) = __$$TaskDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String taskId,
    String taskName,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime dueDate,
    bool completed,
    bool photoRequired,
    String? completedBy,
    String? completedByUserId,
    String? completedByUserName,
    String? completedByUserEmail,
    @TimestampConverter() DateTime? completedAt,
    String? notes,
    String? photoUrl,
    String? proofImageUrl,
    String? description,
    String? notCompletedReason,
    bool isCarryForward,
    @TimestampConverter() DateTime? originalDate,
    String? originalChecklistId,
    String? originalTaskId,
    @TimestampConverter() DateTime? carriedIntoDate,
    bool carryForwardAttempted,
    bool excludedFromMetrics,
    bool resolvedLate,
    @TimestampConverter() DateTime? resolvedAt,
    String? organizationId,
    String? locationId,
    String? checklistId,
    String? checklistName,
    String? shiftId,
    String? templateId,
    String? dateString,
  });
}

/// @nodoc
class __$$TaskDataImplCopyWithImpl<$Res>
    extends _$TaskDataCopyWithImpl<$Res, _$TaskDataImpl>
    implements _$$TaskDataImplCopyWith<$Res> {
  __$$TaskDataImplCopyWithImpl(
    _$TaskDataImpl _value,
    $Res Function(_$TaskDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? taskId = null,
    Object? taskName = null,
    Object? createdAt = null,
    Object? dueDate = null,
    Object? completed = null,
    Object? photoRequired = null,
    Object? completedBy = freezed,
    Object? completedByUserId = freezed,
    Object? completedByUserName = freezed,
    Object? completedByUserEmail = freezed,
    Object? completedAt = freezed,
    Object? notes = freezed,
    Object? photoUrl = freezed,
    Object? proofImageUrl = freezed,
    Object? description = freezed,
    Object? notCompletedReason = freezed,
    Object? isCarryForward = null,
    Object? originalDate = freezed,
    Object? originalChecklistId = freezed,
    Object? originalTaskId = freezed,
    Object? carriedIntoDate = freezed,
    Object? carryForwardAttempted = null,
    Object? excludedFromMetrics = null,
    Object? resolvedLate = null,
    Object? resolvedAt = freezed,
    Object? organizationId = freezed,
    Object? locationId = freezed,
    Object? checklistId = freezed,
    Object? checklistName = freezed,
    Object? shiftId = freezed,
    Object? templateId = freezed,
    Object? dateString = freezed,
  }) {
    return _then(
      _$TaskDataImpl(
        taskId:
            null == taskId
                ? _value.taskId
                : taskId // ignore: cast_nullable_to_non_nullable
                    as String,
        taskName:
            null == taskName
                ? _value.taskName
                : taskName // ignore: cast_nullable_to_non_nullable
                    as String,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        dueDate:
            null == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        completed:
            null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                    as bool,
        photoRequired:
            null == photoRequired
                ? _value.photoRequired
                : photoRequired // ignore: cast_nullable_to_non_nullable
                    as bool,
        completedBy:
            freezed == completedBy
                ? _value.completedBy
                : completedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        completedByUserId:
            freezed == completedByUserId
                ? _value.completedByUserId
                : completedByUserId // ignore: cast_nullable_to_non_nullable
                    as String?,
        completedByUserName:
            freezed == completedByUserName
                ? _value.completedByUserName
                : completedByUserName // ignore: cast_nullable_to_non_nullable
                    as String?,
        completedByUserEmail:
            freezed == completedByUserEmail
                ? _value.completedByUserEmail
                : completedByUserEmail // ignore: cast_nullable_to_non_nullable
                    as String?,
        completedAt:
            freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        notes:
            freezed == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                    as String?,
        photoUrl:
            freezed == photoUrl
                ? _value.photoUrl
                : photoUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        proofImageUrl:
            freezed == proofImageUrl
                ? _value.proofImageUrl
                : proofImageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        notCompletedReason:
            freezed == notCompletedReason
                ? _value.notCompletedReason
                : notCompletedReason // ignore: cast_nullable_to_non_nullable
                    as String?,
        isCarryForward:
            null == isCarryForward
                ? _value.isCarryForward
                : isCarryForward // ignore: cast_nullable_to_non_nullable
                    as bool,
        originalDate:
            freezed == originalDate
                ? _value.originalDate
                : originalDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        originalChecklistId:
            freezed == originalChecklistId
                ? _value.originalChecklistId
                : originalChecklistId // ignore: cast_nullable_to_non_nullable
                    as String?,
        originalTaskId:
            freezed == originalTaskId
                ? _value.originalTaskId
                : originalTaskId // ignore: cast_nullable_to_non_nullable
                    as String?,
        carriedIntoDate:
            freezed == carriedIntoDate
                ? _value.carriedIntoDate
                : carriedIntoDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        carryForwardAttempted:
            null == carryForwardAttempted
                ? _value.carryForwardAttempted
                : carryForwardAttempted // ignore: cast_nullable_to_non_nullable
                    as bool,
        excludedFromMetrics:
            null == excludedFromMetrics
                ? _value.excludedFromMetrics
                : excludedFromMetrics // ignore: cast_nullable_to_non_nullable
                    as bool,
        resolvedLate:
            null == resolvedLate
                ? _value.resolvedLate
                : resolvedLate // ignore: cast_nullable_to_non_nullable
                    as bool,
        resolvedAt:
            freezed == resolvedAt
                ? _value.resolvedAt
                : resolvedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        organizationId:
            freezed == organizationId
                ? _value.organizationId
                : organizationId // ignore: cast_nullable_to_non_nullable
                    as String?,
        locationId:
            freezed == locationId
                ? _value.locationId
                : locationId // ignore: cast_nullable_to_non_nullable
                    as String?,
        checklistId:
            freezed == checklistId
                ? _value.checklistId
                : checklistId // ignore: cast_nullable_to_non_nullable
                    as String?,
        checklistName:
            freezed == checklistName
                ? _value.checklistName
                : checklistName // ignore: cast_nullable_to_non_nullable
                    as String?,
        shiftId:
            freezed == shiftId
                ? _value.shiftId
                : shiftId // ignore: cast_nullable_to_non_nullable
                    as String?,
        templateId:
            freezed == templateId
                ? _value.templateId
                : templateId // ignore: cast_nullable_to_non_nullable
                    as String?,
        dateString:
            freezed == dateString
                ? _value.dateString
                : dateString // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TaskDataImpl implements _TaskData {
  _$TaskDataImpl({
    required this.taskId,
    required this.taskName,
    @TimestampConverter() required this.createdAt,
    @TimestampConverter() required this.dueDate,
    this.completed = false,
    this.photoRequired = false,
    this.completedBy,
    this.completedByUserId,
    this.completedByUserName,
    this.completedByUserEmail,
    @TimestampConverter() this.completedAt,
    this.notes,
    this.photoUrl,
    this.proofImageUrl,
    this.description,
    this.notCompletedReason,
    this.isCarryForward = false,
    @TimestampConverter() this.originalDate,
    this.originalChecklistId,
    this.originalTaskId,
    @TimestampConverter() this.carriedIntoDate,
    this.carryForwardAttempted = false,
    this.excludedFromMetrics = false,
    this.resolvedLate = false,
    @TimestampConverter() this.resolvedAt,
    this.organizationId,
    this.locationId,
    this.checklistId,
    this.checklistName,
    this.shiftId,
    this.templateId,
    this.dateString,
  });

  factory _$TaskDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskDataImplFromJson(json);

  // Identity
  @override
  final String taskId;
  @override
  final String taskName;
  // Timestamps
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @TimestampConverter()
  final DateTime dueDate;
  // Status
  @override
  @JsonKey()
  final bool completed;
  @override
  @JsonKey()
  final bool photoRequired;
  // Completion metadata
  @override
  final String? completedBy;
  @override
  final String? completedByUserId;
  @override
  final String? completedByUserName;
  @override
  final String? completedByUserEmail;
  @override
  @TimestampConverter()
  final DateTime? completedAt;
  // Content
  @override
  final String? notes;
  @override
  final String? photoUrl;
  // Canonical image field
  @override
  final String? proofImageUrl;
  // Legacy alias (kept for compatibility)
  @override
  final String? description;
  // Legacy/aux text for migration
  @override
  final String? notCompletedReason;
  // Carry-forward fields
  @override
  @JsonKey()
  final bool isCarryForward;
  @override
  @TimestampConverter()
  final DateTime? originalDate;
  @override
  final String? originalChecklistId;
  @override
  final String? originalTaskId;
  @override
  @TimestampConverter()
  final DateTime? carriedIntoDate;
  @override
  @JsonKey()
  final bool carryForwardAttempted;
  // Analytics / flags
  @override
  @JsonKey()
  final bool excludedFromMetrics;
  @override
  @JsonKey()
  final bool resolvedLate;
  @override
  @TimestampConverter()
  final DateTime? resolvedAt;
  // Optional denormalized fields to enable collectionGroup queries
  @override
  final String? organizationId;
  @override
  final String? locationId;
  @override
  final String? checklistId;
  @override
  final String? checklistName;
  @override
  final String? shiftId;
  @override
  final String? templateId;
  @override
  final String? dateString;

  @override
  String toString() {
    return 'TaskData(taskId: $taskId, taskName: $taskName, createdAt: $createdAt, dueDate: $dueDate, completed: $completed, photoRequired: $photoRequired, completedBy: $completedBy, completedByUserId: $completedByUserId, completedByUserName: $completedByUserName, completedByUserEmail: $completedByUserEmail, completedAt: $completedAt, notes: $notes, photoUrl: $photoUrl, proofImageUrl: $proofImageUrl, description: $description, notCompletedReason: $notCompletedReason, isCarryForward: $isCarryForward, originalDate: $originalDate, originalChecklistId: $originalChecklistId, originalTaskId: $originalTaskId, carriedIntoDate: $carriedIntoDate, carryForwardAttempted: $carryForwardAttempted, excludedFromMetrics: $excludedFromMetrics, resolvedLate: $resolvedLate, resolvedAt: $resolvedAt, organizationId: $organizationId, locationId: $locationId, checklistId: $checklistId, checklistName: $checklistName, shiftId: $shiftId, templateId: $templateId, dateString: $dateString)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskDataImpl &&
            (identical(other.taskId, taskId) || other.taskId == taskId) &&
            (identical(other.taskName, taskName) ||
                other.taskName == taskName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.photoRequired, photoRequired) ||
                other.photoRequired == photoRequired) &&
            (identical(other.completedBy, completedBy) ||
                other.completedBy == completedBy) &&
            (identical(other.completedByUserId, completedByUserId) ||
                other.completedByUserId == completedByUserId) &&
            (identical(other.completedByUserName, completedByUserName) ||
                other.completedByUserName == completedByUserName) &&
            (identical(other.completedByUserEmail, completedByUserEmail) ||
                other.completedByUserEmail == completedByUserEmail) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.proofImageUrl, proofImageUrl) ||
                other.proofImageUrl == proofImageUrl) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.notCompletedReason, notCompletedReason) ||
                other.notCompletedReason == notCompletedReason) &&
            (identical(other.isCarryForward, isCarryForward) ||
                other.isCarryForward == isCarryForward) &&
            (identical(other.originalDate, originalDate) ||
                other.originalDate == originalDate) &&
            (identical(other.originalChecklistId, originalChecklistId) ||
                other.originalChecklistId == originalChecklistId) &&
            (identical(other.originalTaskId, originalTaskId) ||
                other.originalTaskId == originalTaskId) &&
            (identical(other.carriedIntoDate, carriedIntoDate) ||
                other.carriedIntoDate == carriedIntoDate) &&
            (identical(other.carryForwardAttempted, carryForwardAttempted) ||
                other.carryForwardAttempted == carryForwardAttempted) &&
            (identical(other.excludedFromMetrics, excludedFromMetrics) ||
                other.excludedFromMetrics == excludedFromMetrics) &&
            (identical(other.resolvedLate, resolvedLate) ||
                other.resolvedLate == resolvedLate) &&
            (identical(other.resolvedAt, resolvedAt) ||
                other.resolvedAt == resolvedAt) &&
            (identical(other.organizationId, organizationId) ||
                other.organizationId == organizationId) &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            (identical(other.checklistId, checklistId) ||
                other.checklistId == checklistId) &&
            (identical(other.checklistName, checklistName) ||
                other.checklistName == checklistName) &&
            (identical(other.shiftId, shiftId) || other.shiftId == shiftId) &&
            (identical(other.templateId, templateId) ||
                other.templateId == templateId) &&
            (identical(other.dateString, dateString) ||
                other.dateString == dateString));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    taskId,
    taskName,
    createdAt,
    dueDate,
    completed,
    photoRequired,
    completedBy,
    completedByUserId,
    completedByUserName,
    completedByUserEmail,
    completedAt,
    notes,
    photoUrl,
    proofImageUrl,
    description,
    notCompletedReason,
    isCarryForward,
    originalDate,
    originalChecklistId,
    originalTaskId,
    carriedIntoDate,
    carryForwardAttempted,
    excludedFromMetrics,
    resolvedLate,
    resolvedAt,
    organizationId,
    locationId,
    checklistId,
    checklistName,
    shiftId,
    templateId,
    dateString,
  ]);

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskDataImplCopyWith<_$TaskDataImpl> get copyWith =>
      __$$TaskDataImplCopyWithImpl<_$TaskDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskDataImplToJson(this);
  }
}

abstract class _TaskData implements TaskData {
  factory _TaskData({
    required final String taskId,
    required final String taskName,
    @TimestampConverter() required final DateTime createdAt,
    @TimestampConverter() required final DateTime dueDate,
    final bool completed,
    final bool photoRequired,
    final String? completedBy,
    final String? completedByUserId,
    final String? completedByUserName,
    final String? completedByUserEmail,
    @TimestampConverter() final DateTime? completedAt,
    final String? notes,
    final String? photoUrl,
    final String? proofImageUrl,
    final String? description,
    final String? notCompletedReason,
    final bool isCarryForward,
    @TimestampConverter() final DateTime? originalDate,
    final String? originalChecklistId,
    final String? originalTaskId,
    @TimestampConverter() final DateTime? carriedIntoDate,
    final bool carryForwardAttempted,
    final bool excludedFromMetrics,
    final bool resolvedLate,
    @TimestampConverter() final DateTime? resolvedAt,
    final String? organizationId,
    final String? locationId,
    final String? checklistId,
    final String? checklistName,
    final String? shiftId,
    final String? templateId,
    final String? dateString,
  }) = _$TaskDataImpl;

  factory _TaskData.fromJson(Map<String, dynamic> json) =
      _$TaskDataImpl.fromJson;

  // Identity
  @override
  String get taskId;
  @override
  String get taskName; // Timestamps
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @TimestampConverter()
  DateTime get dueDate; // Status
  @override
  bool get completed;
  @override
  bool get photoRequired; // Completion metadata
  @override
  String? get completedBy;
  @override
  String? get completedByUserId;
  @override
  String? get completedByUserName;
  @override
  String? get completedByUserEmail;
  @override
  @TimestampConverter()
  DateTime? get completedAt; // Content
  @override
  String? get notes;
  @override
  String? get photoUrl; // Canonical image field
  @override
  String? get proofImageUrl; // Legacy alias (kept for compatibility)
  @override
  String? get description; // Legacy/aux text for migration
  @override
  String? get notCompletedReason; // Carry-forward fields
  @override
  bool get isCarryForward;
  @override
  @TimestampConverter()
  DateTime? get originalDate;
  @override
  String? get originalChecklistId;
  @override
  String? get originalTaskId;
  @override
  @TimestampConverter()
  DateTime? get carriedIntoDate;
  @override
  bool get carryForwardAttempted; // Analytics / flags
  @override
  bool get excludedFromMetrics;
  @override
  bool get resolvedLate;
  @override
  @TimestampConverter()
  DateTime? get resolvedAt; // Optional denormalized fields to enable collectionGroup queries
  @override
  String? get organizationId;
  @override
  String? get locationId;
  @override
  String? get checklistId;
  @override
  String? get checklistName;
  @override
  String? get shiftId;
  @override
  String? get templateId;
  @override
  String? get dateString;

  /// Create a copy of TaskData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskDataImplCopyWith<_$TaskDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
