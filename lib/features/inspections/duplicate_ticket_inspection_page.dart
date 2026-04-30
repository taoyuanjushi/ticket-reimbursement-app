import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/inspections/duplicate_ticket_inspection_service.dart';
import 'package:ticket_box/features/inspections/inspection_providers.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class DuplicateTicketInspectionPage extends ConsumerWidget {
  const DuplicateTicketInspectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionAsync = ref.watch(duplicateTicketInspectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('资料检查')),
      body: SafeArea(
        child: inspectionAsync.when(
          data: (result) => _DuplicateInspectionContent(
            result: result,
            onRefresh: () => ref.invalidate(duplicateTicketInspectionProvider),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40),
                      const SizedBox(height: 12),
                      const Text('检查失败，请稍后重试'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(duplicateTicketInspectionProvider),
                        child: const Text('重新检查'),
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
}

class _DuplicateInspectionContent extends StatelessWidget {
  const _DuplicateInspectionContent({
    required this.result,
    required this.onRefresh,
  });

  final DuplicateTicketInspectionResult result;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('duplicate-ticket-inspection-page'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AppSurfaceCard(
          color: const Color(0xFFF8FBF9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: '可能重复票据',
                subtitle: '按日期、金额和标题相似度做本地检查',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _InspectionSummaryItem(
                      label: '重复组',
                      value: '${result.groupCount}',
                      valueKey: 'duplicate-group-count',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InspectionSummaryItem(
                      label: '涉及票据',
                      value: '${result.ticketCount}',
                      valueKey: 'duplicate-ticket-count',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新检查'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (result.groups.isEmpty)
          const _NoDuplicateState()
        else
          for (var index = 0; index < result.groups.length; index += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _DuplicateGroupCard(
                groupIndex: index + 1,
                group: result.groups[index],
              ),
            ),
      ],
    );
  }
}

class _InspectionSummaryItem extends StatelessWidget {
  const _InspectionSummaryItem({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            key: ValueKey(valueKey),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  const _DuplicateGroupCard({required this.groupIndex, required this.group});

  final int groupIndex;
  final PossibleDuplicateTicketGroup group;

  @override
  Widget build(BuildContext context) {
    final firstTicket = group.tickets.first;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: '重复组 $groupIndex',
            subtitle:
                '${formatTicketDate(firstTicket.occurredOn)} · ${formatTicketAmount(firstTicket.amountInCents)}',
          ),
          const SizedBox(height: 10),
          const Chip(label: Text('同日同金额，标题相近')),
          const SizedBox(height: 12),
          _DuplicateReviewSuggestionBox(
            onReview: () => _openReviewSheet(context),
          ),
          const SizedBox(height: 14),
          for (final ticket in group.tickets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DuplicateTicketItem(ticket: ticket),
            ),
        ],
      ),
    );
  }

  Future<void> _openReviewSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DuplicateReviewSheet(tickets: group.tickets),
    );
  }
}

class _DuplicateReviewSuggestionBox extends StatelessWidget {
  const _DuplicateReviewSuggestionBox({required this.onReview});

  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
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
            '处理建议',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '逐张查看内容、附件和备注，再手动决定是否编辑或保留。不会自动合并或删除。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            key: const ValueKey('duplicate-review-action'),
            onPressed: onReview,
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text('对比后手动处理'),
          ),
        ],
      ),
    );
  }
}

class _DuplicateReviewSheet extends StatelessWidget {
  const _DuplicateReviewSheet({required this.tickets});

  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: '重复票据复核',
                subtitle: '只提供查看和编辑入口，是否处理由你手动决定。',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DuplicateTicketItem(ticket: ticket),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuplicateTicketItem extends StatelessWidget {
  const _DuplicateTicketItem({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = ticket.title.trim().isEmpty ? '未命名票据' : ticket.title;

    return InkWell(
      key: ValueKey('duplicate-ticket-${ticket.id}'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.receipt_long_outlined, color: colors.primary),
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
                  const SizedBox(height: 6),
                  Text(
                    '${formatTicketDate(ticket.occurredOn)} · ${formatTicketAmount(ticket.amountInCents)} · ${ticketStatusLabel(ticket.status)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        key: ValueKey('duplicate-ticket-view-${ticket.id}'),
                        onPressed: () => _openDetail(context),
                        child: const Text('查看票据'),
                      ),
                      OutlinedButton(
                        key: ValueKey('duplicate-ticket-edit-${ticket.id}'),
                        onPressed: () => _openEdit(context),
                        child: const Text('编辑票据'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(ticketId: ticket.id),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketFormPage(initialTicket: ticket),
      ),
    );
  }
}

class _NoDuplicateState extends StatelessWidget {
  const _NoDuplicateState();

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
              Icons.task_alt_rounded,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '暂未发现可能重复票据',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '检查只做提示，不会自动修改任何票据。',
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
