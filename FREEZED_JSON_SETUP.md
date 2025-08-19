# Freezed & JSON Serialization Setup

This document outlines the complete setup for Freezed immutable data classes with JSON serialization in this Flutter project.

## Overview

Our project uses:
- **Freezed**: For immutable data classes with code generation
- **json_serializable**: For JSON serialization
- **Custom Timestamp Converters**: For Cloud Firestore DateTime handling

## Dependencies

### pubspec.yaml
```yaml
dependencies:
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  cloud_firestore: ^5.6.5

dev_dependencies:
  build_runner: ^2.4.11
  freezed: ^2.5.3
  json_serializable: ^6.8.0
```

## Model Structure

### 1. Basic Model Template

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hands_app/data/models/timestamp_converter.dart';

part 'example_model.freezed.dart';
part 'example_model.g.dart';

@freezed
class ExampleModel with _$ExampleModel {
  factory ExampleModel({
    required String id,
    required String name,
    @TimestampConverter() required DateTime createdAt,
    @NullableTimestampConverter() DateTime? updatedAt,
    @Default(false) bool isActive,
    @Default([]) List<String> tags,
  }) = _ExampleModel;

  factory ExampleModel.fromJson(Map<String, dynamic> json) =>
      _$ExampleModelFromJson(json);
}
```

### 2. Timestamp Converters

Located in `lib/data/models/timestamp_converter.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      throw Exception('NullableTimestampConverter: Unexpected type: ${value.runtimeType}');
    }
  }

  @override
  Object? toJson(DateTime? date) => date == null ? null : Timestamp.fromDate(date);
}

class TimestampConverter implements JsonConverter<DateTime, Object?> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object? value) {
    if (value == null) {
      throw Exception('TimestampConverter: value is null for a required DateTime field');
    }
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else {
      throw Exception('TimestampConverter: Unexpected type: ${value.runtimeType}');
    }
  }

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}
```

## Existing Models

### TaskData
- **Location**: `lib/data/models/task_data.dart`
- **Purpose**: Represents individual tasks with completion tracking
- **Key Features**: Carry-forward logic, photo requirements, analytics exclusion
- **Timestamps**: `createdAt`, `dueDate`, `completedAt`, `originalDate`, `carriedIntoDate`, `resolvedAt`

### ShiftData
- **Location**: `lib/data/models/shift_data.dart`
- **Purpose**: Represents work shifts with scheduling information
- **Key Features**: Staffing levels, job types, recurring schedules
- **Timestamps**: `createdAt`, `shiftDate`, `updatedAt`

### DailyChecklist & DailyTask
- **Location**: `lib/data/models/daily_checklist.dart`
- **Purpose**: Daily checklists containing multiple tasks
- **Key Features**: Template-based generation, completion tracking
- **Timestamps**: `createdAt`, `updatedAt`, `completedAt`

## Code Generation Commands

### VS Code Tasks (Recommended)
Use the built-in VS Code tasks via Command Palette (`Cmd+Shift+P`):

1. **Generate Freezed/JSON Code**: `dart run build_runner build`
2. **Generate Freezed/JSON Code (Delete Conflicts)**: `dart run build_runner build --delete-conflicting-outputs`
3. **Watch Freezed/JSON Code**: `dart run build_runner watch` (runs in background)

### Terminal Commands
```bash
# One-time generation
dart run build_runner build

# Delete conflicting outputs and regenerate
dart run build_runner build --delete-conflicting-outputs

# Watch mode (continuous generation)
dart run build_runner watch

# Clean generated files
dart run build_runner clean
```

## Generated Files

For each model (e.g., `task_data.dart`), the following files are auto-generated:
- `task_data.freezed.dart`: Freezed immutable class implementation
- `task_data.g.dart`: JSON serialization methods

**⚠️ Never edit generated files manually!** They will be overwritten.

## Common Patterns

### 1. Required Fields
```dart
required String id,
required String name,
```

### 2. Optional Fields with Defaults
```dart
@Default(false) bool isActive,
@Default([]) List<String> items,
@Default({}) Map<String, dynamic> metadata,
```

### 3. Nullable Fields
```dart
String? description,
@NullableTimestampConverter() DateTime? updatedAt,
```

### 4. DateTime Fields
```dart
@TimestampConverter() required DateTime createdAt,  // Required
@NullableTimestampConverter() DateTime? updatedAt,  // Optional
```

### 5. Complex Types
```dart
@Default(<String>[]) List<String> tags,
@Default(<String, int>{}) Map<String, int> counts,
```

## Best Practices

1. **Always import timestamp converters** for DateTime fields
2. **Use meaningful defaults** with `@Default()` annotation
3. **Regenerate after model changes**: Run build_runner after editing models
4. **Keep generated files in version control**: Commit `.freezed.dart` and `.g.dart` files
5. **Use nullable types sparingly**: Prefer defaults over nullable fields when possible

## Troubleshooting

### Build Runner Issues
```bash
# If generation fails, try cleaning first
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### Constructor Mismatches
- Ensure all fields in the factory constructor match the generated code
- Check that @Default values match the expected types
- Verify timestamp converter annotations are correct

### Import Errors
- Ensure all required imports are present
- Check that the `part` statements reference the correct files
- Verify timestamp converter imports for DateTime fields

## VS Code Integration

The project includes pre-configured VS Code tasks for easy code generation:

- Open Command Palette (`Cmd+Shift+P`)
- Type "Tasks: Run Task"
- Select the desired build_runner task

This provides a seamless workflow for maintaining generated code.
