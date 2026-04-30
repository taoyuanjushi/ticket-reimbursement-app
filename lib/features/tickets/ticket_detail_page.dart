import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reminders/reminder_providers.dart';
import 'package:ticket_box/features/reminders/reminder_support.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/tags/tag_providers.dart';
import 'package:ticket_box/features/tickets/ticket_file_preview_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class TicketDetailPage extends ConsumerWidget {
  const TicketDetailPage({required this.ticketId, super.key});

  final int ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketAsync = ref.watch(ticketByIdProvider(ticketId));
    final ticketTagsAsync = ref.watch(ticketTagsProvider(ticketId));

    return Scaffold(
      appBar: AppBar(title: const Text('票据详情')),
      body: SafeArea(
        child: ticketAsync.when(
          data: (ticket) {
            if (ticket == null) {
              return _MissingTicketState(
                onBack: () => Navigator.of(context).pop(),
              );
            }

            return ListView(
              key: const ValueKey('ticket-detail-page'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _TicketHeadlineCard(ticket: ticket),
                const SizedBox(height: 16),
                _TicketActionCard(
                  onEdit: () => _openEditPage(context, ticket),
                  onReminder: () => _createReminder(context, ref, ticket),
                  onDelete: () => _deleteTicket(context, ref, ticket),
                ),
                const SizedBox(height: 16),
                _TicketInfoCard(ticket: ticket),
                const SizedBox(height: 16),
                _TicketTagsCard(
                  tagsAsync: ticketTagsAsync,
                  onRetry: () => ref.invalidate(ticketTagsProvider(ticketId)),
                ),
                const SizedBox(height: 16),
                _TicketAttachmentCard(
                  ticket: ticket,
                  onOpenPressed: () => _openAttachmentPreview(context, ticket),
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
                      const Text('加载票据详情失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(ticketByIdProvider(ticketId)),
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

  Future<void> _openEditPage(BuildContext context, Ticket ticket) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketFormPage(initialTicket: ticket),
      ),
    );
  }

  Future<void> _createReminder(
    BuildContext context,
    WidgetRef ref,
    Ticket ticket,
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
          .scheduleTicketReminder(
            ticketId: ticket.id,
            title: ticket.title,
            settings: settings,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已创建票据提醒：${formatReminderScheduleDateTime(scheduledAt)}',
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

  Future<void> _openAttachmentPreview(
    BuildContext context,
    Ticket ticket,
  ) async {
    final filePath = ticket.filePath;
    if (filePath == null || filePath.trim().isEmpty) {
      return;
    }

    final fileName = resolveTicketFileName(
      fileName: ticket.fileName,
      filePath: filePath,
    );
    final fileType = resolveTicketFileType(
      fileType: ticket.fileType,
      fileName: ticket.fileName,
      filePath: filePath,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketFilePreviewPage(
          filePath: filePath,
          fileName: fileName,
          fileType: fileType,
        ),
      ),
    );
  }

  Future<void> _deleteTicket(
    BuildContext context,
    WidgetRef ref,
    Ticket ticket,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除票据'),
          content: const Text('票据会移入回收站，附件文件不会立即删除。'),
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
      await ref.read(ticketRepositoryProvider).deleteTicket(ticket.id);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(const SnackBar(content: Text('移入回收站失败，请稍后重试')));
      return;
    }

    ref.invalidate(ticketListProvider);
    ref.invalidate(ticketRecentListProvider);
    ref.invalidate(ticketByIdProvider(ticket.id));
    ref.invalidate(reimbursementAvailableTicketsProvider);
    if (ticket.reimbursementSheetId != null) {
      ref.invalidate(
        reimbursementLinkedTicketsProvider(ticket.reimbursementSheetId!),
      );
    }

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('票据已移入回收站')));
  }
}

class _TicketHeadlineCard extends StatelessWidget {
  const _TicketHeadlineCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                    Text(ticket.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      formatTicketAmount(ticket.amountInCents),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
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
                  Icons.receipt_long_rounded,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(ticketTypeLabel(ticket.type))),
              Chip(label: Text(ticketStatusLabel(ticket.status))),
              Chip(label: Text(formatTicketDate(ticket.occurredOn))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketActionCard extends StatelessWidget {
  const _TicketActionCard({
    required this.onEdit,
    required this.onReminder,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onReminder;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '快捷操作', subtitle: '编辑、提醒和删除都在这里'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('编辑票据'),
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
              style: TextButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除票据'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketInfoCard extends StatelessWidget {
  const _TicketInfoCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '基础信息', subtitle: '票据的核心字段'),
          const SizedBox(height: 18),
          _InfoRow(label: '标题', value: ticket.title),
          _InfoRow(
            label: '金额',
            value: formatTicketAmount(ticket.amountInCents),
          ),
          _InfoRow(label: '日期', value: formatTicketDate(ticket.occurredOn)),
          _InfoRow(label: '类型', value: ticketTypeLabel(ticket.type)),
          _InfoRow(label: '状态', value: ticketStatusLabel(ticket.status)),
          _InfoRow(label: '备注', value: ticket.note ?? '未填写', isLast: true),
        ],
      ),
    );
  }
}

class _TicketTagsCard extends StatelessWidget {
  const _TicketTagsCard({required this.tagsAsync, required this.onRetry});

  final AsyncValue<List<Tag>> tagsAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '标签', subtitle: '用标签整理这张票据'),
          const SizedBox(height: 18),
          tagsAsync.when(
            data: (tags) {
              if (tags.isEmpty) {
                return Text(
                  '未添加标签',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    Chip(
                      label: Text(tag.name),
                      avatar: const Icon(Icons.label_outline_rounded, size: 18),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '加载标签失败',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: colors.error),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRetry, child: const Text('重新加载')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TicketAttachmentCard extends StatelessWidget {
  const _TicketAttachmentCard({
    required this.ticket,
    required this.onOpenPressed,
  });

  final Ticket ticket;
  final VoidCallback onOpenPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filePath = ticket.filePath;
    final hasAttachment = filePath != null && filePath.trim().isNotEmpty;
    final fileName = resolveTicketFileName(
      fileName: ticket.fileName,
      filePath: filePath,
    );
    final fileType = resolveTicketFileType(
      fileType: ticket.fileType,
      fileName: ticket.fileName,
      filePath: filePath,
    );
    final fileExists = hasAttachment && File(filePath).existsSync();

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: '附件信息', subtitle: '本地保存的图片或 PDF'),
          const SizedBox(height: 18),
          _InfoRow(label: '附件状态', value: hasAttachment ? '已附加' : '未附加'),
          _InfoRow(
            label: '文件类型',
            value: hasAttachment ? ticketFileTypeLabel(fileType) : '无',
          ),
          _InfoRow(
            label: '文件名',
            value: hasAttachment ? fileName : '无',
            isLast: true,
          ),
          if (hasAttachment) ...[
            const SizedBox(height: 16),
            if (fileExists && isImageTicketFile(fileType))
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(
                  File(filePath),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (fileExists && isPdfTicketFile(fileType))
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: colors.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '本地 PDF 已保存，可在附件页查看。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                '附件不可用，可能已被移除。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.error),
              ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: fileExists ? onOpenPressed : null,
              icon: Icon(
                isPdfTicketFile(fileType)
                    ? Icons.picture_as_pdf_outlined
                    : Icons.visibility_outlined,
              ),
              label: Text(isPdfTicketFile(fileType) ? '查看 PDF' : '查看附件'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTicketState extends StatelessWidget {
  const _MissingTicketState({required this.onBack});

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
              const Icon(Icons.receipt_long_outlined, size: 40),
              const SizedBox(height: 12),
              const Text('未找到这张票据'),
              const SizedBox(height: 12),
              FilledButton(onPressed: onBack, child: const Text('返回列表')),
            ],
          ),
        ),
      ),
    );
  }
}
