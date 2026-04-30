import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/inspections/inspection_providers.dart';
import 'package:ticket_box/features/inspections/reimbursement_completeness_inspection_service.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_detail_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_form_page.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class ReimbursementCompletenessInspectionPage extends ConsumerWidget {
  const ReimbursementCompletenessInspectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionAsync = ref.watch(
      reimbursementCompletenessInspectionProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('报销单完整性检查')),
      body: SafeArea(
        child: inspectionAsync.when(
          data: (result) => _ReimbursementCompletenessInspectionContent(
            result: result,
            onRefresh: () =>
                ref.invalidate(reimbursementCompletenessInspectionProvider),
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
                        onPressed: () => ref.invalidate(
                          reimbursementCompletenessInspectionProvider,
                        ),
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

class _ReimbursementCompletenessInspectionContent extends StatelessWidget {
  const _ReimbursementCompletenessInspectionContent({
    required this.result,
    required this.onRefresh,
  });

  final ReimbursementCompletenessInspectionResult result;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('reimbursement-completeness-inspection-page'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AppSurfaceCard(
          color: const Color(0xFFF8FBF9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: '报销单完整性',
                subtitle: '导出材料包前检查关联票据和附件',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _InspectionSummaryItem(
                      label: '问题报销单',
                      value: '${result.problematicSheetCount}',
                      valueKey: 'problematic-reimbursement-count',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InspectionSummaryItem(
                      label: '问题项',
                      value: '${result.totalIssueCount}',
                      valueKey: 'reimbursement-completeness-issue-count',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _IssueTypeSummary(counts: result.issueCountsByType),
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
        if (result.records.isEmpty)
          const _NoReimbursementIssueState()
        else
          for (final record in result.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ProblematicReimbursementCard(record: record),
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

class _IssueTypeSummary extends StatelessWidget {
  const _IssueTypeSummary({required this.counts});

  final Map<ReimbursementCompletenessIssueType, int> counts;

  @override
  Widget build(BuildContext context) {
    final chips = ReimbursementCompletenessIssueType.values
        .map((type) {
          final count = counts[type] ?? 0;
          if (count == 0) {
            return null;
          }

          return Chip(label: Text('${_issueTypeLabel(type)} $count'));
        })
        .whereType<Chip>()
        .toList();

    if (chips.isEmpty) {
      return const Text('当前没有发现明显问题。');
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  String _issueTypeLabel(ReimbursementCompletenessIssueType type) {
    switch (type) {
      case ReimbursementCompletenessIssueType.noLinkedTickets:
        return '未关联票据';
      case ReimbursementCompletenessIssueType.linkedTicketWithoutAttachment:
        return '票据无附件';
      case ReimbursementCompletenessIssueType.linkedTicketMissingAttachmentFile:
        return '附件文件缺失';
      case ReimbursementCompletenessIssueType.linkedTicketInvalidAmount:
        return '票据金额异常';
      case ReimbursementCompletenessIssueType.linkedTicketEmptyTitle:
        return '票据标题为空';
      case ReimbursementCompletenessIssueType.emptyNote:
        return '报销备注为空';
    }
  }
}

class _ProblematicReimbursementCard extends StatelessWidget {
  const _ProblematicReimbursementCard({required this.record});

  final ProblematicReimbursementSheetRecord record;

  @override
  Widget build(BuildContext context) {
    final sheet = record.sheet;
    final colors = Theme.of(context).colorScheme;
    final title = sheet.title.trim().isEmpty ? '未命名报销单' : sheet.title;

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('problematic-reimbursement-${sheet.id}'),
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: colors.primary,
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
                    Text(
                      '${record.linkedTicketCount} 张票据 · ${formatTicketAmount(record.totalAmountInCents)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final issue in record.issues)
                          Chip(label: Text(issue.displayLabel)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ReimbursementRepairSuggestionBox(
                      suggestions: _buildSuggestions(),
                      onDetail: () => _openDetail(context),
                      onEdit: () => _openEdit(context),
                      onTickets: record.problematicTickets.isEmpty
                          ? null
                          : () => _openProblematicTickets(context),
                      detailKey: ValueKey(
                        'reimbursement-repair-detail-${sheet.id}',
                      ),
                      ticketKey: ValueKey(
                        'reimbursement-repair-tickets-${sheet.id}',
                      ),
                      editKey: ValueKey(
                        'reimbursement-repair-edit-${sheet.id}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildSuggestions() {
    final suggestions = <String>[];

    for (final issue in record.issues) {
      switch (issue.type) {
        case ReimbursementCompletenessIssueType.noLinkedTickets:
          suggestions.add('先进入报销单，关联需要报销的票据。');
          break;
        case ReimbursementCompletenessIssueType.linkedTicketWithoutAttachment:
          suggestions.add('为缺附件的关联票据补充图片或 PDF。');
          break;
        case ReimbursementCompletenessIssueType
            .linkedTicketMissingAttachmentFile:
          suggestions.add('重新附加缺失的本地文件。');
          break;
        case ReimbursementCompletenessIssueType.linkedTicketInvalidAmount:
          suggestions.add('核对关联票据金额。');
          break;
        case ReimbursementCompletenessIssueType.linkedTicketEmptyTitle:
          suggestions.add('补全关联票据标题。');
          break;
        case ReimbursementCompletenessIssueType.emptyNote:
          suggestions.add('补充报销单备注，方便导出说明。');
          break;
      }
    }

    return suggestions;
  }

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReimbursementDetailPage(reimbursementSheetId: record.sheet.id),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReimbursementFormPage(initialSheet: record.sheet),
      ),
    );
  }

  Future<void> _openProblematicTickets(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _ProblematicTicketsSheet(
          tickets: record.problematicTickets,
          onOpenTicket: (ticketId) {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => TicketDetailPage(ticketId: ticketId),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReimbursementRepairSuggestionBox extends StatelessWidget {
  const _ReimbursementRepairSuggestionBox({
    required this.suggestions,
    required this.onDetail,
    required this.onTickets,
    required this.onEdit,
    required this.detailKey,
    required this.ticketKey,
    required this.editKey,
  });

  final List<String> suggestions;
  final VoidCallback onDetail;
  final VoidCallback? onTickets;
  final VoidCallback onEdit;
  final Key detailKey;
  final Key ticketKey;
  final Key editKey;

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
          for (final suggestion in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                suggestion,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                key: detailKey,
                onPressed: onDetail,
                child: const Text('查看报销单'),
              ),
              if (onTickets != null)
                OutlinedButton(
                  key: ticketKey,
                  onPressed: onTickets,
                  child: const Text('处理票据'),
                ),
              TextButton(
                key: editKey,
                onPressed: onEdit,
                child: const Text('去编辑'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProblematicTicketsSheet extends StatelessWidget {
  const _ProblematicTicketsSheet({
    required this.tickets,
    required this.onOpenTicket,
  });

  final List<Ticket> tickets;
  final ValueChanged<int> onOpenTicket;

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
                title: '处理关联票据',
                subtitle: '选择一张票据查看详情，所有修改仍需手动完成。',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProblematicTicketTile(
                        ticket: ticket,
                        onTap: () => onOpenTicket(ticket.id),
                      ),
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

class _ProblematicTicketTile extends StatelessWidget {
  const _ProblematicTicketTile({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = ticket.title.trim().isEmpty ? '未命名票据' : ticket.title;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('reimbursement-problem-ticket-${ticket.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
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
                  Icons.receipt_long_outlined,
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
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatTicketDate(ticket.occurredOn)} · ${formatTicketAmount(ticket.amountInCents)} · ${ticketStatusLabel(ticket.status)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoReimbursementIssueState extends StatelessWidget {
  const _NoReimbursementIssueState();

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
            '暂未发现明显不完整报销单',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '检查只做提示，不会自动修复任何数据。',
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
