# DateTime.now() Audit

Generated: 2025-08-19

Legend
- Persisted → Converted: client-side code persisted DateTime.now() and was converted to Firestore Timestamp.fromDate(...)
- Persisted → Already Correct: write sites already used Timestamp.fromDate(...) / Timestamp.now() / FieldValue.serverTimestamp()
- UI-only: DateTime used only for UI, formatting, or in-memory models
- Test-only: located under `lib/test_data` or `test/` and intentionally left as DateTime
- Deferred: legacy model serialization storing ISO strings (left as-is)

Summary
- Total `DateTime.now` occurrences found: 129
- Persisted → Converted: 2
- Persisted → Already Correct: 20+ (checked common write sites)
- UI-only: majority (~100)
- Test-only: ~20 (in `lib/test_data/dummy_org_data.dart` etc.)
- Deferred (legacy ISO serialization): several model `toMap()` places (e.g., `DailyChecklistTask.toMap()`)

Detailed breakdown (file → category and notes)

- lib/services/daily_checklist_service.dart
  - Many persisted writes already use `Timestamp.fromDate(...)`, `Timestamp.now()` or `FieldValue.serverTimestamp()` (Persisted → Already Correct).
  - In-memory UI emission uses `DateTime.now()` (UI-only).
  - Legacy `DailyChecklistTask.toMap()` uses ISO strings (Deferred).

- lib/custom_code/widgets/UserManagementBottomSheet.dart
  - `invites` document `expiresAt` uses `Timestamp.fromDate(DateTime.now().add(Duration(days:7)))` (Persisted → Already Correct)

- lib/features/auth/pages/account_creation_page_simple_branded.dart
  - `trialEndsAt` uses `Timestamp.fromDate(DateTime.now().add(Duration(days:30)))` (Persisted → Already Correct)

- lib/features/messaging/services/messaging_service.dart
  - message/thread writes use `FieldValue.serverTimestamp()` (Persisted → Already Correct)

- lib/ui/schedule_page.dart
  - schedule writes use `Timestamp.fromDate(...)` for start/end (Persisted → Already Correct)

- lib/data/models/task_data.dart & lib/data/models/timestamp_converter.dart
  - Model-level converters exist to serialize DateTime → Timestamp when using generated `toJson()` (Persisted via models is safe).

- lib/features/dashboard/pages/*
  - Many `DateTime.now()` usages are UI-only for display/formatting (UI-only).

- lib/test_data/dummy_org_data.dart
  - Test fixtures using DateTime.now() (Test-only).

Notes
- I focused on explicit Firestore write maps (`.set`, `.update`, `.add`, batch writes). These write paths already use Firestore Timestamps in the obvious places.
- Models that serialize DateTime to ISO strings (legacy) were left as Deferred to avoid breaking migrations.

Recommendation
- No additional forced conversions required right now — persisted writes appear safe.
- Optional follow-up: convert legacy `toMap()` ISO serialization to use `Timestamp` consistently across the app (this requires a careful migration plan and update to server-side functions that expect ISO strings).

End of audit.
