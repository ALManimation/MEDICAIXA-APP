import 'package:flutter_test/flutter_test.dart';
import 'package:medicaixa_app/features/alarms/data/alarm_model.dart';
import 'package:medicaixa_app/features/reminders/data/reminder_model.dart';

void main() {
  group('AlarmModel and ReminderModel copyWith Sentinel Tests', () {
    test('AlarmModel copyWith instance method now allows nulls directly', () {
      final original = AlarmModel(
        id: 1,
        hour: 8,
        minute: 0,
        name: 'Paracetamol',
        medName: 'Paracetamol',
        enabled: true,
        active: true,
        days: List.filled(7, true),
        status: 'PENDENTE',
        color: 'red',
        quantity: 1.0,
        daysQuantity: List.filled(7, 0.0),
        type: 'comprimido',
        dosage: '500mg',
        snoozeMin: 10,
        durationDays: 5,
        cycleOnDays: 10,
      );

      // Omitted dosage should remain '500mg'
      final omitted = original.copyWith(hour: 9);
      expect(omitted.hour, equals(9));
      expect(omitted.dosage, equals('500mg'));
      expect(omitted.cycleOnDays, equals(10));

      // Direct copyWith call successfully sets nullable fields to null
      final cleared = original.copyWith(
        dosage: null,
        cycleOnDays: null,
      );
      expect(cleared.dosage, isNull);
      expect(cleared.cycleOnDays, isNull);
    });

    test('ReminderModel copyWith distinguishes omitted properties from explicitly passed null values directly', () {
      const original = ReminderModel(
        id: 1,
        title: 'Lembrete 1',
        description: 'Tomar água',
        enabled: true,
        hasTime: true,
        hour: 10,
        minute: 30,
        period: 'day',
        interval: 1,
        startDate: '2026-07-01',
        notifyDaysBefore: 1,
        color: 'blue',
        lastCompletedDate: '01/07/2026',
      );

      // Omitted hour and lastCompletedDate should remain
      final omitted = original.copyWith(title: 'Novo Lembrete');
      expect(omitted.title, equals('Novo Lembrete'));
      expect(omitted.hour, equals(10));
      expect(omitted.lastCompletedDate, equals('01/07/2026'));

      // Explicitly passed null should clear them
      final cleared = original.copyWith(
        hour: null,
        minute: null,
        lastCompletedDate: null,
      );
      expect(cleared.hour, isNull);
      expect(cleared.minute, isNull);
      expect(cleared.lastCompletedDate, isNull);
    });
  });
}
