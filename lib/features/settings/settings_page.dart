import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/inspections/duplicate_ticket_inspection_page.dart';
import 'package:ticket_box/features/inspections/reimbursement_completeness_inspection_page.dart';
import 'package:ticket_box/features/inspections/ticket_completeness_inspection_page.dart';
import 'package:ticket_box/features/reminders/reminder_providers.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/settings/about_page.dart';
import 'package:ticket_box/features/settings/feedback_page.dart';
import 'package:ticket_box/features/settings/help_page.dart';
import 'package:ticket_box/features/settings/local_maintenance_providers.dart';
import 'package:ticket_box/features/settings/local_backup_export_service.dart';
import 'package:ticket_box/features/settings/local_backup_restore_service.dart';
import 'package:ticket_box/features/settings/local_maintenance_service.dart';
import 'package:ticket_box/features/settings/privacy_page.dart';
import 'package:ticket_box/features/settings/ticket_recycle_bin_page.dart';
import 'package:ticket_box/features/tags/tag_management_page.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final settingsAsync = ref.watch(reminderSettingsProvider);
    final maintenanceInfoAsync = ref.watch(localMaintenanceInfoProvider);
    final trashedTicketsAsync = ref.watch(trashedTicketListProvider);
    final trashedSheetsAsync = ref.watch(trashedReimbursementSheetListProvider);

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
        const AppSectionHeader(title: '应用信息', subtitle: '查看版本和本地优先说明'),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            children: [
              _SettingsNavigationTile(
                icon: Icons.info_outline_rounded,
                title: '关于票据盒',
                subtitle: '版本信息和本地数据说明',
                onTap: () => _openAboutPage(context),
                colors: colors,
              ),
              const Divider(height: 24),
              _SettingsNavigationTile(
                icon: Icons.privacy_tip_outlined,
                title: '隐私说明',
                subtitle: '本地数据、附件和备份说明',
                onTap: () => _openPrivacyPage(context),
                colors: colors,
              ),
              const Divider(height: 24),
              _SettingsNavigationTile(
                icon: Icons.help_outline_rounded,
                title: '使用帮助',
                subtitle: '查看票据、报销和备份流程',
                onTap: () => _openHelpPage(context),
                colors: colors,
              ),
              const Divider(height: 24),
              _SettingsNavigationTile(
                icon: Icons.feedback_outlined,
                title: '问题反馈',
                subtitle: '复制诊断信息，手动反馈问题',
                onTap: () => _openFeedbackPage(context),
                colors: colors,
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
        const AppSectionHeader(title: '标签管理', subtitle: '创建、编辑和整理票据标签'),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.label_outline_rounded, color: colors.primary),
            ),
            title: const Text('管理本地标签'),
            subtitle: const Text('在票据表单里可多选标签'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openTagManagement(context),
          ),
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(title: '安全删除', subtitle: '恢复误删票据或报销单，永久删除前会确认'),
        const SizedBox(height: 12),
        _RecycleBinSummaryCard(
          trashedTicketsAsync: trashedTicketsAsync,
          trashedSheetsAsync: trashedSheetsAsync,
          onTap: () => _openTicketRecycleBin(context),
          colors: colors,
        ),
        const SizedBox(height: 24),
        const AppSectionHeader(title: '资料检查', subtitle: '导出前先看看可能的数据问题'),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.fact_check_outlined, color: colors.primary),
            ),
            title: const Text('检查可能重复票据'),
            subtitle: const Text('按日期、金额和标题相似度分组'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openDuplicateTicketInspection(context),
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.rule_folder_outlined, color: colors.primary),
            ),
            title: const Text('检查票据信息完整性'),
            subtitle: const Text('查看空标题、缺金额和附件问题'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openTicketCompletenessInspection(context),
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.inventory_2_outlined, color: colors.primary),
            ),
            title: const Text('检查报销单完整性'),
            subtitle: const Text('查看空报销单、附件和票据问题'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openReimbursementCompletenessInspection(context),
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
                onExportBackup: () => _exportLocalBackup(context, ref),
                onRestoreBackup: () => _restoreLocalBackup(context, ref),
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

  Future<void> _openTagManagement(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TagManagementPage()),
    );
  }

  Future<void> _openAboutPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
  }

  Future<void> _openPrivacyPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const PrivacyPage()));
  }

  Future<void> _openHelpPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const HelpPage()));
  }

  Future<void> _openFeedbackPage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const FeedbackPage()));
  }

  Future<void> _openTicketRecycleBin(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TicketRecycleBinPage()),
    );
  }

  Future<void> _openDuplicateTicketInspection(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const DuplicateTicketInspectionPage(),
      ),
    );
  }

  Future<void> _openTicketCompletenessInspection(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const TicketCompletenessInspectionPage(),
      ),
    );
  }

  Future<void> _openReimbursementCompletenessInspection(
    BuildContext context,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ReimbursementCompletenessInspectionPage(),
      ),
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

  Future<void> _exportLocalBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(localBackupExportServiceProvider)
          .exportBackup();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本地备份已导出')));

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('备份导出成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.attachmentFileCount > 0
                      ? '已打包数据库和 ${result.attachmentFileCount} 个附件文件。'
                      : '已打包数据库，当前没有附件文件。',
                ),
                const SizedBox(height: 12),
                const Text('文件路径'),
                const SizedBox(height: 8),
                SelectableText(result.filePath),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
              FilledButton.icon(
                onPressed: () => _shareBackup(
                  pageContext: context,
                  dialogContext: dialogContext,
                  result: result,
                ),
                icon: const Icon(Icons.share_outlined),
                label: const Text('分享文件'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导出本地备份失败')));
    }
  }

  Future<void> _shareBackup({
    required BuildContext pageContext,
    required BuildContext dialogContext,
    required LocalBackupExportResult result,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.filePath)],
          subject: '票据盒本地备份',
          text: '备份文件：${result.fileName}',
        ),
      );

      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    } catch (_) {
      if (!pageContext.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(const SnackBar(content: Text('分享备份文件失败')));
    }
  }

  Future<void> _restoreLocalBackup(BuildContext context, WidgetRef ref) async {
    final restoreService = ref.read(localBackupRestoreServiceProvider);
    final backupFilePath = await restoreService.pickBackupFilePath();
    if (backupFilePath == null) {
      return;
    }

    LocalBackupInspectionResult inspection;
    try {
      inspection = await restoreService.inspectBackup(backupFilePath);
    } on LocalBackupValidationException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('读取本地备份失败')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    final confirmed = await _confirmRestoreBackup(context, inspection);
    if (confirmed != true) {
      return;
    }

    var didCloseDatabase = false;

    try {
      await ref.read(appDatabaseProvider).close();
      didCloseDatabase = true;

      final result = await restoreService.restoreBackup(backupFilePath);
      _refreshAfterBackupRestore(ref);

      if (!context.mounted) {
        return;
      }

      final message = result.attachmentFileCount > 0
          ? '本地备份已恢复，附件 ${result.attachmentFileCount} 个'
          : '本地备份已恢复';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on LocalBackupValidationException catch (error) {
      if (didCloseDatabase) {
        _refreshAfterBackupRestore(ref);
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (didCloseDatabase) {
        _refreshAfterBackupRestore(ref);
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('恢复本地备份失败')));
    }
  }

  Future<bool?> _confirmRestoreBackup(
    BuildContext context,
    LocalBackupInspectionResult inspection,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('恢复本地备份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将恢复备份：${inspection.fileName}'),
              const SizedBox(height: 12),
              Text(
                inspection.attachmentFileCount > 0
                    ? '将覆盖当前设备上的全部本地数据和 ${inspection.attachmentFileCount} 个附件文件，且无法撤销。'
                    : '将覆盖当前设备上的全部本地数据，且无法撤销。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认恢复'),
            ),
          ],
        );
      },
    );
  }

  void _refreshAfterBackupRestore(WidgetRef ref) {
    ref.invalidate(appDatabaseProvider);
    ref.invalidate(ticketRepositoryProvider);
    ref.invalidate(reimbursementRepositoryProvider);
    ref.invalidate(reminderSettingsRepositoryProvider);
    ref.invalidate(reminderSettingsProvider);
    ref.invalidate(localMaintenanceInfoProvider);
    ref.invalidate(ticketListProvider);
    ref.invalidate(ticketRecentListProvider);
    ref.invalidate(reimbursementListProvider);
    ref.invalidate(reimbursementAvailableTicketsProvider);
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

class _SettingsNavigationTile extends StatelessWidget {
  const _SettingsNavigationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: colors.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _RecycleBinSummaryCard extends StatelessWidget {
  const _RecycleBinSummaryCard({
    required this.trashedTicketsAsync,
    required this.trashedSheetsAsync,
    required this.onTap,
    required this.colors,
  });

  final AsyncValue<List<Ticket>> trashedTicketsAsync;
  final AsyncValue<List<ReimbursementSheet>> trashedSheetsAsync;
  final VoidCallback onTap;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.delete_outline_rounded, color: colors.primary),
            ),
            title: const Text('回收站'),
            subtitle: const Text('回收站中的内容可以恢复，永久删除后无法恢复'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _RecycleBinCountItem(
                  label: '已删除票据数量',
                  value: _formatCount(trashedTicketsAsync),
                  valueKey: 'settings-recycle-bin-ticket-count',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RecycleBinCountItem(
                  label: '已删除报销单数量',
                  value: _formatCount(trashedSheetsAsync),
                  valueKey: 'settings-recycle-bin-sheet-count',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCount<T>(AsyncValue<List<T>> asyncValue) {
    if (asyncValue.hasError) {
      return '加载失败';
    }

    final items = asyncValue.whenOrNull(data: (items) => items);
    if (items == null) {
      return '读取中';
    }

    return '${items.length}';
  }
}

class _RecycleBinCountItem extends StatelessWidget {
  const _RecycleBinCountItem({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            key: ValueKey(valueKey),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
    required this.onExportBackup,
    required this.onRestoreBackup,
    required this.onClearExports,
    required this.onClearInvalidAttachments,
    required this.onCancelNotifications,
  });

  final Future<void> Function() onExportBackup;
  final Future<void> Function() onRestoreBackup;
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
          FilledButton.icon(
            onPressed: onExportBackup,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('导出本地备份'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRestoreBackup,
            icon: const Icon(Icons.restore_page_outlined),
            label: const Text('恢复本地备份'),
          ),
          const SizedBox(height: 12),
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
