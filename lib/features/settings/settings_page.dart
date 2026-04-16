import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/features/reminders/reminder_providers.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';
import 'package:ticket_box/features/settings/local_maintenance_providers.dart';
import 'package:ticket_box/features/settings/local_maintenance_service.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(reminderSettingsProvider);
    final maintenanceInfoAsync = ref.watch(localMaintenanceInfoProvider);

    return ListView(
      key: const ValueKey('settings-page-content'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        AppSurfaceCard(
          color: const Color(0xFFF8FBF9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: AppSectionHeader(
                      title: '本地设置',
                      subtitle: '提醒和维护都只保存在当前设备。',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(title: '提醒设置', subtitle: '控制本地提醒的开关和默认时间'),
        const SizedBox(height: 12),
        settingsAsync.when(
          data: (settings) => _ReminderSettingsCard(
            settings: settings,
            onEnabledChanged: (value) =>
                _updateReminderEnabled(context, ref, value),
            onTimePressed: () => _pickReminderTime(context, ref, settings),
          ),
          loading: () => _SettingsLoadingCard(colors: colors),
          error: (error, stackTrace) => _SettingsErrorCard(
            message: '加载提醒设置失败',
            retryLabel: '重新加载',
            onRetry: () => ref.invalidate(reminderSettingsProvider),
          ),
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(title: '本地维护', subtitle: '查看路径信息和执行维护操作'),
        const SizedBox(height: 12),
        maintenanceInfoAsync.when(
          data: (info) => Column(
            children: [
              _LocalMaintenanceOverviewCard(info: info),
              const SizedBox(height: 12),
              _LocalMaintenanceActionsCard(
                onClearExports: () => _clearExportedCsvFiles(context, ref),
                onClearInvalidAttachments: () =>
                    _clearInvalidAttachmentReferences(context, ref),
                onCancelNotifications: () =>
                    _cancelAllPendingNotifications(context, ref),
              ),
            ],
          ),
          loading: () => _SettingsLoadingCard(colors: colors),
          error: (error, stackTrace) => _SettingsErrorCard(
            message: '加载本地维护信息失败',
            retryLabel: '重新加载',
            onRetry: () => ref.invalidate(localMaintenanceInfoProvider),
          ),
        ),
      ],
    );
  }

  Future<void> _updateReminderEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final granted = await ref
          .read(reminderNotificationServiceProvider)
          .requestPermissions();

      if (!granted) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未获得通知权限，无法开启提醒')));
        return;
      }
    }

    await ref
        .read(reminderSettingsRepositoryProvider)
        .setReminderEnabled(enabled);
    ref.invalidate(reminderSettingsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(enabled ? '已开启本地提醒' : '已关闭本地提醒')));
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings settings,
  ) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: settings.timeOfDay,
      helpText: '选择默认提醒时间',
      cancelText: '取消',
      confirmText: '确定',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedTime == null) {
      return;
    }

    await ref
        .read(reminderSettingsRepositoryProvider)
        .setReminderDefaultTime(
          hour: pickedTime.hour,
          minute: pickedTime.minute,
        );
    ref.invalidate(reminderSettingsProvider);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('默认提醒时间已更新为 ${formatReminderTimeValue(pickedTime)}'),
      ),
    );
  }

  Future<void> _clearExportedCsvFiles(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final deletedCount = await ref
          .read(localMaintenanceServiceProvider)
          .clearExportedCsvFiles();

      if (!context.mounted) {
        return;
      }

      final message = deletedCount > 0
          ? '已清理 $deletedCount 个导出文件'
          : '当前没有可清理的导出 CSV';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清理导出文件失败')));
    }
  }

  Future<void> _clearInvalidAttachmentReferences(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final cleanedCount = await ref
          .read(localMaintenanceServiceProvider)
          .clearInvalidAttachmentReferences();
      ref.invalidate(localMaintenanceInfoProvider);

      if (!context.mounted) {
        return;
      }

      final message = cleanedCount > 0
          ? '已清理 $cleanedCount 条无效附件引用'
          : '当前没有可清理的无效附件引用';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清理无效附件引用失败')));
    }
  }

  Future<void> _cancelAllPendingNotifications(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref
          .read(localMaintenanceServiceProvider)
          .cancelAllPendingNotifications();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已取消全部待提醒通知')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('取消待提醒通知失败')));
    }
  }
}

class _ReminderSettingsCard extends StatelessWidget {
  const _ReminderSettingsCard({
    required this.settings,
    required this.onEnabledChanged,
    required this.onTimePressed,
  });

  final ReminderSettings settings;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onTimePressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: settings.enabled,
            onChanged: onEnabledChanged,
            title: const Text('开启本地提醒'),
            subtitle: const Text('提醒和设置仅保存在当前设备'),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.schedule_outlined, color: colors.primary),
            ),
            title: const Text('默认提醒时间'),
            subtitle: Text(formatReminderTimeValue(settings.timeOfDay)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTimePressed,
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Text(
              '仅支持手动为单张票据或报销单创建提醒。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalMaintenanceOverviewCard extends StatelessWidget {
  const _LocalMaintenanceOverviewCard({required this.info});

  final LocalMaintenanceInfo info;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '本地信息', subtitle: '以下内容仅影响当前设备。'),
          const SizedBox(height: 18),
          _MaintenancePathItem(label: '本地数据库路径', value: info.databasePath),
          const SizedBox(height: 16),
          _MaintenancePathItem(
            label: '附件目录路径',
            value: info.attachmentDirectoryPath,
          ),
          const SizedBox(height: 16),
          _MaintenancePathItem(
            label: '报销单 CSV 导出目录路径',
            value: info.reimbursementExportDirectoryPath,
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              '无效附件引用：${info.invalidAttachmentCount} 条',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalMaintenanceActionsCard extends StatelessWidget {
  const _LocalMaintenanceActionsCard({
    required this.onClearExports,
    required this.onClearInvalidAttachments,
    required this.onCancelNotifications,
  });

  final Future<void> Function() onClearExports;
  final Future<void> Function() onClearInvalidAttachments;
  final Future<void> Function() onCancelNotifications;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '维护操作', subtitle: '按需执行本地清理和通知处理'),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onClearExports,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('清空导出 CSV'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onClearInvalidAttachments,
            icon: const Icon(Icons.link_off_outlined),
            label: const Text('清理无效附件引用'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancelNotifications,
            icon: const Icon(Icons.notifications_off_outlined),
            label: const Text('取消全部待提醒通知'),
          ),
        ],
      ),
    );
  }
}

class _MaintenancePathItem extends StatelessWidget {
  const _MaintenancePathItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SettingsLoadingCard extends StatelessWidget {
  const _SettingsLoadingCard({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: CircularProgressIndicator(color: colors.primary),
        ),
      ),
    );
  }
}

class _SettingsErrorCard extends StatelessWidget {
  const _SettingsErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.error_outline, color: colors.onErrorContainer),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
