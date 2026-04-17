import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/app/navigation/app_destination.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/home/home_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_detail_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_form_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_support.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workbenchAsync = ref.watch(homeWorkbenchProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(homeWorkbenchProvider);
        await ref.read(homeWorkbenchProvider.future);
      },
      child: ListView(
        key: const ValueKey('home-page-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _WorkbenchHeroCard(
            onCreateTicket: () => _openCreateTicketPage(context, ref),
            onCreateReimbursement: () =>
                _openCreateReimbursementPage(context, ref),
            onOpenTickets: () => _openMainSection(context, AppRoutes.tickets),
            onOpenReimbursements: () =>
                _openMainSection(context, AppRoutes.reimbursements),
          ),
          const SizedBox(height: 24),
          workbenchAsync.when(
            data: (data) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummarySection(data: data),
                  const SizedBox(height: 24),
                  _RecentTicketsSection(
                    tickets: data.recentTickets,
                    onViewAll: () =>
                        _openMainSection(context, AppRoutes.tickets),
                    onCreatePressed: () => _openCreateTicketPage(context, ref),
                    onOpenTicket: (ticketId) =>
                        _openTicketDetailPage(context, ref, ticketId),
                  ),
                  const SizedBox(height: 24),
                  _RecentReimbursementsSection(
                    sheets: data.recentReimbursementSheets,
                    onViewAll: () =>
                        _openMainSection(context, AppRoutes.reimbursements),
                    onCreatePressed: () =>
                        _openCreateReimbursementPage(context, ref),
                    onOpenSheet: (sheetId) =>
                        _openReimbursementDetailPage(context, ref, sheetId),
                  ),
                ],
              );
            },
            loading: () => const _WorkbenchLoadingState(),
            error: (error, stackTrace) {
              return _WorkbenchErrorState(
                onRetry: () => ref.invalidate(homeWorkbenchProvider),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateTicketPage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TicketFormPage()),
    );

    if (!context.mounted) {
      return;
    }

    ref.invalidate(homeWorkbenchProvider);
  }

  Future<void> _openCreateReimbursementPage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ReimbursementFormPage()),
    );

    if (!context.mounted) {
      return;
    }

    ref.invalidate(homeWorkbenchProvider);
  }

  Future<void> _openTicketDetailPage(
    BuildContext context,
    WidgetRef ref,
    int ticketId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(ticketId: ticketId),
      ),
    );

    if (!context.mounted) {
      return;
    }

    ref.invalidate(homeWorkbenchProvider);
  }

  Future<void> _openReimbursementDetailPage(
    BuildContext context,
    WidgetRef ref,
    int reimbursementSheetId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReimbursementDetailPage(reimbursementSheetId: reimbursementSheetId),
      ),
    );

    if (!context.mounted) {
      return;
    }

    ref.invalidate(homeWorkbenchProvider);
  }

  void _openMainSection(BuildContext context, String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }
}

class _WorkbenchHeroCard extends StatelessWidget {
  const _WorkbenchHeroCard({
    required this.onCreateTicket,
    required this.onCreateReimbursement,
    required this.onOpenTickets,
    required this.onOpenReimbursements,
  });

  final VoidCallback onCreateTicket;
  final VoidCallback onCreateReimbursement;
  final VoidCallback onOpenTickets;
  final VoidCallback onOpenReimbursements;

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '本地票据工作台',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('先处理今天要整理的票据', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      '在这里看待报销数量、最近票据和最近报销单。',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onCreateTicket,
                icon: const Icon(Icons.add),
                label: const Text('新增票据'),
              ),
              FilledButton.tonalIcon(
                onPressed: onCreateReimbursement,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('新建报销单'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenTickets,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('查看票据'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenReimbursements,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('查看报销单'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.data});

  final HomeWorkbenchData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '工作概览', subtitle: '先看数量，再继续处理'),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              key: const ValueKey('home-summary-total-tickets'),
              icon: Icons.receipt_long_rounded,
              label: '全部票据',
              value: '${data.ticketCount}',
            ),
            _SummaryCard(
              key: const ValueKey('home-summary-pending-tickets'),
              icon: Icons.schedule_rounded,
              label: '待报销',
              value: '${data.pendingTicketCount}',
            ),
            _SummaryCard(
              key: const ValueKey('home-summary-reimbursement-sheets'),
              icon: Icons.account_balance_wallet_rounded,
              label: '报销单',
              value: '${data.reimbursementSheetCount}',
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 156),
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 20, color: colors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTicketsSection extends StatelessWidget {
  const _RecentTicketsSection({
    required this.tickets,
    required this.onViewAll,
    required this.onCreatePressed,
    required this.onOpenTicket,
  });

  final List<Ticket> tickets;
  final VoidCallback onViewAll;
  final VoidCallback onCreatePressed;
  final ValueChanged<int> onOpenTicket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '最近票据',
          subtitle: tickets.isEmpty ? '先新增票据，再从这里继续整理。' : '默认只显示最近 3 张。',
          trailing: TextButton(onPressed: onViewAll, child: const Text('查看票据')),
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          child: tickets.isEmpty
              ? _SectionEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: '还没有票据',
                  description: '先新增一张票据。',
                  buttonText: '新增票据',
                  onPressed: onCreatePressed,
                )
              : Column(
                  children: [
                    for (var index = 0; index < tickets.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == tickets.length - 1 ? 0 : 12,
                        ),
                        child: _RecentTicketCard(
                          ticket: tickets[index],
                          onTap: () => onOpenTicket(tickets[index].id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentReimbursementsSection extends StatelessWidget {
  const _RecentReimbursementsSection({
    required this.sheets,
    required this.onViewAll,
    required this.onCreatePressed,
    required this.onOpenSheet,
  });

  final List<ReimbursementSheet> sheets;
  final VoidCallback onViewAll;
  final VoidCallback onCreatePressed;
  final ValueChanged<int> onOpenSheet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '最近报销单',
          subtitle: sheets.isEmpty ? '新建报销单后，这里会显示最近记录。' : '从这里继续关联票据或导出。',
          trailing: TextButton(
            onPressed: onViewAll,
            child: const Text('查看报销单'),
          ),
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          child: sheets.isEmpty
              ? _SectionEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: '还没有报销单',
                  description: '先新建一张报销单。',
                  buttonText: '新建报销单',
                  onPressed: onCreatePressed,
                )
              : Column(
                  children: [
                    for (var index = 0; index < sheets.length; index++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == sheets.length - 1 ? 0 : 12,
                        ),
                        child: _RecentReimbursementCard(
                          sheet: sheets[index],
                          onTap: () => onOpenSheet(sheets[index].id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RecentTicketCard extends StatelessWidget {
  const _RecentTicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentReimbursementCard extends StatelessWidget {
  const _RecentReimbursementCard({required this.sheet, required this.onTap});

  final ReimbursementSheet sheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final description = (sheet.description ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              sheet.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(reimbursementStatusLabel(sheet.status)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description.isEmpty ? '暂无备注' : description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '更新于 ${formatTicketDate(sheet.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: colors.primary),
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
          description,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(buttonText),
        ),
      ],
    );
  }
}

class _WorkbenchLoadingState extends StatelessWidget {
  const _WorkbenchLoadingState();

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        children: const [
          SizedBox(height: 8),
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在加载首页数据'),
        ],
      ),
    );
  }
}

class _WorkbenchErrorState extends StatelessWidget {
  const _WorkbenchErrorState({required this.onRetry});

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
            '加载首页失败',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '请重试。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}
