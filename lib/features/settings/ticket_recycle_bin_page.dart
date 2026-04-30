import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/home/home_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_support.dart';
import 'package:ticket_box/features/tags/tag_providers.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class TicketRecycleBinPage extends ConsumerWidget {
  const TicketRecycleBinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trashedTicketsAsync = ref.watch(trashedTicketListProvider);
    final trashedSheetsAsync = ref.watch(trashedReimbursementSheetListProvider);
    final trashedTicketCount = trashedTicketsAsync.whenOrNull(
      data: (tickets) => tickets.length,
    );
    final trashedSheetCount = trashedSheetsAsync.whenOrNull(
      data: (sheets) => sheets.length,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trashedTicketListProvider);
            ref.invalidate(trashedReimbursementSheetListProvider);
            await ref.read(trashedTicketListProvider.future);
            await ref.read(trashedReimbursementSheetListProvider.future);
          },
          child: ListView(
            key: const ValueKey('ticket-recycle-bin-page'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _RecycleBinOverviewCard(
                ticketCount: trashedTicketCount,
                sheetCount: trashedSheetCount,
                hasError:
                    trashedTicketsAsync.hasError || trashedSheetsAsync.hasError,
              ),
              const SizedBox(height: 20),
              const AppSectionHeader(
                title: '已删除票据',
                subtitle: '恢复后会回到票据列表。永久删除会清理票据和本地附件。',
              ),
              const SizedBox(height: 12),
              trashedTicketsAsync.when(
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const _RecycleBinEmptyState(
                      title: '暂无已删除票据',
                      subtitle: '这里没有待恢复的票据。删除票据后会先显示在这里。',
                    );
                  }

                  return Column(
                    children: [
                      for (final ticket in tickets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TrashedTicketCard(
                            ticket: ticket,
                            onRestore: () =>
                                _restoreTicket(context, ref, ticket),
                            onPermanentDelete: () =>
                                _permanentlyDeleteTicket(context, ref, ticket),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const _RecycleBinLoadingCard(),
                error: (error, stackTrace) => _RecycleBinErrorCard(
                  message: '加载已删除票据失败',
                  onRetry: () => ref.invalidate(trashedTicketListProvider),
                ),
              ),
              const SizedBox(height: 20),
              const AppSectionHeader(
                title: '已删除报销单',
                subtitle: '恢复后会回到报销单列表，关联票据和附件保持不变。',
              ),
              const SizedBox(height: 12),
              trashedSheetsAsync.when(
                data: (sheets) {
                  if (sheets.isEmpty) {
                    return const _RecycleBinEmptyState(
                      title: '暂无已删除报销单',
                      subtitle: '这里没有待恢复的报销单。删除报销单后会先显示在这里。',
                    );
                  }

                  return Column(
                    children: [
                      for (final sheet in sheets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _TrashedReimbursementSheetCard(
                            sheet: sheet,
                            onRestore: () => _restoreSheet(context, ref, sheet),
                            onPermanentDelete: () =>
                                _permanentlyDeleteSheet(context, ref, sheet),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const _RecycleBinLoadingCard(),
                error: (error, stackTrace) => _RecycleBinErrorCard(
                  message: '加载已删除报销单失败',
                  onRetry: () =>
                      ref.invalidate(trashedReimbursementSheetListProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreTicket(
    BuildContext context,
    WidgetRef ref,
    Ticket ticket,
  ) async {
    try {
      await ref.read(ticketRepositoryProvider).restoreTicket(ticket.id);
      _refreshTicketState(ref, ticket);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('恢复失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('票据已恢复')));
  }

  Future<void> _permanentlyDeleteTicket(
    BuildContext context,
    WidgetRef ref,
    Ticket ticket,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('永久删除票据'),
          content: const Text('将删除票据记录和本地附件，操作后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('永久删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    var fileCleanupFailed = false;
    try {
      await ref
          .read(ticketRepositoryProvider)
          .permanentlyDeleteTicket(ticket.id);
      try {
        await ref
            .read(ticketFileServiceProvider)
            .deleteStoredFile(ticket.filePath);
      } catch (_) {
        fileCleanupFailed = true;
      }
      _refreshTicketState(ref, ticket);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('永久删除失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(fileCleanupFailed ? '票据已删除，但附件清理失败' : '票据已永久删除')),
    );
  }

  Future<void> _restoreSheet(
    BuildContext context,
    WidgetRef ref,
    ReimbursementSheet sheet,
  ) async {
    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .restoreReimbursementSheet(sheet.id);
      _refreshSheetState(ref, sheet);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('恢复报销单失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('报销单已恢复')));
  }

  Future<void> _permanentlyDeleteSheet(
    BuildContext context,
    WidgetRef ref,
    ReimbursementSheet sheet,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('永久删除报销单'),
          content: const Text('只会删除报销单记录，关联票据和附件会保留。操作后无法恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('永久删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(reimbursementRepositoryProvider)
          .permanentlyDeleteReimbursementSheet(sheet.id);
      _refreshSheetState(ref, sheet, unlinkTickets: true);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('永久删除报销单失败，请稍后重试')));
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('报销单已永久删除，票据已保留')));
  }

  void _refreshTicketState(WidgetRef ref, Ticket ticket) {
    ref.invalidate(trashedTicketListProvider);
    ref.invalidate(ticketListProvider);
    ref.invalidate(ticketRecentListProvider);
    ref.invalidate(ticketByIdProvider(ticket.id));
    ref.invalidate(ticketTagsProvider(ticket.id));
    ref.invalidate(tagSummaryListProvider);
    ref.invalidate(homeWorkbenchProvider);
    ref.invalidate(reimbursementAvailableTicketsProvider);

    final sheetId = ticket.reimbursementSheetId;
    if (sheetId != null) {
      ref.invalidate(reimbursementLinkedTicketsProvider(sheetId));
    }
  }

  void _refreshSheetState(
    WidgetRef ref,
    ReimbursementSheet sheet, {
    bool unlinkTickets = false,
  }) {
    ref.invalidate(trashedReimbursementSheetListProvider);
    ref.invalidate(reimbursementListProvider);
    ref.invalidate(reimbursementByIdProvider(sheet.id));
    ref.invalidate(reimbursementLinkedTicketsProvider(sheet.id));
    ref.invalidate(homeWorkbenchProvider);

    if (unlinkTickets) {
      ref.invalidate(reimbursementAvailableTicketsProvider);
      ref.invalidate(ticketListProvider);
      ref.invalidate(ticketRecentListProvider);
    }
  }
}

class _RecycleBinOverviewCard extends StatelessWidget {
  const _RecycleBinOverviewCard({
    required this.ticketCount,
    required this.sheetCount,
    required this.hasError,
  });

  final int? ticketCount;
  final int? sheetCount;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final totalCount = ticketCount != null && sheetCount != null
        ? ticketCount! + sheetCount!
        : null;
    final isEmpty = totalCount == 0;

    return AppSurfaceCard(
      color: const Color(0xFFF8FBF9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: isEmpty ? '回收站是空的' : '回收站状态',
            subtitle: hasError ? '部分状态加载失败，请下拉刷新。' : '回收站中的内容可以恢复。永久删除后无法恢复。',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RecycleBinMetric(
                  label: '已删除票据',
                  value: _formatCount(ticketCount),
                  valueKey: 'recycle-bin-ticket-count',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RecycleBinMetric(
                  label: '已删除报销单',
                  value: _formatCount(sheetCount),
                  valueKey: 'recycle-bin-sheet-count',
                ),
              ),
            ],
          ),
          if (isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '当前没有已删除内容。误删的票据或报销单会先进入这里。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int? count) {
    if (count == null) {
      return hasError ? '加载失败' : '读取中';
    }
    return '$count';
  }
}

class _RecycleBinMetric extends StatelessWidget {
  const _RecycleBinMetric({
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

class _TrashedTicketCard extends StatelessWidget {
  const _TrashedTicketCard({
    required this.ticket,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final Ticket ticket;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = ticket.title.trim().isEmpty ? '未命名票据' : ticket.title;
    final deletedAt = ticket.deletedAt;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.delete_outline_rounded, color: colors.error),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatTicketDate(ticket.occurredOn)} · ${formatTicketAmount(ticket.amountInCents)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '删除时间：${deletedAt == null ? '未知' : _formatDeletedAt(deletedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: ValueKey('restore-ticket-${ticket.id}'),
                onPressed: onRestore,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('恢复'),
              ),
              TextButton.icon(
                key: ValueKey('permanently-delete-ticket-${ticket.id}'),
                onPressed: onPermanentDelete,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('永久删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDeletedAt(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _TrashedReimbursementSheetCard extends StatelessWidget {
  const _TrashedReimbursementSheetCard({
    required this.sheet,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  final ReimbursementSheet sheet;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = sheet.title.trim().isEmpty ? '未命名报销单' : sheet.title;
    final deletedAt = sheet.deletedAt;
    final description = (sheet.description ?? '').trim();

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(reimbursementStatusLabel(sheet.status)),
                        ),
                        if (description.isNotEmpty)
                          Chip(label: Text(description)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '删除时间：${deletedAt == null ? '未知' : _formatDeletedAt(deletedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: ValueKey('restore-reimbursement-${sheet.id}'),
                onPressed: onRestore,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('恢复'),
              ),
              TextButton.icon(
                key: ValueKey('permanently-delete-reimbursement-${sheet.id}'),
                onPressed: onPermanentDelete,
                style: TextButton.styleFrom(foregroundColor: colors.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('永久删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDeletedAt(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}

class _RecycleBinEmptyState extends StatelessWidget {
  const _RecycleBinEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.delete_sweep_outlined,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RecycleBinLoadingCard extends StatelessWidget {
  const _RecycleBinLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const AppSurfaceCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _RecycleBinErrorCard extends StatelessWidget {
  const _RecycleBinErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}
