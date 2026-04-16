import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class TicketsPage extends ConsumerStatefulWidget {
  const TicketsPage({super.key});

  @override
  ConsumerState<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends ConsumerState<TicketsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(ticketSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketListProvider);
    final recentTicketsAsync = ref.watch(ticketRecentListProvider);
    final searchQuery = ref.watch(ticketSearchQueryProvider);
    final selectedStatus = ref.watch(ticketStatusFilterProvider);
    final selectedType = ref.watch(ticketTypeFilterProvider);
    final selectedMonth = ref.watch(ticketMonthFilterProvider);
    final hasFilters =
        selectedStatus != null || selectedType != null || selectedMonth != null;
    final hasSearchOrFilter = ref.watch(ticketHasSearchOrFilterProvider);
    final shouldShowResults = ref.watch(ticketArchiveResultsVisibleProvider);
    final isShowingAll = ref.watch(ticketShowAllProvider) && !hasSearchOrFilter;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ticketListProvider);
        ref.invalidate(ticketRecentListProvider);
        if (shouldShowResults) {
          await ref.read(ticketListProvider.future);
        } else {
          await ref.read(ticketRecentListProvider.future);
        }
      },
      child: ListView(
        key: const ValueKey('tickets-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _HeaderCard(onAddPressed: () => _openCreatePage(context)),
          const SizedBox(height: 18),
          _ArchiveSearchCard(
            controller: _searchController,
            searchQuery: searchQuery,
            selectedStatus: selectedStatus,
            selectedType: selectedType,
            selectedMonth: selectedMonth,
            hasActiveCriteria: shouldShowResults,
            onSearchChanged: (value) {
              ref.read(ticketSearchQueryProvider.notifier).setQuery(value);
            },
            onSearchCleared: () {
              _searchController.clear();
              ref.read(ticketSearchQueryProvider.notifier).clear();
            },
            onStatusChanged: (value) {
              ref.read(ticketStatusFilterProvider.notifier).setFilter(value);
            },
            onTypeChanged: (value) {
              ref.read(ticketTypeFilterProvider.notifier).setFilter(value);
            },
            onMonthPressed: () => _pickMonth(context, ref, selectedMonth),
            onClearPressed: _clearArchiveCriteria,
          ),
          const SizedBox(height: 18),
          if (!shouldShowResults)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ArchiveGuidanceState(
                  onCreatePressed: () => _openCreatePage(context),
                ),
                const SizedBox(height: 18),
                recentTicketsAsync.when(
                  data: (tickets) => _RecentTicketsSection(
                    tickets: tickets,
                    onViewAllPressed: _showAllTickets,
                    onCreatePressed: () => _openCreatePage(context),
                    onTicketPressed: (ticketId) =>
                        _openDetailPage(context, ticketId),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) {
                    return _ErrorState(
                      onRetryPressed: () =>
                          ref.invalidate(ticketRecentListProvider),
                    );
                  },
                ),
              ],
            )
          else
            ticketsAsync.when(
              data: (tickets) {
                if (tickets.isEmpty) {
                  return _EmptyState(
                    hasSearchOrFilter: hasSearchOrFilter,
                    onCreatePressed: () => _openCreatePage(context),
                    onResetPressed: _clearArchiveCriteria,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      count: tickets.length,
                      searchQuery: searchQuery.trim(),
                      hasFilters: hasFilters,
                      isShowingAll: isShowingAll,
                    ),
                    const SizedBox(height: 14),
                    for (final ticket in tickets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TicketCard(
                          ticket: ticket,
                          onTap: () => _openDetailPage(context, ticket.id),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) {
                return _ErrorState(
                  onRetryPressed: () => ref.invalidate(ticketListProvider),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAllTickets() {
    FocusScope.of(context).unfocus();
    ref.read(ticketShowAllProvider.notifier).showAll();
  }

  void _clearArchiveCriteria() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    ref.read(ticketSearchQueryProvider.notifier).clear();
    ref.read(ticketStatusFilterProvider.notifier).setFilter(null);
    ref.read(ticketTypeFilterProvider.notifier).setFilter(null);
    ref.read(ticketMonthFilterProvider.notifier).setFilter(null);
    ref.read(ticketShowAllProvider.notifier).hide();
  }

  Future<void> _openCreatePage(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TicketFormPage()),
    );
  }

  Future<void> _openDetailPage(BuildContext context, int ticketId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailPage(ticketId: ticketId),
      ),
    );
  }

  Future<void> _pickMonth(
    BuildContext context,
    WidgetRef ref,
    DateTime? currentMonth,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: currentMonth ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '选择月份',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (pickedDate == null) {
      return;
    }

    ref
        .read(ticketMonthFilterProvider.notifier)
        .setFilter(normalizeTicketMonth(pickedDate));
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.onAddPressed});

  final VoidCallback onAddPressed;

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
              const Expanded(
                child: AppSectionHeader(
                  title: '票据归档',
                  subtitle: '搜索优先，默认只展示最近票据。',
                ),
              ),
              const SizedBox(width: 12),
              _PageIconBadge(icon: Icons.inventory_2_rounded),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add),
            label: const Text('新增票据'),
          ),
          const SizedBox(height: 10),
          Text(
            '所有票据都归档在这里，先找，再看。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ArchiveSearchCard extends StatelessWidget {
  const _ArchiveSearchCard({
    required this.controller,
    required this.searchQuery,
    required this.selectedStatus,
    required this.selectedType,
    required this.selectedMonth,
    required this.hasActiveCriteria,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onMonthPressed,
    required this.onClearPressed,
  });

  final TextEditingController controller;
  final String searchQuery;
  final String? selectedStatus;
  final String? selectedType;
  final DateTime? selectedMonth;
  final bool hasActiveCriteria;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onMonthPressed;
  final VoidCallback onClearPressed;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: '搜索归档',
            subtitle: '搜索标题、备注或附件名，再按条件缩小范围。',
            trailing: hasActiveCriteria
                ? TextButton(onPressed: onClearPressed, child: const Text('清空'))
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('ticket-archive-search-input'),
            controller: controller,
            decoration: InputDecoration(
              labelText: '搜索票据',
              hintText: '输入标题、备注或附件名',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: onSearchCleared,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: '清空搜索',
                    ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final statusField = DropdownButtonFormField<String?>(
                key: ValueKey(
                  'ticket-status-filter-${selectedStatus ?? 'all'}',
                ),
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: '状态'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部状态'),
                  ),
                  for (final option in ticketStatusOptions)
                    DropdownMenuItem<String?>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                onChanged: onStatusChanged,
              );
              final typeField = DropdownButtonFormField<String?>(
                key: ValueKey('ticket-type-filter-${selectedType ?? 'all'}'),
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: '类型'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部类型'),
                  ),
                  for (final option in ticketTypeOptions)
                    DropdownMenuItem<String?>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                onChanged: onTypeChanged,
              );

              if (compact) {
                return Column(
                  children: [
                    statusField,
                    const SizedBox(height: 12),
                    typeField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: statusField),
                  const SizedBox(width: 12),
                  Expanded(child: typeField),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onMonthPressed,
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(
              selectedMonth == null
                  ? '全部月份'
                  : '月份：${formatTicketMonth(selectedMonth!)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveGuidanceState extends StatelessWidget {
  const _ArchiveGuidanceState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      color: colors.secondaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: '先搜索，再看结果',
            subtitle: '输入关键词，或先筛选状态、类型、月份。',
            trailing: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.manage_search_rounded, color: colors.primary),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onCreatePressed,
            icon: const Icon(Icons.add),
            label: const Text('新增票据'),
          ),
        ],
      ),
    );
  }
}

class _RecentTicketsSection extends StatelessWidget {
  const _RecentTicketsSection({
    required this.tickets,
    required this.onViewAllPressed,
    required this.onCreatePressed,
    required this.onTicketPressed,
  });

  final List<Ticket> tickets;
  final VoidCallback onViewAllPressed;
  final VoidCallback onCreatePressed;
  final ValueChanged<int> onTicketPressed;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return _EmptyState(
        hasSearchOrFilter: false,
        onCreatePressed: onCreatePressed,
        onResetPressed: onViewAllPressed,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '最近 3 张票据',
          subtitle: '默认仅显示最近票据。',
          trailing: TextButton(
            key: const ValueKey('ticket-view-all-button'),
            onPressed: onViewAllPressed,
            child: const Text('查看全部票据'),
          ),
        ),
        const SizedBox(height: 14),
        for (final ticket in tickets)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TicketCard(
              ticket: ticket,
              onTap: () => onTicketPressed(ticket.id),
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.count,
    required this.searchQuery,
    required this.hasFilters,
    required this.isShowingAll,
  });

  final int count;
  final String searchQuery;
  final bool hasFilters;
  final bool isShowingAll;

  @override
  Widget build(BuildContext context) {
    final title = isShowingAll ? '全部票据 $count 张' : '找到 $count 张票据';
    final summary = _buildSummary();

    return AppSectionHeader(title: title, subtitle: summary);
  }

  String? _buildSummary() {
    final parts = <String>[];

    if (searchQuery.isNotEmpty) {
      parts.add('关键词：$searchQuery');
    }
    if (hasFilters) {
      parts.add('已筛选');
    }
    if (isShowingAll) {
      parts.add('全部归档');
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' · ');
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = (ticket.note ?? '').trim();
    final hasAttachment =
        (ticket.filePath ?? '').trim().isNotEmpty ||
        (ticket.fileName ?? '').trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0B1F33),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                          const SizedBox(height: 4),
                          Text(
                            note.isEmpty
                                ? formatTicketDate(ticket.occurredOn)
                                : '${formatTicketDate(ticket.occurredOn)} · $note',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatTicketAmount(ticket.amountInCents),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(ticketTypeLabel(ticket.type))),
                    Chip(label: Text(ticketStatusLabel(ticket.status))),
                    if (hasAttachment)
                      Chip(
                        avatar: const Icon(Icons.attach_file_rounded, size: 16),
                        label: const Text('已附附件'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearchOrFilter,
    required this.onCreatePressed,
    required this.onResetPressed,
  });

  final bool hasSearchOrFilter;
  final VoidCallback onCreatePressed;
  final VoidCallback onResetPressed;

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
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              hasSearchOrFilter
                  ? Icons.filter_alt_off_outlined
                  : Icons.receipt_long_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasSearchOrFilter ? '未找到匹配票据' : '还没有票据',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearchOrFilter ? '换个关键词或筛选条件试试。' : '先新增一张票据。',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: hasSearchOrFilter ? onResetPressed : onCreatePressed,
            icon: Icon(hasSearchOrFilter ? Icons.close_rounded : Icons.add),
            label: Text(hasSearchOrFilter ? '清空条件' : '新增第一张票据'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetryPressed});

  final VoidCallback onRetryPressed;

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
            '加载票据失败',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '请重试。',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetryPressed, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

class _PageIconBadge extends StatelessWidget {
  const _PageIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: colors.onSecondaryContainer),
    );
  }
}
