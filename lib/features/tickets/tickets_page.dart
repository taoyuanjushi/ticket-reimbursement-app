import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_support.dart';
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
    final sortField = ref.watch(ticketSortFieldProvider);
    final sortDirection = ref.watch(ticketSortDirectionProvider);
    final selectionState = ref.watch(ticketSelectionProvider);
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
          _HeaderCard(
            onAddPressed: () => _openCreatePage(context),
            onSelectionModePressed: selectionState.enabled
                ? _exitSelectionMode
                : _enterSelectionMode,
            isSelectionMode: selectionState.enabled,
          ),
          const SizedBox(height: 18),
          _ArchiveSearchCard(
            controller: _searchController,
            searchQuery: searchQuery,
            selectedStatus: selectedStatus,
            selectedType: selectedType,
            selectedMonth: selectedMonth,
            selectedSortField: sortField,
            selectedSortDirection: sortDirection,
            hasActiveCriteria: shouldShowResults,
            onSearchChanged: _updateSearchQuery,
            onSearchCleared: _clearSearchQuery,
            onStatusChanged: _updateStatusFilter,
            onTypeChanged: _updateTypeFilter,
            onSortFieldChanged: _updateSortField,
            onSortDirectionChanged: _updateSortDirection,
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
                    sortField: sortField,
                    sortDirection: sortDirection,
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
                final children = <Widget>[
                  if (selectionState.enabled) ...[
                    _MultiSelectActionCard(
                      selectedCount: selectionState.selectedCount,
                      hasSelection: selectionState.hasSelection,
                      onCancelPressed: _exitSelectionMode,
                      onUpdateStatusPressed: _openBatchStatusSheet,
                      onAddToSheetPressed: _openBatchAddSheet,
                      onDeletePressed: _deleteSelectedTickets,
                    ),
                    const SizedBox(height: 18),
                  ],
                ];

                if (tickets.isEmpty) {
                  children.add(
                    _EmptyState(
                      hasSearchOrFilter: hasSearchOrFilter,
                      onCreatePressed: () => _openCreatePage(context),
                      onResetPressed: _clearArchiveCriteria,
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  );
                }

                children.add(
                  _SectionHeader(
                    count: tickets.length,
                    searchQuery: searchQuery.trim(),
                    hasFilters: hasFilters,
                    isShowingAll: isShowingAll,
                    sortField: sortField,
                    sortDirection: sortDirection,
                  ),
                );
                children.add(const SizedBox(height: 14));
                for (final ticket in tickets) {
                  children.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TicketCard(
                        ticket: ticket,
                        isSelectionMode: selectionState.enabled,
                        isSelected: selectionState.isSelected(ticket.id),
                        onTap: () => selectionState.enabled
                            ? _toggleSelection(ticket.id)
                            : _openDetailPage(context, ticket.id),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                );
              },
              loading: () => Column(
                children: [
                  if (selectionState.enabled) ...[
                    _MultiSelectActionCard(
                      selectedCount: selectionState.selectedCount,
                      hasSelection: selectionState.hasSelection,
                      onCancelPressed: _exitSelectionMode,
                      onUpdateStatusPressed: _openBatchStatusSheet,
                      onAddToSheetPressed: _openBatchAddSheet,
                      onDeletePressed: _deleteSelectedTickets,
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
              ),
              error: (error, stackTrace) {
                return Column(
                  children: [
                    if (selectionState.enabled) ...[
                      _MultiSelectActionCard(
                        selectedCount: selectionState.selectedCount,
                        hasSelection: selectionState.hasSelection,
                        onCancelPressed: _exitSelectionMode,
                        onUpdateStatusPressed: _openBatchStatusSheet,
                        onAddToSheetPressed: _openBatchAddSheet,
                        onDeletePressed: _deleteSelectedTickets,
                      ),
                      const SizedBox(height: 18),
                    ],
                    _ErrorState(
                      onRetryPressed: () => ref.invalidate(ticketListProvider),
                    ),
                  ],
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

  void _enterSelectionMode() {
    FocusScope.of(context).unfocus();
    ref.read(ticketShowAllProvider.notifier).showAll();
    ref.read(ticketSelectionProvider.notifier).start();
  }

  void _exitSelectionMode() {
    FocusScope.of(context).unfocus();
    ref.read(ticketSelectionProvider.notifier).stop();
  }

  void _toggleSelection(int ticketId) {
    ref.read(ticketSelectionProvider.notifier).toggle(ticketId);
  }

  void _clearSelectedForCriteriaChange() {
    if (!ref.read(ticketSelectionProvider).enabled) {
      return;
    }

    ref.read(ticketSelectionProvider.notifier).clearSelected();
  }

  void _updateSearchQuery(String value) {
    _clearSelectedForCriteriaChange();
    ref.read(ticketSearchQueryProvider.notifier).setQuery(value);
  }

  void _clearSearchQuery() {
    _clearSelectedForCriteriaChange();
    _searchController.clear();
    ref.read(ticketSearchQueryProvider.notifier).clear();
  }

  void _updateStatusFilter(String? value) {
    _clearSelectedForCriteriaChange();
    ref.read(ticketStatusFilterProvider.notifier).setFilter(value);
  }

  void _updateTypeFilter(String? value) {
    _clearSelectedForCriteriaChange();
    ref.read(ticketTypeFilterProvider.notifier).setFilter(value);
  }

  void _updateSortField(TicketSortField? value) {
    if (value == null) {
      return;
    }

    _clearSelectedForCriteriaChange();
    ref.read(ticketSortFieldProvider.notifier).setField(value);
  }

  void _updateSortDirection(TicketSortDirection? value) {
    if (value == null) {
      return;
    }

    _clearSelectedForCriteriaChange();
    ref.read(ticketSortDirectionProvider.notifier).setDirection(value);
  }

  void _clearArchiveCriteria() {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    _clearSelectedForCriteriaChange();
    ref.read(ticketSearchQueryProvider.notifier).clear();
    ref.read(ticketStatusFilterProvider.notifier).setFilter(null);
    ref.read(ticketTypeFilterProvider.notifier).setFilter(null);
    ref.read(ticketMonthFilterProvider.notifier).setFilter(null);
    if (!ref.read(ticketSelectionProvider).enabled) {
      ref.read(ticketShowAllProvider.notifier).hide();
    }
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

    _clearSelectedForCriteriaChange();
    ref
        .read(ticketMonthFilterProvider.notifier)
        .setFilter(normalizeTicketMonth(pickedDate));
  }

  Future<void> _openBatchAddSheet() async {
    final selectedIds = ref.read(ticketSelectionProvider).selectedIds;
    if (selectedIds.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _BatchAttachSheet(
          selectedCount: selectedIds.length,
          onSheetSelected: (sheet) => _attachSelectedTickets(sheet),
        );
      },
    );
  }

  Future<void> _openBatchStatusSheet() async {
    final selectedIds = ref.read(ticketSelectionProvider).selectedIds;
    if (selectedIds.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _BatchStatusSheet(
          selectedCount: selectedIds.length,
          onStatusSelected: (status) => _updateSelectedTicketStatus(status),
        );
      },
    );
  }

  Future<void> _attachSelectedTickets(ReimbursementSheet sheet) async {
    final selectedIds = ref.read(ticketSelectionProvider).selectedIds.toList();
    if (selectedIds.isEmpty) {
      return;
    }

    try {
      final selectedTickets = await ref
          .read(ticketRepositoryProvider)
          .getTicketsByIds(selectedIds);
      final affectedSheetIds = {
        sheet.id,
        ...selectedTickets.map((ticket) => ticket.reimbursementSheetId),
      }.whereType<int>().toSet();

      await ref
          .read(reimbursementRepositoryProvider)
          .attachTicketsToReimbursementSheet(
            ticketIds: selectedIds,
            reimbursementSheetId: sheet.id,
          );

      ref.invalidate(ticketListProvider);
      ref.invalidate(ticketRecentListProvider);
      ref.invalidate(reimbursementAvailableTicketsProvider);
      for (final sheetId in affectedSheetIds) {
        ref.invalidate(reimbursementLinkedTicketsProvider(sheetId));
      }
      ref.read(ticketSelectionProvider.notifier).clearSelected();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 ${selectedIds.length} 张票据加入报销单')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('加入报销单失败，请稍后重试')));
    }
  }

  Future<void> _updateSelectedTicketStatus(String status) async {
    final selectedIds = ref.read(ticketSelectionProvider).selectedIds.toList();
    if (selectedIds.isEmpty) {
      return;
    }

    try {
      await ref
          .read(ticketRepositoryProvider)
          .updateTicketStatuses(ticketIds: selectedIds, status: status);

      ref.invalidate(ticketListProvider);
      ref.invalidate(ticketRecentListProvider);
      for (final ticketId in selectedIds) {
        ref.invalidate(ticketByIdProvider(ticketId));
      }
      ref.read(ticketSelectionProvider.notifier).clearSelected();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已将 ${selectedIds.length} 张票据改为${ticketStatusLabel(status)}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('批量修改状态失败，请稍后重试')));
    }
  }

  Future<void> _deleteSelectedTickets() async {
    final selectedIds = ref.read(ticketSelectionProvider).selectedIds.toList();
    if (selectedIds.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('批量删除票据'),
          content: Text('已选 ${selectedIds.length} 张票据，删除后本地附件也会一起移除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      final selectedTickets = await ref
          .read(ticketRepositoryProvider)
          .getTicketsByIds(selectedIds);
      await ref.read(ticketRepositoryProvider).deleteTickets(selectedIds);

      final fileService = ref.read(ticketFileServiceProvider);
      for (final ticket in selectedTickets) {
        await fileService.deleteStoredFile(ticket.filePath);
      }

      ref.invalidate(ticketListProvider);
      ref.invalidate(ticketRecentListProvider);
      ref.invalidate(reimbursementAvailableTicketsProvider);
      for (final sheetId
          in selectedTickets
              .map((ticket) => ticket.reimbursementSheetId)
              .whereType<int>()
              .toSet()) {
        ref.invalidate(reimbursementLinkedTicketsProvider(sheetId));
      }
      ref.read(ticketSelectionProvider.notifier).clearSelected();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${selectedIds.length} 张票据')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('批量删除失败，请稍后重试')));
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.onAddPressed,
    required this.onSelectionModePressed,
    required this.isSelectionMode,
  });

  final VoidCallback onAddPressed;
  final VoidCallback onSelectionModePressed;
  final bool isSelectionMode;

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
              const _PageIconBadge(icon: Icons.inventory_2_rounded),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add),
                label: const Text('新增票据'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('ticket-multi-select-button'),
                onPressed: onSelectionModePressed,
                icon: Icon(
                  isSelectionMode
                      ? Icons.close_rounded
                      : Icons.checklist_rounded,
                ),
                label: Text(isSelectionMode ? '取消选择' : '批量选择'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '所有票据都归档在这里，先找，再批量处理。',
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
    required this.selectedSortField,
    required this.selectedSortDirection,
    required this.hasActiveCriteria,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
    required this.onMonthPressed,
    required this.onClearPressed,
  });

  final TextEditingController controller;
  final String searchQuery;
  final String? selectedStatus;
  final String? selectedType;
  final DateTime? selectedMonth;
  final TicketSortField selectedSortField;
  final TicketSortDirection selectedSortDirection;
  final bool hasActiveCriteria;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<TicketSortField?> onSortFieldChanged;
  final ValueChanged<TicketSortDirection?> onSortDirectionChanged;
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
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final sortFieldInput = DropdownButtonFormField<TicketSortField>(
                key: const ValueKey('ticket-sort-field-input'),
                initialValue: selectedSortField,
                decoration: const InputDecoration(labelText: '排序方式'),
                items: [
                  for (final option in ticketSortFieldOptions)
                    DropdownMenuItem<TicketSortField>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                onChanged: onSortFieldChanged,
              );
              final sortDirectionInput =
                  DropdownButtonFormField<TicketSortDirection>(
                    key: const ValueKey('ticket-sort-direction-input'),
                    initialValue: selectedSortDirection,
                    decoration: const InputDecoration(labelText: '排序方向'),
                    items: [
                      for (final option in ticketSortDirectionOptions)
                        DropdownMenuItem<TicketSortDirection>(
                          value: option.value,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: onSortDirectionChanged,
                  );

              if (compact) {
                return Column(
                  children: [
                    sortFieldInput,
                    const SizedBox(height: 12),
                    sortDirectionInput,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: sortFieldInput),
                  const SizedBox(width: 12),
                  Expanded(child: sortDirectionInput),
                ],
              );
            },
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
    required this.sortField,
    required this.sortDirection,
    required this.onViewAllPressed,
    required this.onCreatePressed,
    required this.onTicketPressed,
  });

  final List<Ticket> tickets;
  final TicketSortField sortField;
  final TicketSortDirection sortDirection;
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

    final defaultSort = isDefaultTicketSort(sortField, sortDirection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: defaultSort ? '最近 3 张票据' : '当前排序前 3 张票据',
          subtitle: defaultSort
              ? '默认仅显示最近票据。'
              : '已按${ticketSortFieldLabel(sortField)} · ${ticketSortDirectionLabel(sortDirection)}',
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
              isSelectionMode: false,
              isSelected: false,
              onTap: () => onTicketPressed(ticket.id),
            ),
          ),
      ],
    );
  }
}

class _MultiSelectActionCard extends StatelessWidget {
  const _MultiSelectActionCard({
    required this.selectedCount,
    required this.hasSelection,
    required this.onCancelPressed,
    required this.onUpdateStatusPressed,
    required this.onAddToSheetPressed,
    required this.onDeletePressed,
  });

  final int selectedCount;
  final bool hasSelection;
  final VoidCallback onCancelPressed;
  final Future<void> Function() onUpdateStatusPressed;
  final Future<void> Function() onAddToSheetPressed;
  final Future<void> Function() onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppSurfaceCard(
      color: colors.primaryContainer.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: '已选 $selectedCount 张票据',
            subtitle: '可批量修改状态、加入报销单或删除',
            trailing: TextButton(
              onPressed: onCancelPressed,
              child: const Text('取消选择'),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('ticket-batch-status-button'),
                onPressed: hasSelection ? onUpdateStatusPressed : null,
                icon: const Icon(Icons.sync_alt_rounded),
                label: const Text('批量修改状态'),
              ),
              FilledButton.icon(
                key: const ValueKey('ticket-batch-add-button'),
                onPressed: hasSelection ? onAddToSheetPressed : null,
                icon: const Icon(Icons.link_rounded),
                label: const Text('加入报销单'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('ticket-batch-delete-button'),
                onPressed: hasSelection ? onDeletePressed : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.25)),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.count,
    required this.searchQuery,
    required this.hasFilters,
    required this.isShowingAll,
    required this.sortField,
    required this.sortDirection,
  });

  final int count;
  final String searchQuery;
  final bool hasFilters;
  final bool isShowingAll;
  final TicketSortField sortField;
  final TicketSortDirection sortDirection;

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
    parts.add(
      '排序：${ticketSortFieldLabel(sortField)} · ${ticketSortDirectionLabel(sortDirection)}',
    );

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' · ');
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
  });

  final Ticket ticket;
  final bool isSelectionMode;
  final bool isSelected;
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
        key: ValueKey('ticket-card-${ticket.id}'),
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primaryContainer.withValues(alpha: 0.5)
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected ? colors.primary : colors.outlineVariant,
              width: isSelected ? 1.4 : 1,
            ),
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
                        isSelectionMode && isSelected
                            ? Icons.check_circle_rounded
                            : Icons.receipt_long_rounded,
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
                          isSelectionMode
                              ? (isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded)
                              : Icons.chevron_right_rounded,
                          color: isSelectionMode && isSelected
                              ? colors.primary
                              : colors.onSurfaceVariant,
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

class _BatchStatusSheet extends StatelessWidget {
  const _BatchStatusSheet({
    required this.selectedCount,
    required this.onStatusSelected,
  });

  final int selectedCount;
  final Future<void> Function(String status) onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.56,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                title: '批量修改状态',
                subtitle: '已选 $selectedCount 张票据',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: ticketStatusOptions.length,
                  itemBuilder: (context, index) {
                    final option = ticketStatusOptions[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TicketStatusOptionCard(
                        option: option,
                        onTap: () => onStatusSelected(option.value),
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

class _TicketStatusOptionCard extends StatelessWidget {
  const _TicketStatusOptionCard({required this.option, required this.onTap});

  final TicketSelectOption option;
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.flag_outlined, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: onTap, child: const Text('应用')),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchAttachSheet extends ConsumerWidget {
  const _BatchAttachSheet({
    required this.selectedCount,
    required this.onSheetSelected,
  });

  final int selectedCount;
  final Future<void> Function(ReimbursementSheet sheet) onSheetSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetsAsync = ref.watch(reimbursementListProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: sheetsAsync.when(
            data: (sheets) {
              if (sheets.isEmpty) {
                return Center(
                  child: AppSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text('还没有报销单'),
                        const SizedBox(height: 8),
                        const Text('请先新增报销单。', textAlign: TextAlign.center),
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
                  AppSectionHeader(
                    title: '加入报销单',
                    subtitle: '已选 $selectedCount 张票据',
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sheets.length,
                      itemBuilder: (context, index) {
                        final sheet = sheets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ReimbursementOptionCard(
                            sheet: sheet,
                            onTap: () => onSheetSelected(sheet),
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
                      const Text('加载报销单失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(reimbursementListProvider),
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
}

class _ReimbursementOptionCard extends StatelessWidget {
  const _ReimbursementOptionCard({required this.sheet, required this.onTap});

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
                      sheet.title,
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
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: onTap, child: const Text('加入')),
            ],
          ),
        ),
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
