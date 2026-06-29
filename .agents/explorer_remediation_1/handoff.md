# Handoff Report: UI and Interaction Fixes (R1, R2, R4) Exploration

This report analyzes the root causes of issues R1, R2, and R4, and details the precise modifications needed to fix them.

---

## 1. Observation

### R1: Alarm Active Screen Dismissal on Snooze
- **File Path**: `lib/features/alarms/data/alarm_repository.dart`
- **Line 743-752**:
  ```dart
  Future<void> snoozeAlarm(int id, int minutes) async {
    final alarmList = await (_db.select(_db.alarms)..where((t) => t.id.equals(id))).get();
    if (alarmList.isEmpty) return;

    final alarm = _toModel(alarmList.first);
    final updated = alarm.copyWith(
      snoozeMin: minutes,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );
  ```
- **Active Alarm Stream Definition (`lib/core/services/alarm_engine.dart` lines 472-476)**:
  ```dart
  Stream<List<AlarmModel>> activeAlarms(ActiveAlarmsRef ref) {
    return ref.watch(alarmRepositoryProvider).watchAllAlarms().map((list) {
      return list.where((a) => a.enabled && a.status == 'ATIVO').toList();
    });
  }
  ```
- **Active Alarm Screen Callback (`lib/features/alarms/presentation/alarm_active_screen.dart` lines 111-116)**:
  ```dart
  Future<void> _snooze(AlarmModel alarm, int minutes) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.snoozeAlarm(alarm.id, minutes);
    ref.invalidate(dashboardNotifierProvider);
    _nextOrDismiss();
  }
  ```

### R2: RenderFlex Overflow in SnoozeModal
- **File Path**: `lib/features/alarms/presentation/snooze_modal.dart`
- **Line 50-66 (Show Modal)**:
  ```dart
  static Future<void> show(
    BuildContext context, {
    ...
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SnoozeModal(
        ...
      ),
    );
  }
  ```
- **Line 118-125 (Build Modal)**:
  ```dart
  @override
  Widget build(BuildContext context) {
    final alarmColor = AppColors.getAlarmColor(widget.alarm.color);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
  ```

### R4: Consistency of FAB Shape on Dashboard Screen
- **File Path**: `lib/features/dashboard/presentation/dashboard_screen.dart`
- **Line 328-338**:
  ```dart
  floatingActionButton: FloatingActionButton(
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AlarmWizardScreen()),
      );
    },
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    tooltip: t('new_alarm_title'),
    child: const Icon(Icons.add_rounded),
  ),
  ```

---

## 2. Logic Chain

### R1. Fechamento da Tela de Alarme ao Adiar
1. The overlay screen `AlarmActiveScreen` is conditionally displayed in the app's `MaterialApp.builder` when the `activeAlarmsProvider` stream emits a list that is not empty.
2. The `activeAlarmsProvider` streams all alarms in the database, filtering to only keep those where `status == 'ATIVO'`.
3. When the user snoozes an alarm, `_snooze()` in `AlarmActiveScreen` executes `repo.snoozeAlarm()`.
4. In `snoozeAlarm()`, the alarm fields `snoozeMin`, `lastModified`, and `pendingSync` are updated in the local database, but its `status` is left unmodified.
5. Because its status remains `'ATIVO'`, the stream continues to include this alarm, and `activeAlarmsProvider` remains non-empty. This prevents the active alarm screen from being removed from the Widget stack.
6. **Reasoning**: By explicitly updating `status` to `'SNOOZED'` within the `snoozeAlarm()` update query, the alarm will be filtered out from `activeAlarmsProvider`, automatically triggering the stream update and dismissing the screen.

### R2. Correção de RenderFlex Overflow na Modal Gerenciar Alarme
1. The `SnoozeModal` contains several UI widgets (medication name, active switch, actions buttons, text fields, steppers, and edit/delete buttons), yielding a tall layout (~400+ logical pixels).
2. By default, `showModalBottomSheet` limits the height of the sheet to 50% of the screen height. This constraint results in a RenderFlex overflow on standard or narrow viewports (e.g. 71-pixel bottom overflow).
3. Furthermore, the root widget in `SnoozeModal.build` is a static `Padding` wrapping a `Column` without any scroll support.
4. **Reasoning**: Enabling `isScrollControlled: true` on `showModalBottomSheet` removes the 50% height constraint. Wrapping the children in a `SafeArea` and `SingleChildScrollView` ensures the modal content can scroll if the viewport is restricted (such as when the keyboard is open for custom dosage input). Combining this with a dynamic bottom padding using `MediaQuery.of(context).viewInsets.bottom` ensures form fields stay visible above the soft keyboard.

### R4. Consistência do Formato do FAB na Tela de Início
1. In Material Design 3, a standard `FloatingActionButton` displays a rounded rectangle shape by default.
2. The `MultiActionFab` component and other FAB controls in the application are designed as circles.
3. The Dashboard FAB in `dashboard_screen.dart` is missing a `shape` declaration.
4. **Reasoning**: Adding `shape: const CircleBorder()` explicitly sets the button shape to be circular, ensuring visual consistency across all sections.

---

## 3. Caveats

- **R1**: Setting the alarm status to `'SNOOZED'` assumes that the ESP32 hardware firmware (or other parts of the app) recognizes `'SNOOZED'` or respects `'PENDENTE'` upon next sync. Looking at the C++ alignment documentation, `'SNOOZED'` is an expected string state for alarm status.
- **R2**: Utilizing `isScrollControlled: true` might expand the bottom sheet to take up more vertical space up to full screen height if not constrained. However, because `Column` has `mainAxisSize: MainAxisSize.min`, it will dynamically fit the content size up to the maximum constraints, which is ideal behavior.

---

## 4. Conclusion

We recommend applying the following concrete code changes to implement the repairs:

### Proposed Change for R1 (`lib/features/alarms/data/alarm_repository.dart`)

Modify `snoozeAlarm` to include the `status: 'SNOOZED'` property update:

```diff
<<<<
    final updated = alarm.copyWith(
      snoozeMin: minutes,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );
====
    final updated = alarm.copyWith(
      status: 'SNOOZED',
      snoozeMin: minutes,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      pendingSync: !_isConnected(),
    );
>>>>
```

### Proposed Changes for R2 (`lib/features/alarms/presentation/snooze_modal.dart`)

1. Set `isScrollControlled: true` in `showModalBottomSheet`:

```diff
<<<<
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SnoozeModal(
====
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SnoozeModal(
>>>>
```

2. Wrap content in `SafeArea` + `SingleChildScrollView` with keyboard-aware padding:

```diff
<<<<
  @override
  Widget build(BuildContext context) {
    final alarmColor = AppColors.getAlarmColor(widget.alarm.color);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
====
  @override
  Widget build(BuildContext context) {
    final alarmColor = AppColors.getAlarmColor(widget.alarm.color);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
>>>>
```
*(Remember to close the bracket for `SafeArea` and `SingleChildScrollView` at the end of the `build` method).*

### Proposed Change for R4 (`lib/features/dashboard/presentation/dashboard_screen.dart`)

Add `shape: const CircleBorder()` to the FAB:

```diff
<<<<
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlarmWizardScreen()),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: t('new_alarm_title'),
            child: const Icon(Icons.add_rounded),
          ),
====
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AlarmWizardScreen()),
              );
            },
            shape: const CircleBorder(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: t('new_alarm_title'),
            child: const Icon(Icons.add_rounded),
          ),
>>>>
```

---

## 5. Verification Method

### Automated Tests
Run the project-wide tests to verify syntax consistency and compilation of all affected modules:
```bash
flutter test
```

### Manual Verification Steps
1. **R1**: Trigger a test alarm by updating its execution time to the current system time. When the active screen pops up, click **"ADIAR 10 MIN"**. Observe that the screen immediately closes/unmounts and the database status updates to `'SNOOZED'`.
2. **R2**: Launch the app on a narrow simulated device (e.g., iPhone SE/14 Pro Max or smaller screen bounds). Select any alarm card and click it to open the Snooze Modal. Verify that the bottom sheet scales properly without rendering vertical overflow indicators. Select the custom quantity `TextField` to raise the keyboard and verify that the layout adjusts/scrolls correctly.
3. **R4**: Navigate to the Dashboard (Início tab) and check the "Add Alarm" button at the bottom-right. Confirm visually (or using the Widget Inspector) that the FAB is perfectly circular.
