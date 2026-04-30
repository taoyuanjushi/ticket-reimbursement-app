import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/features/inspections/inspection_providers.dart';
import 'package:ticket_box/features/inspections/ticket_completeness_inspection_service.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class TicketCompletenessInspectionPage extends ConsumerWidget {
  const TicketCompletenessInspectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionAsync = ref.watch(ticketCompletenessInspectionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('票据完整性检查')),
      body: SafeArea(
        child: inspectionAsync.when(
          data: (result) => _TicketCompletenessInspectionContent(
            result: result,
            onRefresh: () =>
                ref.invalidate(ticketCompletenessInspectionProvider),
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
                          ticketCompletenessInspectionProvider,
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

class _TicketCompletenessInspectionContent extends StatelessWidget {
  const _TicketCompletenessInspectionContent({
    required this.result,
    required this.onRefresh,
  });

  final TicketCompletenessInspectionResult result;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('ticket-completeness-inspection-page'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        AppSurfaceCard(
          color: const Color(0xFFF8FBF9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: '票据完整性',
                subtitle: '只提示可能问题，不会自动修改票据',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _InspectionSummaryItem(
                      label: '问题票据',
                      value: '${result.incompleteTicketCount}',
                      valueKey: 'incomplete-ticket-count',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InspectionSummaryItem(
                      label: '问题项',
                      value: '${result.totalIssueCount}',
                      valueKey: 'ticket-completeness-issue-count',
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
          const _NoCompletenessIssueState()
        else
          for (final record in result.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _IncompleteTicketCard(record: record),
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

  final Map<TicketCompletenessIssueType, int> counts;

  @override
  Widget build(BuildContext context) {
    final chips = TicketCompletenessIssueType.values
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

  String _issueTypeLabel(TicketCompletenessIssueType type) {
    switch (type) {
      case TicketCompletenessIssueType.emptyTitle:
        return '标题为空';
      case TicketCompletenessIssueType.missingAmount:
        return '金额缺失';
      case TicketCompletenessIssueType.pendingWithoutAttachment:
        return '待报销无附件';
      case TicketCompletenessIssueType.missingAttachmentFile:
        return '附件文件缺失';
    }
  }
}

class _IncompleteTicketCard extends StatelessWidget {
  const _IncompleteTicketCard({required this.record});

  final IncompleteTicketRecord record;

  @override
  Widget build(BuildContext context) {
    final ticket = record.ticket;
    final colors = Theme.of(context).colorScheme;
    final title = ticket.title.trim().isEmpty ? '未命名票据' : ticket.title;
    final needsAttachmentAction =
        _hasIssue(TicketCompletenessIssueType.pendingWithoutAttachment) ||
        _hasIssue(TicketCompletenessIssueType.missingAttachmentFile);

    return AppSurfaceCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        key: ValueKey('incomplete-ticket-${ticket.id}'),
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
                    const SizedBox(height: 8),
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
                        for (final issue in record.issues)
                          Chip(label: Text(issue.label)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _TicketRepairSuggestionBox(
                      suggestions: _buildSuggestions(),
                      onEdit: () => _openEdit(context),
                      onAttach: needsAttachmentAction
                          ? () => _openEdit(context)
                          : null,
                      onDetail: () => _openDetail(context),
                      editKey: ValueKey('ticket-repair-edit-${ticket.id}'),
                      attachmentKey: ValueKey(
                        'ticket-repair-attachment-${ticket.id}',
                      ),
                      detailKey: ValueKey('ticket-repair-detail-${ticket.id}'),
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

  bool _hasIssue(TicketCompletenessIssueType type) {
    return record.issues.any((issue) => issue.type == type);
  }

  List<String> _buildSuggestions() {
    final suggestions = <String>[];

    if (_hasIssue(TicketCompletenessIssueType.emptyTitle)) {
      suggestions.add('补充清晰标题，便于归档和导出。');
    }
    if (_hasIssue(TicketCompletenessIssueType.missingAmount)) {
      suggestions.add('核对金额后补充正确金额。');
    }
    if (_hasIssue(TicketCompletenessIssueType.pendingWithoutAttachment)) {
      suggestions.add('补充图片或 PDF 附件。');
    }
    if (_hasIssue(TicketCompletenessIssueType.missingAttachmentFile)) {
      suggestions.add('重新附加本地文件，或确认附件路径。');
    }

    return suggestions;
  }

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(ticketId: record.ticket.id),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketFormPage(initialTicket: record.ticket),
      ),
    );
  }
}

class _TicketRepairSuggestionBox extends StatelessWidget {
  const _TicketRepairSuggestionBox({
    required this.suggestions,
    required this.onEdit,
    required this.onAttach,
    required this.onDetail,
    required this.editKey,
    required this.attachmentKey,
    required this.detailKey,
  });

  final List<String> suggestions;
  final VoidCallback onEdit;
  final VoidCallback? onAttach;
  final VoidCallback onDetail;
  final Key editKey;
  final Key attachmentKey;
  final Key detailKey;

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
                key: editKey,
                onPressed: onEdit,
                child: const Text('去编辑'),
              ),
              if (onAttach != null)
                OutlinedButton(
                  key: attachmentKey,
                  onPressed: onAttach,
                  child: const Text('补充附件'),
                ),
              TextButton(
                key: detailKey,
                onPressed: onDetail,
                child: const Text('查看详情'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoCompletenessIssueState extends StatelessWidget {
  const _NoCompletenessIssueState();

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
            '暂未发现明显不完整票据',
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
