# Handoff Report - Milestone 2 Stress Test and Verification

**Verdict**: **FAIL** (due to a copyWith shadowing bug on AlarmModel)

## 1. Observation
I observed and analyzed the implementations of Milestone 2 features:
- **Medication Deletion Check**: `lib/features/medications/data/medication_repository.dart` at line 129:
  ```dart
  Future<void> deleteMedication(String name) async {
    final activeAlarms = await (_db.select(_db.alarms)
          ..where((t) => (t.medName.equals(name) | t.name.equals(name)) & (t.enabled.equals(true) | t.active.equals(true))))
        .get();
    if (activeAlarms.isNotEmpty) {
      throw Exception('Cannot delete medication in use by active/enabled alarms.');
    }
  ```
- **copyWith Sentinel Pattern**: `lib/features/alarms/data/alarm_repository.dart` at line 949:
  ```dart
  const Object _sentinel = Object();

  extension AlarmModelCopyWith on AlarmModel {
    AlarmModel copyWith({
      Object? id = _sentinel,
      ...
  ```
  However, in `lib/features/alarms/data/alarm_model.dart` at line 171, a normal instance method copyWith is also defined:
  ```dart
  class AlarmModel {
    ...
    AlarmModel copyWith({
      int? id,
      ...
  ```
- **Unification of ANVISA DB search**: `lib/features/alarms/data/medication_search_service.dart` at line 34, containing `_loadDb()` and `search()`.

I wrote a test suite in `test/milestone_2_challenger_test.dart` and executed tests:
- Executed existing tests via `flutter test` which passed 225/225 tests successfully.
- Executed `flutter test test/milestone_2_challenger_test.dart` which confirmed:
  1. **Medication Deletion Check**: Successfully blocks deletion if referencing alarms are enabled/active, and allows deletion when referencing alarms are both disabled and inactive.
  2. **copyWith Sentinel Pattern**: Fails when calling `alarm.copyWith(dosage: null)` directly on the model instance (returns `'100mg'` instead of `null` because it falls back to the instance method defined on `AlarmModel` which uses the `??` operator instead of the Sentinel). It only succeeds if the extension is explicitly casted/invoked via `AlarmModelCopyWith(alarm).copyWith(dosage: null)`.
  3. **MedicationSearchService**: Fuzzy search ignores accents, casing, and supports Levenshtein distance matching. The database is cached and loaded only once across multiple requests.

## 2. Logic Chain
1. In Dart, instance methods take precedence over extension methods of the same name.
2. `AlarmModel` has a `copyWith` instance method in `lib/features/alarms/data/alarm_model.dart:171` that uses standard null-coalescing (`dosage: dosage ?? this.dosage`).
3. The custom Sentinel copyWith was written as an extension `AlarmModelCopyWith` inside `lib/features/alarms/data/alarm_repository.dart:951`.
4. Because the instance method shadows the extension, direct calls to `alarm.copyWith(dosage: null)` call the instance method and fail to overwrite values to null.
5. Therefore, the Sentinel pattern is broken for everyday direct usages of `copyWith` on `AlarmModel` instances unless developers explicitly wrap it like `AlarmModelCopyWith(alarm).copyWith(...)`.
6. Thus, Milestone 2 has a failure/flaw in its copyWith Sentinel pattern implementation.

## 3. Caveats
- No caveats. The behavior was confirmed via targeted tests using Flutter's compiler and test framework.

## 4. Conclusion
- **Medication Deletion Check**: Correctly implemented and works as expected, including edge cases (enabled vs active vs disabled/inactive).
- **MedicationSearchService**: Correctly implemented, caches resources, runs in isolates, and matches query terms while ignoring accents.
- **copyWith Sentinel Pattern**: **FAILED**. The implementation is shadowed by the instance method, rendering the extension useless in normal code usage. To fix this, the instance method `copyWith` on `AlarmModel` in `lib/features/alarms/data/alarm_model.dart` must be replaced or updated with the Sentinel pattern logic directly.

## 5. Verification Method
Run the challenger test suite using the command below:
```bash
flutter test test/milestone_2_challenger_test.dart
```
Inspect the tests inside `test/milestone_2_challenger_test.dart` to see the comparison between `AlarmModelCopyWith(original).copyWith(...)` (which passes) and `original.copyWith(...)` (which demonstrates the shadowing bug and only passes because we assert the shadowed behavior of retaining the old value).
