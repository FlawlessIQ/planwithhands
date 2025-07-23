// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_checklist.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

DailyChecklist _$DailyChecklistFromJson(Map<String, dynamic> json) {
  return _DailyChecklist.fromJson(json);
}

/// @nodoc
mixin _$DailyChecklist {
  String get id => throw _privateConstructorUsedError;
  String get organizationId => throw _privateConstructorUsedError;
  String get locationId => throw _privateConstructorUsedError;
  String get shiftId => throw _privateConstructorUsedError;
  String get templateId => throw _privateConstructorUsedError;
  String get templateName => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError; // YYYY-MM-DD format
  List<DailyTask> get tasks => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;
  String? get completedBy => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime get createdAt => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this DailyChecklist to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyChecklist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyChecklistCopyWith<DailyChecklist> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyChecklistCopyWith<$Res> {
  factory $DailyChecklistCopyWith(
    DailyChecklist value,
    $Res Function(DailyChecklist) then,
  ) = _$DailyChecklistCopyWithImpl<$Res, DailyChecklist>;
  @useResult
  $Res call({
    String id,
    String organizationId,
    String locationId,
    String shiftId,
    String templateId,
    String templateName,
    String date,
    List<DailyTask> tasks,
    bool isCompleted,
    String? completedBy,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class _$DailyChecklistCopyWithImpl<$Res, $Val extends DailyChecklist>
    implements $DailyChecklistCopyWith<$Res> {
  _$DailyChecklistCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyChecklist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? organizationId = null,
    Object? locationId = null,
    Object? shiftId = null,
    Object? templateId = null,
    Object? templateName = null,
    Object? date = null,
    Object? tasks = null,
    Object? isCompleted = null,
    Object? completedBy = freezed,
    Object? completedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            organizationId:
                null == organizationId
                    ? _value.organizationId
                    : organizationId // ignore: cast_nullable_to_non_nullable
                        as String,
            locationId:
                null == locationId
                    ? _value.locationId
                    : locationId // ignore: cast_nullable_to_non_nullable
                        as String,
            shiftId:
                null == shiftId
                    ? _value.shiftId
                    : shiftId // ignore: cast_nullable_to_non_nullable
                        as String,
            templateId:
                null == templateId
                    ? _value.templateId
                    : templateId // ignore: cast_nullable_to_non_nullable
                        as String,
            templateName:
                null == templateName
                    ? _value.templateName
                    : templateName // ignore: cast_nullable_to_non_nullable
                        as String,
            date:
                null == date
                    ? _value.date
                    : date // ignore: cast_nullable_to_non_nullable
                        as String,
            tasks:
                null == tasks
                    ? _value.tasks
                    : tasks // ignore: cast_nullable_to_non_nullable
                        as List<DailyTask>,
            isCompleted:
                null == isCompleted
                    ? _value.isCompleted
                    : isCompleted // ignore: cast_nullable_to_non_nullable
                        as bool,
            completedBy:
                freezed == completedBy
                    ? _value.completedBy
                    : completedBy // ignore: cast_nullable_to_non_nullable
                        as String?,
            completedAt:
                freezed == completedAt
                    ? _value.completedAt
                    : completedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            createdAt:
                null == createdAt
                    ? _value.createdAt
                    : createdAt // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            updatedAt:
                freezed == updatedAt
                    ? _value.updatedAt
                    : updatedAt // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyChecklistImplCopyWith<$Res>
    implements $DailyChecklistCopyWith<$Res> {
  factory _$$DailyChecklistImplCopyWith(
    _$DailyChecklistImpl value,
    $Res Function(_$DailyChecklistImpl) then,
  ) = __$$DailyChecklistImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String organizationId,
    String locationId,
    String shiftId,
    String templateId,
    String templateName,
    String date,
    List<DailyTask> tasks,
    bool isCompleted,
    String? completedBy,
    @TimestampConverter() DateTime? completedAt,
    @TimestampConverter() DateTime createdAt,
    @TimestampConverter() DateTime? updatedAt,
  });
}

/// @nodoc
class __$$DailyChecklistImplCopyWithImpl<$Res>
    extends _$DailyChecklistCopyWithImpl<$Res, _$DailyChecklistImpl>
    implements _$$DailyChecklistImplCopyWith<$Res> {
  __$$DailyChecklistImplCopyWithImpl(
    _$DailyChecklistImpl _value,
    $Res Function(_$DailyChecklistImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyChecklist
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? organizationId = null,
    Object? locationId = null,
    Object? shiftId = null,
    Object? templateId = null,
    Object? templateName = null,
    Object? date = null,
    Object? tasks = null,
    Object? isCompleted = null,
    Object? completedBy = freezed,
    Object? completedAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
  }) {
    return _then(
      _$DailyChecklistImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        organizationId:
            null == organizationId
                ? _value.organizationId
                : organizationId // ignore: cast_nullable_to_non_nullable
                    as String,
        locationId:
            null == locationId
                ? _value.locationId
                : locationId // ignore: cast_nullable_to_non_nullable
                    as String,
        shiftId:
            null == shiftId
                ? _value.shiftId
                : shiftId // ignore: cast_nullable_to_non_nullable
                    as String,
        templateId:
            null == templateId
                ? _value.templateId
                : templateId // ignore: cast_nullable_to_non_nullable
                    as String,
        templateName:
            null == templateName
                ? _value.templateName
                : templateName // ignore: cast_nullable_to_non_nullable
                    as String,
        date:
            null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                    as String,
        tasks:
            null == tasks
                ? _value._tasks
                : tasks // ignore: cast_nullable_to_non_nullable
                    as List<DailyTask>,
        isCompleted:
            null == isCompleted
                ? _value.isCompleted
                : isCompleted // ignore: cast_nullable_to_non_nullable
                    as bool,
        completedBy:
            freezed == completedBy
                ? _value.completedBy
                : completedBy // ignore: cast_nullable_to_non_nullable
                    as String?,
        completedAt:
            freezed == completedAt
                ? _value.completedAt
                : completedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        createdAt:
            null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        updatedAt:
            freezed == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyChecklistImpl implements _DailyChecklist {
  _$DailyChecklistImpl({
    required this.id,
    required this.organizationId,
    required this.locationId,
    required this.shiftId,
    required this.templateId,
    required this.templateName,
    required this.date,
    final List<DailyTask> tasks = const [],
    this.isCompleted = false,
    this.completedBy,
    @TimestampConverter() this.completedAt,
    @TimestampConverter() required this.createdAt,
    @TimestampConverter() this.updatedAt,
  }) : _tasks = tasks;

  factory _$DailyChecklistImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyChecklistImplFromJson(json);

  @override
  final String id;
  @override
  final String organizationId;
  @override
  final String locationId;
  @override
  final String shiftId;
  @override
  final String templateId;
  @override
  final String templateName;
  @override
  final String date;
  // YYYY-MM-DD format
  final List<DailyTask> _tasks;
  // YYYY-MM-DD format
  @override
  @JsonKey()
  List<DailyTask> get tasks {
    if (_tasks is EqualUnmodifiableListView) return _tasks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tasks);
  }

  @override
  @JsonKey()
  final bool isCompleted;
  @override
  final String? completedBy;
  @override
  @TimestampConverter()
  final DateTime? completedAt;
  @override
  @TimestampConverter()
  final DateTime createdAt;
  @override
  @TimestampConverter()
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'DailyChecklist(id: $id, organizationId: $organizationId, locationId: $locationId, shiftId: $shiftId, templateId: $templateId, templateName: $templateName, date: $date, tasks: $tasks, isCompleted: $isCompleted, completedBy: $completedBy, completedAt: $completedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyChecklistImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.organizationId, organizationId) ||
                other.organizationId == organizationId) &&
            (identical(other.locationId, locationId) ||
                other.locationId == locationId) &&
            (identical(other.shiftId, shiftId) || other.shiftId == shiftId) &&
            (identical(other.templateId, templateId) ||
                other.templateId == templateId) &&
            (identical(other.templateName, templateName) ||
                other.templateName == templateName) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other._tasks, _tasks) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.completedBy, completedBy) ||
                other.completedBy == completedBy) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    organizationId,
    locationId,
    shiftId,
    templateId,
    templateName,
    date,
    const DeepCollectionEquality().hash(_tasks),
    isCompleted,
    completedBy,
    completedAt,
    createdAt,
    updatedAt,
  );

  /// Create a copy of DailyChecklist
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyChecklistImplCopyWith<_$DailyChecklistImpl> get copyWith =>
      __$$DailyChecklistImplCopyWithImpl<_$DailyChecklistImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyChecklistImplToJson(this);
  }
}

abstract class _DailyChecklist implements DailyChecklist {
  factory _DailyChecklist({
    required final String id,
    required final String organizationId,
    required final String locationId,
    required final String shiftId,
    required final String templateId,
    required final String templateName,
    required final String date,
    final List<DailyTask> tasks,
    final bool isCompleted,
    final String? completedBy,
    @TimestampConverter() final DateTime? completedAt,
    @TimestampConverter() required final DateTime createdAt,
    @TimestampConverter() final DateTime? updatedAt,
  }) = _$DailyChecklistImpl;

  factory _DailyChecklist.fromJson(Map<String, dynamic> json) =
      _$DailyChecklistImpl.fromJson;

  @override
  String get id;
  @override
  String get organizationId;
  @override
  String get locationId;
  @override
  String get shiftId;
  @override
  String get templateId;
  @override
  String get templateName;
  @override
  String get date; // YYYY-MM-DD format
  @override
  List<DailyTask> get tasks;
  @override
  bool get isCompleted;
  @override
  String? get completedBy;
  @override
  @TimestampConverter()
  DateTime? get completedAt;
  @override
  @TimestampConverter()
  DateTime get createdAt;
  @override
  @TimestampConverter()
  DateTime? get updatedAt;

  /// Create a copy of DailyChecklist
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyChecklistImplCopyWith<_$DailyChecklistImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DailyTask _$DailyTaskFromJson(Map<String, dynamic> json) {
  return _DailyTask.fromJson(json);
}

/// @nodoc
mixin _$DailyTask {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  bool get completed => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  String? get completedBy => throw _privateConstructorUsedError;
  @TimestampConverter()
  DateTime? get completedAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String? get proofImageUrl => throw _privateConstructorUsedError;

  /// Serializes this DailyTask to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DailyTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DailyTaskCopyWith<DailyTask> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyTaskCopyWith<$Res> {
  factory $DailyTaskCopyWith(DailyTask value, $Res Function(DailyTask) then) =
      _$DailyTaskCopyWithImpl<$Res, DailyTask>;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    bool completed,
    int order,
    String? completedBy,
    @TimestampConverter() DateTime? completedAt,
    String? notes,
    String? proofImageUrl,
  });
}

/// @nodoc
class _$DailyTaskCopyWithImpl<$Res, $Val extends DailyTask>
    implements $DailyTaskCopyWith<$Res> {
  _$DailyTaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DailyTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? completed = null,
    Object? order = null,
    Object? completedBy = freezed,
    Object? completedAt = freezed,
    Object? notes = freezed,
    Object? proofImageUrl = freezed,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            completed:
                null == completed
                    ? _value.completed
                    : completed // ignore: cast_nullable_to_non_nullable
                        as bool,
            order:
                null == order
                    ? _value.order
                    : order // ignore: cast_nullable_to_non_nullable
                        as int,
            completedBy:
                freezed == completedBy
                    ? _value.completedBy
                    : completedBy // ignore: cast_nullable_to_non_nullable
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
            proofImageUrl:
                freezed == proofImageUrl
                    ? _value.proofImageUrl
                    : proofImageUrl // ignore: cast_nullable_to_non_nullable
                        as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DailyTaskImplCopyWith<$Res>
    implements $DailyTaskCopyWith<$Res> {
  factory _$$DailyTaskImplCopyWith(
    _$DailyTaskImpl value,
    $Res Function(_$DailyTaskImpl) then,
  ) = __$$DailyTaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    bool completed,
    int order,
    String? completedBy,
    @TimestampConverter() DateTime? completedAt,
    String? notes,
    String? proofImageUrl,
  });
}

/// @nodoc
class __$$DailyTaskImplCopyWithImpl<$Res>
    extends _$DailyTaskCopyWithImpl<$Res, _$DailyTaskImpl>
    implements _$$DailyTaskImplCopyWith<$Res> {
  __$$DailyTaskImplCopyWithImpl(
    _$DailyTaskImpl _value,
    $Res Function(_$DailyTaskImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DailyTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? completed = null,
    Object? order = null,
    Object? completedBy = freezed,
    Object? completedAt = freezed,
    Object? notes = freezed,
    Object? proofImageUrl = freezed,
  }) {
    return _then(
      _$DailyTaskImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        completed:
            null == completed
                ? _value.completed
                : completed // ignore: cast_nullable_to_non_nullable
                    as bool,
        order:
            null == order
                ? _value.order
                : order // ignore: cast_nullable_to_non_nullable
                    as int,
        completedBy:
            freezed == completedBy
                ? _value.completedBy
                : completedBy // ignore: cast_nullable_to_non_nullable
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
        proofImageUrl:
            freezed == proofImageUrl
                ? _value.proofImageUrl
                : proofImageUrl // ignore: cast_nullable_to_non_nullable
                    as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DailyTaskImpl implements _DailyTask {
  _$DailyTaskImpl({
    required this.id,
    required this.title,
    this.description,
    this.completed = false,
    this.order = 0,
    this.completedBy,
    @TimestampConverter() this.completedAt,
    this.notes,
    this.proofImageUrl,
  });

  factory _$DailyTaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$DailyTaskImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String? description;
  @override
  @JsonKey()
  final bool completed;
  @override
  @JsonKey()
  final int order;
  @override
  final String? completedBy;
  @override
  @TimestampConverter()
  final DateTime? completedAt;
  @override
  final String? notes;
  @override
  final String? proofImageUrl;

  @override
  String toString() {
    return 'DailyTask(id: $id, title: $title, description: $description, completed: $completed, order: $order, completedBy: $completedBy, completedAt: $completedAt, notes: $notes, proofImageUrl: $proofImageUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyTaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.completed, completed) ||
                other.completed == completed) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.completedBy, completedBy) ||
                other.completedBy == completedBy) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.proofImageUrl, proofImageUrl) ||
                other.proofImageUrl == proofImageUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    title,
    description,
    completed,
    order,
    completedBy,
    completedAt,
    notes,
    proofImageUrl,
  );

  /// Create a copy of DailyTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyTaskImplCopyWith<_$DailyTaskImpl> get copyWith =>
      __$$DailyTaskImplCopyWithImpl<_$DailyTaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DailyTaskImplToJson(this);
  }
}

abstract class _DailyTask implements DailyTask {
  factory _DailyTask({
    required final String id,
    required final String title,
    final String? description,
    final bool completed,
    final int order,
    final String? completedBy,
    @TimestampConverter() final DateTime? completedAt,
    final String? notes,
    final String? proofImageUrl,
  }) = _$DailyTaskImpl;

  factory _DailyTask.fromJson(Map<String, dynamic> json) =
      _$DailyTaskImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String? get description;
  @override
  bool get completed;
  @override
  int get order;
  @override
  String? get completedBy;
  @override
  @TimestampConverter()
  DateTime? get completedAt;
  @override
  String? get notes;
  @override
  String? get proofImageUrl;

  /// Create a copy of DailyTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DailyTaskImplCopyWith<_$DailyTaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
