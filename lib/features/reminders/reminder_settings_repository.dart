import 'package:drift/drift.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';

class ReminderSettingsRepository {
  ReminderSettingsRepository(this.database);

  final AppDatabase database;

  Future<ReminderSettings> getReminderSettings() async {
    final rows =
        await (database.select(database.appSettings)..where(
              (setting) => setting.key.isIn(const [
                reminderEnabledSettingKey,
                reminderDefaultTimeSettingKey,
              ]),
            ))
            .get();

    String? enabledValue;
    String? timeValue;
    for (final row in rows) {
      if (row.key == reminderEnabledSettingKey) {
        enabledValue = row.value;
      } else if (row.key == reminderDefaultTimeSettingKey) {
        timeValue = row.value;
      }
    }

    return reminderSettingsFromRawValues(
      enabledValue: enabledValue,
      timeValue: timeValue,
    );
  }

  Future<void> setReminderEnabled(bool enabled) {
    return _upsertSetting(
      key: reminderEnabledSettingKey,
      value: enabled ? 'true' : 'false',
    );
  }

  Future<void> setReminderDefaultTime({
    required int hour,
    required int minute,
  }) {
    final normalized = ReminderSettings(
      enabled: false,
      hour: hour,
      minute: minute,
    );

    return _upsertSetting(
      key: reminderDefaultTimeSettingKey,
      value: normalized.timeStorageValue,
    );
  }

  Future<void> _upsertSetting({required String key, required String value}) {
    return database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: Value(value),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
