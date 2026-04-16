import 'package:flutter/material.dart';

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  static const int defaultHour = 9;
  static const int defaultMinute = 0;

  final bool enabled;
  final int hour;
  final int minute;

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String get timeStorageValue =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

const reminderEnabledSettingKey = 'reminder_enabled';
const reminderDefaultTimeSettingKey = 'reminder_default_time';

ReminderSettings defaultReminderSettings() {
  return const ReminderSettings(
    enabled: false,
    hour: ReminderSettings.defaultHour,
    minute: ReminderSettings.defaultMinute,
  );
}

ReminderSettings reminderSettingsFromRawValues({
  String? enabledValue,
  String? timeValue,
}) {
  final parsedTime = parseReminderTimeValue(timeValue);

  return ReminderSettings(
    enabled: enabledValue == 'true',
    hour: parsedTime.hour,
    minute: parsedTime.minute,
  );
}

TimeOfDay parseReminderTimeValue(String? rawValue) {
  final normalized = rawValue?.trim();
  if (normalized == null || normalized.isEmpty) {
    return const TimeOfDay(
      hour: ReminderSettings.defaultHour,
      minute: ReminderSettings.defaultMinute,
    );
  }

  final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(normalized);
  if (match == null) {
    return const TimeOfDay(
      hour: ReminderSettings.defaultHour,
      minute: ReminderSettings.defaultMinute,
    );
  }

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return const TimeOfDay(
      hour: ReminderSettings.defaultHour,
      minute: ReminderSettings.defaultMinute,
    );
  }

  return TimeOfDay(hour: hour, minute: minute);
}

String formatReminderTimeValue(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime nextReminderDateTime(TimeOfDay time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  var scheduled = DateTime(
    current.year,
    current.month,
    current.day,
    time.hour,
    time.minute,
  );

  if (!scheduled.isAfter(current)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }

  return scheduled;
}

String formatReminderScheduleDateTime(DateTime dateTime) {
  final year = dateTime.year.toString();
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
