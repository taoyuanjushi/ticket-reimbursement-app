import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/reminders/reminder_settings_repository.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';

void main() {
  test('loads default reminder settings when nothing is stored', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = ReminderSettingsRepository(database);
    final settings = await repository.getReminderSettings();

    expect(settings.enabled, isFalse);
    expect(settings.hour, ReminderSettings.defaultHour);
    expect(settings.minute, ReminderSettings.defaultMinute);
  });

  test('persists reminder settings locally', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = ReminderSettingsRepository(database);
    await repository.setReminderEnabled(true);
    await repository.setReminderDefaultTime(hour: 18, minute: 30);

    final settings = await repository.getReminderSettings();

    expect(settings.enabled, isTrue);
    expect(settings.hour, 18);
    expect(settings.minute, 30);
  });

  test(
    'next reminder time rolls to next day when selected time has passed',
    () {
      final next = nextReminderDateTime(
        const TimeOfDay(hour: 9, minute: 0),
        now: DateTime(2026, 4, 15, 10, 30),
      );

      expect(next, DateTime(2026, 4, 16, 9));
    },
  );
}
