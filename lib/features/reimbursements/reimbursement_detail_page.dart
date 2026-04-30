import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/home/home_providers.dart';
import 'package:ticket_box/features/reminders/reminder_providers.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_form_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_package_export_service.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_support.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class ReimbursementDetailPage extends ConsumerWidget {
  const ReimbursementDetailPage({
    required this.reimbursementSheetId,
    super.key,
  });

  final int reimbursementSheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetAsync = ref.watch(
      reimbursementByIdProvider(reimbursementSheetId),
    );
    final linkedTicketsAsync = ref.watch(
      reimbursementLinkedTicketsProvider(reimbursementSheetId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('报销单详情')),
      body: SafeArea(
        child: sheetAsync.when(
          data: (sheet) {
            if (sheet == null) {
              return _MissingSheetState(
                onBack: () => Navigator.of(context).pop(),
              );
            }

            return ListView(
              key: const ValueKey('reimbursement-detail-page'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _SheetHeadlineCard(sheet: sheet),
                const SizedBox(height: 16),
                _SheetActionCard(
                  onReminder: () => _createReminder(context, ref, sheet),
                  onEdit: () => _openEditPage(context, sheet),
                  onDelete: () => _deleteSheet(context, ref, sheet),
                ),
                const SizedBox(height: 16),
                linkedTicketsAsync.when(
                  data: (linkedTickets) {
                    final totalAmount = linkedTickets.fold<int>(
                      0,
                      (sum, ticket) => sum + ticket.amountInCents,
                    );

                    return _LinkedTicketsSection(
                      linkedTickets: linkedTickets,
                      totalAmountInCents: totalAmount,
                      onAttachPressed: () =>
                          _openAttachSheet(context, ref, sheet.id),
                      onExportPressed: () =>
                          _exportCsv(context, ref, sheet, linkedTickets),
                      onExportPackagePressed: () =>
                          _exportPackage(context, ref, sheet, linkedTickets),
                      onRemoveTicket: (ticketId) =>
                          _removeTicket(context, ref, ticketId),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) {
                    return _LinkedTicketsErrorState(
                      onRetry: () => ref.invalidate(
                        reimbursementLinkedTicketsProvider(
                          reimbursementSheetId,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('加载报销单详情失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(
                          reimbursementByIdProvider(reimbursementSheetId),
                        ),
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditPage(
    BuildContext context,
    ReimbursementSheet sheet,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReimbursementFormPage(initialSheet: sheet),
      ),
    );
  }

  Future<void> _createReminder(
    BuildContext context,
    WidgetRef ref,
    ReimbursementSheet sheet,
  ) async {
    try {
      final settings = await ref.read(reminderSettingsProvider.future);
      if (!settings.enabled) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先在设置中开启本地提醒')));
        return;
      }

      final granted = await ref
          .read(reminderNotificationServiceProvider)
          .requestPermissions();
      if (!granted) {
        if (!context.mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未获得通知权限，无法创建提醒')));
        return;
      }

      final scheduledAt = await ref
          .read(reminderNotificationServiceProvider)
          .scheduleReimbursementReminder(
            reimbursementSheetId: sheet.id,
            title: sheet.title,
            settings: settings,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已创建报销单提醒：${formatReminderScheduleDateTime(scheduledAt)}',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('创建提醒失败，请稍后重试')));
    }
  }

  Future<void> _deleteSheet(
    BuildContext context,
    WidgetRef ref,
    ReimbursementSheet sheet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除报销单'),
          content: const Text('报销单会移入回收站，关联票据和附件不会删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('移入回收站'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .moveReimbursementSheetToTrash(sheet.id);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(const SnackBar(content: Text('移入回收站失败，请稍后重试')));
      return;
    }

    ref.invalidate(reimbursementListProvider);
    ref.invalidate(trashedReimbursementSheetListProvider);
    ref.invalidate(reimbursementByIdProvider(sheet.id));
    ref.invalidate(reimbursementLinkedTicketsProvider(sheet.id));
    ref.invalidate(reimbursementAvailableTicketsProvider);
    ref.invalidate(homeWorkbenchProvider);

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('报销单已移入回收站')));
  }

  Future<void> _openAttachSheet(
    BuildContext context,
    WidgetRef ref,
    int reimbursementSheetId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _AttachTicketSheet(reimbursementSheetId: reimbursementSheetId);
      },
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    ReimbursementSheet sheet,
    List<Ticket> linkedTickets,
  ) async {
    try {
      final result = await ref
          .read(reimbursementCsvExportServiceProvider)
          .exportSheetTickets(sheetTitle: sheet.title, tickets: linkedTickets);

      if (!context.mounted) {
        return;
      }

      final successText = linkedTickets.isEmpty ? '已导出空白 CSV' : 'CSV 已导出';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successText)));

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('导出成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  linkedTickets.isEmpty
                      ? '未关联票据，已导出表头。'
                      : '已导出 ${result.exportedCount} 张票据。',
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
                onPressed: () => _shareExportedCsv(
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
      ).showSnackBar(const SnackBar(content: Text('导出失败，请稍后重试')));
    }
  }

  Future<void> _shareExportedCsv({
    required BuildContext pageContext,
    required BuildContext dialogContext,
    required ReimbursementCsvExportResult result,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.filePath)],
          subject: '报销单 CSV 导出',
          text: '导出文件：${result.fileName}',
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
      ).showSnackBar(const SnackBar(content: Text('分享失败，请稍后重试')));
    }
  }

  Future<void> _exportPackage(
    BuildContext context,
    WidgetRef ref,
    ReimbursementSheet sheet,
    List<Ticket> linkedTickets,
  ) async {
    final packageExportService = ref.read(
      reimbursementPackageExportServiceProvider,
    );
    ReimbursementPackagePreview preview;

    try {
      preview = await packageExportService.previewPackage(
        tickets: linkedTickets,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('读取材料包预览失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    final shouldExport = await _confirmPackageExport(context, preview);
    if (shouldExport != true) {
      return;
    }

    try {
      final result = await packageExportService.exportPackage(
        sheet: sheet,
        tickets: linkedTickets,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('报销材料包已导出')));

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('导出成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已打包 ${result.ticketCount} 张票据，包含 ${result.attachmentFileCount} 个附件。',
                ),
                if (result.missingAttachmentCount > 0) ...[
                  const SizedBox(height: 8),
                  Text('有 ${result.missingAttachmentCount} 个附件缺失，已写入说明。'),
                ],
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
                onPressed: () => _shareReimbursementPackage(
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
      ).showSnackBar(const SnackBar(content: Text('导出材料包失败，请稍后重试')));
    }
  }

  Future<bool?> _confirmPackageExport(
    BuildContext context,
    ReimbursementPackagePreview preview,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _PackagePreviewDialog(preview: preview);
      },
    );
  }

  Future<void> _shareReimbursementPackage({
    required BuildContext pageContext,
    required BuildContext dialogContext,
    required ReimbursementPackageExportResult result,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.filePath)],
          subject: '报销材料包',
          text: '导出文件：${result.fileName}',
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
      ).showSnackBar(const SnackBar(content: Text('分享失败，请稍后重试')));
    }
  }

  Future<void> _removeTicket(
    BuildContext context,
    WidgetRef ref,
    int ticketId,
  ) async {
    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .removeTicketFromReimbursementSheet(ticketId: ticketId);
      ref.invalidate(reimbursementLinkedTicketsProvider(reimbursementSheetId));
      ref.invalidate(reimbursementAvailableTicketsProvider);
      ref.invalidate(ticketListProvider);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('移出票据失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('票据已移出报销单')));
  }
}

class _PackagePreviewDialog extends StatelessWidget {
  const _PackagePreviewDialog({required this.preview});

  final ReimbursementPackagePreview preview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const ValueKey('reimbursement-package-preview-dialog'),
      title: const Text('导出报销材料包'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PackagePreviewMetric(
              label: '票据数量',
              value: '${preview.ticketCount}',
              valueKey: 'reimbursement-package-preview-ticket-count',
            ),
            _PackagePreviewMetric(
              label: '可用附件数量',
              value: '${preview.availableAttachmentCount}',
              valueKey: 'reimbursement-package-preview-available-count',
            ),
            _PackagePreviewMetric(
              label: '无附件票据数量',
              value: '${preview.noAttachmentTicketCount}',
              valueKey: 'reimbursement-package-preview-no-attachment-count',
            ),
            _PackagePreviewMetric(
              label: '附件文件缺失数量',
              value: '${preview.missingAttachmentFileCount}',
              valueKey: 'reimbursement-package-preview-missing-count',
            ),
            const SizedBox(height: 16),
            Text(
              '将导出内容',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const _PackagePreviewContentItem(label: '报销清单.csv'),
            const _PackagePreviewContentItem(label: '说明.txt'),
            _PackagePreviewContentItem(
              label: '附件文件（${preview.availableAttachmentCount} 个）',
            ),
            if (preview.missingAttachmentFileCount > 0) ...[
              const SizedBox(height: 12),
              _PackagePreviewNotice(
                icon: Icons.warning_amber_rounded,
                color: colors.error,
                text:
                    '有 ${preview.missingAttachmentFileCount} 个附件文件找不到，导出会继续，详情会写入说明。',
              ),
            ],
            if (preview.noAttachmentTicketCount > 0) ...[
              const SizedBox(height: 10),
              _PackagePreviewNotice(
                icon: Icons.info_outline_rounded,
                color: colors.primary,
                text: '有 ${preview.noAttachmentTicketCount} 张票据未附加文件，导出会继续。',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('reimbursement-package-preview-confirm-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('继续导出'),
        ),
      ],
    );
  }
}

class _PackagePreviewMetric extends StatelessWidget {
  const _PackagePreviewMetric({
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            key: ValueKey(valueKey),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PackagePreviewContentItem extends StatelessWidget {
  const _PackagePreviewContentItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _PackagePreviewNotice extends StatelessWidget {
  const _PackagePreviewNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _SheetHeadlineCard extends StatelessWidget {
  const _SheetHeadlineCard({required this.sheet});

  final ReimbursementSheet sheet;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      color: const Color(0xFFF8FBF9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheet.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(reimbursementStatusLabel(sheet.status)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            sheet.description ?? '暂无备注',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SheetActionCard extends StatelessWidget {
  const _SheetActionCard({
    required this.onReminder,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onReminder;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '快捷操作', subtitle: '编辑信息或创建提醒'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑报销单'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onReminder,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('创建提醒'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除报销单'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedTicketsSection extends StatelessWidget {
  const _LinkedTicketsSection({
    required this.linkedTickets,
    required this.totalAmountInCents,
    required this.onAttachPressed,
    required this.onExportPressed,
    required this.onExportPackagePressed,
    required this.onRemoveTicket,
  });

  final List<Ticket> linkedTickets;
  final int totalAmountInCents;
  final VoidCallback onAttachPressed;
  final VoidCallback onExportPressed;
  final VoidCallback onExportPackagePressed;
  final ValueChanged<int> onRemoveTicket;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: '关联票据',
            subtitle:
                '共 ${linkedTickets.length} 张票据 · ${formatTicketAmount(totalAmountInCents)}',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onAttachPressed,
                icon: const Icon(Icons.link_rounded),
                label: const Text('关联票据'),
              ),
              OutlinedButton.icon(
                onPressed: onExportPressed,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('导出 CSV'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('reimbursement-package-export-button'),
                onPressed: onExportPackagePressed,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('导出报销材料包'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (linkedTickets.isEmpty)
            _LinkedTicketEmptyState(onAttachPressed: onAttachPressed)
          else
            for (final ticket in linkedTickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _LinkedTicketCard(
                  ticket: ticket,
                  onRemove: () => onRemoveTicket(ticket.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _LinkedTicketCard extends StatelessWidget {
  const _LinkedTicketCard({required this.ticket, required this.onRemove});

  final Ticket ticket;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(ticketTypeLabel(ticket.type))),
                    Chip(label: Text(ticketStatusLabel(ticket.status))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatTicketDate(ticket.occurredOn)} · ${formatTicketAmount(ticket.amountInCents)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: '移出报销单',
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.error,
            ),
            icon: const Icon(Icons.link_off_outlined),
          ),
        ],
      ),
    );
  }
}

class _LinkedTicketEmptyState extends StatelessWidget {
  const _LinkedTicketEmptyState({required this.onAttachPressed});

  final VoidCallback onAttachPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('reimbursement-linked-empty-state'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.receipt_long_outlined, color: colors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有关联票据',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '先关联需要报销的票据。',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAttachPressed,
            icon: const Icon(Icons.link_rounded),
            label: const Text('去关联票据'),
          ),
        ],
      ),
    );
  }
}

class _LinkedTicketsErrorState extends StatelessWidget {
  const _LinkedTicketsErrorState({required this.onRetry});

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
          const SizedBox(height: 14),
          Text(
            '加载关联票据失败',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

class _MissingSheetState extends StatelessWidget {
  const _MissingSheetState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 40),
              const SizedBox(height: 12),
              const Text('未找到这张报销单'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onBack, child: const Text('返回列表')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachTicketSheet extends ConsumerWidget {
  const _AttachTicketSheet({required this.reimbursementSheetId});

  final int reimbursementSheetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(reimbursementAvailableTicketsProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ticketsAsync.when(
            data: (tickets) {
              if (tickets.isEmpty) {
                return Center(
                  child: AppSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link_off_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text('没有可关联的票据'),
                        const SizedBox(height: 8),
                        const Text(
                          '请先新增票据，或先把其他报销单中的票据移出。',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionHeader(
                    title: '关联现有票据',
                    subtitle: '选择一张票据加入当前报销单。',
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AttachableTicketCard(
                            ticket: ticket,
                            onAttach: () =>
                                _attachTicket(context, ref, ticket.id),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) {
              return Center(
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('加载可关联票据失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(
                          reimbursementAvailableTicketsProvider,
                        ),
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _attachTicket(
    BuildContext context,
    WidgetRef ref,
    int ticketId,
  ) async {
    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .attachTicketToReimbursementSheet(
            ticketId: ticketId,
            reimbursementSheetId: reimbursementSheetId,
          );
      ref.invalidate(reimbursementLinkedTicketsProvider(reimbursementSheetId));
      ref.invalidate(reimbursementAvailableTicketsProvider);
      ref.invalidate(ticketListProvider);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联票据失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('票据已关联到报销单')));
  }
}

class _AttachableTicketCard extends StatelessWidget {
  const _AttachableTicketCard({required this.ticket, required this.onAttach});

  final Ticket ticket;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(ticketTypeLabel(ticket.type))),
                    Chip(label: Text(ticketStatusLabel(ticket.status))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatTicketDate(ticket.occurredOn)} · ${formatTicketAmount(ticket.amountInCents)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(onPressed: onAttach, child: const Text('关联')),
        ],
      ),
    );
  }
}
