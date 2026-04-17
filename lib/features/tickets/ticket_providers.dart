import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

final ticketStatusFilterProvider =
    NotifierProvider<TicketStatusFilterNotifier, String?>(
      TicketStatusFilterNotifier.new,
    );

final ticketTypeFilterProvider =
    NotifierProvider<TicketTypeFilterNotifier, String?>(
      TicketTypeFilterNotifier.new,
    );

final ticketMonthFilterProvider =
    NotifierProvider<TicketMonthFilterNotifier, DateTime?>(
      TicketMonthFilterNotifier.new,
    );

final ticketSearchQueryProvider =
    NotifierProvider<TicketSearchQueryNotifier, String>(
      TicketSearchQueryNotifier.new,
    );

final ticketShowAllProvider = NotifierProvider<TicketShowAllNotifier, bool>(
  TicketShowAllNotifier.new,
);

final ticketSortFieldProvider =
    NotifierProvider<TicketSortFieldNotifier, TicketSortField>(
      TicketSortFieldNotifier.new,
    );

final ticketSortDirectionProvider =
    NotifierProvider<TicketSortDirectionNotifier, TicketSortDirection>(
      TicketSortDirectionNotifier.new,
    );

final ticketSelectionProvider =
    NotifierProvider<TicketSelectionNotifier, TicketSelectionState>(
      TicketSelectionNotifier.new,
    );

final ticketHasSearchOrFilterProvider = Provider<bool>((ref) {
  final query = ref.watch(ticketSearchQueryProvider).trim();
  final status = ref.watch(ticketStatusFilterProvider);
  final type = ref.watch(ticketTypeFilterProvider);
  final month = ref.watch(ticketMonthFilterProvider);

  return query.isNotEmpty || status != null || type != null || month != null;
});

final ticketArchiveResultsVisibleProvider = Provider<bool>((ref) {
  final hasSearchOrFilter = ref.watch(ticketHasSearchOrFilterProvider);
  final showAll = ref.watch(ticketShowAllProvider);
  final selectionEnabled = ref.watch(ticketSelectionProvider).enabled;

  return hasSearchOrFilter || showAll || selectionEnabled;
});

final ticketRecentListProvider = FutureProvider<List<Ticket>>((ref) async {
  final sortField = ref.watch(ticketSortFieldProvider);
  final sortDirection = ref.watch(ticketSortDirectionProvider);
  final tickets = await ref
      .watch(ticketRepositoryProvider)
      .listTickets(sortField: sortField, sortDirection: sortDirection);
  return tickets.take(3).toList(growable: false);
});

final ticketListProvider = FutureProvider<List<Ticket>>((ref) {
  final repository = ref.watch(ticketRepositoryProvider);
  final query = ref.watch(ticketSearchQueryProvider).trim();
  final status = ref.watch(ticketStatusFilterProvider);
  final type = ref.watch(ticketTypeFilterProvider);
  final month = ref.watch(ticketMonthFilterProvider);
  final sortField = ref.watch(ticketSortFieldProvider);
  final sortDirection = ref.watch(ticketSortDirectionProvider);
  final shouldShowResults = ref.watch(ticketArchiveResultsVisibleProvider);

  if (!shouldShowResults) {
    return const [];
  }

  return repository.filterTickets(
    status: status,
    type: type,
    month: month,
    keyword: query.isEmpty ? null : query,
    sortField: sortField,
    sortDirection: sortDirection,
  );
});

final ticketByIdProvider = FutureProvider.family<Ticket?, int>((ref, id) {
  return ref.watch(ticketRepositoryProvider).getTicketById(id);
});

final ticketFileServiceProvider = Provider<TicketFileService>((ref) {
  return TicketFileService();
});

class TicketStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? value) {
    state = value;
  }
}

class TicketTypeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? value) {
    state = value;
  }
}

class TicketMonthFilterNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setFilter(DateTime? value) {
    state = value;
  }
}

class TicketSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) {
    state = value;
  }

  void clear() {
    state = '';
  }
}

class TicketShowAllNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void showAll() {
    state = true;
  }

  void hide() {
    state = false;
  }
}

class TicketSortFieldNotifier extends Notifier<TicketSortField> {
  @override
  TicketSortField build() => TicketSortField.date;

  void setField(TicketSortField value) {
    state = value;
  }
}

class TicketSortDirectionNotifier extends Notifier<TicketSortDirection> {
  @override
  TicketSortDirection build() => TicketSortDirection.descending;

  void setDirection(TicketSortDirection value) {
    state = value;
  }
}

class TicketSelectionState {
  const TicketSelectionState({
    required this.enabled,
    required this.selectedIds,
  });

  const TicketSelectionState.initial()
    : enabled = false,
      selectedIds = const <int>{};

  final bool enabled;
  final Set<int> selectedIds;

  int get selectedCount => selectedIds.length;

  bool get hasSelection => selectedIds.isNotEmpty;

  bool isSelected(int ticketId) => selectedIds.contains(ticketId);

  TicketSelectionState copyWith({bool? enabled, Set<int>? selectedIds}) {
    return TicketSelectionState(
      enabled: enabled ?? this.enabled,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class TicketSelectionNotifier extends Notifier<TicketSelectionState> {
  @override
  TicketSelectionState build() => const TicketSelectionState.initial();

  void start() {
    if (state.enabled) {
      return;
    }

    state = const TicketSelectionState(enabled: true, selectedIds: <int>{});
  }

  void stop() {
    state = const TicketSelectionState.initial();
  }

  void clearSelected() {
    if (state.selectedIds.isEmpty) {
      return;
    }

    state = state.copyWith(selectedIds: <int>{});
  }

  void toggle(int ticketId) {
    final nextSelectedIds = Set<int>.from(state.selectedIds);
    if (!nextSelectedIds.add(ticketId)) {
      nextSelectedIds.remove(ticketId);
    }

    state = TicketSelectionState(enabled: true, selectedIds: nextSelectedIds);
  }
}
