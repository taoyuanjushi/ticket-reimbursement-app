import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/app/app_metadata.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/settings/local_maintenance_providers.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class FeedbackDiagnosticInfo {
  const FeedbackDiagnosticInfo({
    required this.appName,
    required this.appVersion,
    required this.platform,
    required this.databasePath,
    required this.attachmentDirectoryPath,
    required this.reimbursementExportDirectoryPath,
    required this.reimbursementPackageExportDirectoryPath,
    required this.backupExportDirectoryPath,
  });

  final String appName;
  final String appVersion;
  final String platform;
  final String databasePath;
  final String attachmentDirectoryPath;
  final String reimbursementExportDirectoryPath;
  final String reimbursementPackageExportDirectoryPath;
  final String backupExportDirectoryPath;

  String toClipboardText() {
    return [
      '应用名称：$appName',
      '应用版本：$appVersion',
      '平台：$platform',
      '本地数据库路径：$databasePath',
      '附件目录路径：$attachmentDirectoryPath',
      '报销单 CSV 导出目录路径：$reimbursementExportDirectoryPath',
      '报销材料包导出目录路径：$reimbursementPackageExportDirectoryPath',
      '本地备份导出目录路径：$backupExportDirectoryPath',
    ].join('\n');
  }
}

final feedbackDiagnosticInfoProvider = FutureProvider<FeedbackDiagnosticInfo>((
  ref,
) async {
  final maintenanceInfo = await ref.watch(localMaintenanceInfoProvider.future);
  final backupDirectory = await ref
      .watch(localBackupExportServiceProvider)
      .exportsDirectory();
  final packageDirectory = await ref
      .watch(reimbursementPackageExportServiceProvider)
      .exportsDirectory();

  return FeedbackDiagnosticInfo(
    appName: appName,
    appVersion: appDisplayVersion,
    platform: '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    databasePath: maintenanceInfo.databasePath,
    attachmentDirectoryPath: maintenanceInfo.attachmentDirectoryPath,
    reimbursementExportDirectoryPath:
        maintenanceInfo.reimbursementExportDirectoryPath,
    reimbursementPackageExportDirectoryPath: packageDirectory.path,
    backupExportDirectoryPath: backupDirectory.path,
  );
});

class FeedbackPage extends ConsumerWidget {
  const FeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnosticInfoAsync = ref.watch(feedbackDiagnosticInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('问题反馈')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('feedback-page'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const AppSurfaceCard(
              color: Color(0xFFF8FBF9),
              child: AppSectionHeader(
                title: '反馈问题',
                subtitle: '不会自动上传任何数据，请按需复制诊断信息后手动发送。',
              ),
            ),
            const SizedBox(height: 16),
            const AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionHeader(title: '建议提供的信息', subtitle: '越具体越容易复现和修复。'),
                  SizedBox(height: 16),
                  _FeedbackChecklistItem(label: '手机型号'),
                  _FeedbackChecklistItem(label: 'Android 版本'),
                  _FeedbackChecklistItem(label: '操作步骤'),
                  _FeedbackChecklistItem(label: '实际结果'),
                  _FeedbackChecklistItem(label: '截图/录屏（如果方便）'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            diagnosticInfoAsync.when(
              data: (diagnosticInfo) => _DiagnosticInfoCard(
                diagnosticInfo: diagnosticInfo,
                onCopy: () => _copyDiagnosticInfo(context, diagnosticInfo),
              ),
              loading: () => const AppSurfaceCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stackTrace) => AppSurfaceCard(
                child: Column(
                  children: [
                    const Text('加载诊断信息失败'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(feedbackDiagnosticInfoProvider),
                      child: const Text('重新加载'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyDiagnosticInfo(
    BuildContext context,
    FeedbackDiagnosticInfo diagnosticInfo,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: diagnosticInfo.toClipboardText()),
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('诊断信息已复制')));
  }
}

class _FeedbackChecklistItem extends StatelessWidget {
  const _FeedbackChecklistItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _DiagnosticInfoCard extends StatelessWidget {
  const _DiagnosticInfoCard({
    required this.diagnosticInfo,
    required this.onCopy,
  });

  final FeedbackDiagnosticInfo diagnosticInfo;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: '本地诊断信息',
            subtitle: '仅包含版本、平台和本地路径，不包含票据内容或附件内容。',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SelectableText(
              diagnosticInfo.toClipboardText(),
              key: const ValueKey('feedback-diagnostic-text'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('copy-diagnostic-info-button'),
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制诊断信息'),
          ),
        ],
      ),
    );
  }
}
