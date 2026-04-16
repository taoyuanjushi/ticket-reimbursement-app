import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  ReminderNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ticket_box_reminders';
  static const String _channelName = '票据与报销提醒';
  static const String _channelDescription = '用于手动创建票据和报销单提醒';
  static const int _ticketReminderBaseId = 100000;
  static const int _reimbursementReminderBaseId = 200000;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final initializationSettings = switch (defaultTargetPlatform) {
      TargetPlatform.android => const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
      ),
      TargetPlatform.iOS => const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      TargetPlatform.macOS => const InitializationSettings(
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      TargetPlatform.linux => const InitializationSettings(
        linux: LinuxInitializationSettings(defaultActionName: '打开提醒'),
      ),
      TargetPlatform.windows => const InitializationSettings(
        windows: WindowsInitializationSettings(
          appName: '票据盒',
          appUserModelId: 'com.ticketbox.piaojuhe',
          guid: 'cd9ae5bb-ef86-4b62-874b-0e77a6892e8a',
        ),
      ),
      _ => throw UnsupportedError('当前平台不支持本地提醒'),
    };

    await _plugin.initialize(settings: initializationSettings);
    await _configureLocalTimeZone();
    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    await initialize();

    return switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false,
      TargetPlatform.iOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false,
      TargetPlatform.macOS =>
        await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false,
      TargetPlatform.linux ||
      TargetPlatform.windows ||
      TargetPlatform.fuchsia => true,
    };
  }

  Future<void> cancelAllNotifications() async {
    await initialize();
    await _plugin.cancelAll();
  }

  Future<DateTime> scheduleTicketReminder({
    required int ticketId,
    required String title,
    required ReminderSettings settings,
  }) {
    return _scheduleReminder(
      notificationId: _ticketReminderBaseId + ticketId,
      title: '票据提醒',
      body: '你有一张待处理票据：$title',
      payload: 'ticket:$ticketId',
      time: settings.timeOfDay,
    );
  }

  Future<DateTime> scheduleReimbursementReminder({
    required int reimbursementSheetId,
    required String title,
    required ReminderSettings settings,
  }) {
    return _scheduleReminder(
      notificationId: _reimbursementReminderBaseId + reimbursementSheetId,
      title: '报销单提醒',
      body: '请处理报销单：$title',
      payload: 'reimbursement:$reimbursementSheetId',
      time: settings.timeOfDay,
    );
  }

  Future<DateTime> _scheduleReminder({
    required int notificationId,
    required String title,
    required String body,
    required String payload,
    required TimeOfDay time,
  }) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
      throw UnsupportedError('当前平台不支持本地提醒');
    }

    await initialize();

    final scheduledAt = nextReminderDateTime(time);
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: _notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    return scheduledAt;
  }

  NotificationDetails get _notificationDetails {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: '提醒',
    );
    const darwin = DarwinNotificationDetails();

    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();

    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      // Fall back to timezone package defaults when the platform timezone
      // identifier cannot be resolved.
    }
  }
}
