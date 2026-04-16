import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reminders/reminder_notification_service.dart';
import 'package:ticket_box/features/reminders/reminder_settings_repository.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';

final reminderSettingsRepositoryProvider = Provider<ReminderSettingsRepository>(
  (ref) {
    return ReminderSettingsRepository(ref.watch(appDatabaseProvider));
  },
);

final reminderSettingsProvider = FutureProvider<ReminderSettings>((ref) {
  return ref.watch(reminderSettingsRepositoryProvider).getReminderSettings();
});

final reminderNotificationServiceProvider =
    Provider<ReminderNotificationService>((ref) {
      return ReminderNotificationService();
    });
