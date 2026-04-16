import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
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

  return hasSearchOrFilter || showAll;
});

final ticketRecentListProvider = FutureProvider<List<Ticket>>((ref) async {
  final tickets = await ref.watch(ticketRepositoryProvider).listTickets();
  return tickets.take(3).toList(growable: false);
});

final ticketListProvider = FutureProvider<List<Ticket>>((ref) {
  final repository = ref.watch(ticketRepositoryProvider);
  final query = ref.watch(ticketSearchQueryProvider).trim();
  final status = ref.watch(ticketStatusFilterProvider);
  final type = ref.watch(ticketTypeFilterProvider);
  final month = ref.watch(ticketMonthFilterProvider);
  final shouldShowResults = ref.watch(ticketArchiveResultsVisibleProvider);

  if (!shouldShowResults) {
    return const [];
  }

  return repository.filterTickets(
    status: status,
    type: type,
    month: month,
    keyword: query.isEmpty ? null : query,
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
