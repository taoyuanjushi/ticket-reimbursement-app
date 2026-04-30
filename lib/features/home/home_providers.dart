import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';

final homeCurrentDateProvider = Provider<DateTime>((ref) => DateTime.now());

enum HomeDashboardRange { currentMonth, previousMonth, all }

String homeDashboardRangeLabel(HomeDashboardRange range) {
  switch (range) {
    case HomeDashboardRange.currentMonth:
      return '本月';
    case HomeDashboardRange.previousMonth:
      return '上月';
    case HomeDashboardRange.all:
      return '全部';
  }
}

final homeDashboardRangeProvider =
    NotifierProvider<HomeDashboardRangeNotifier, HomeDashboardRange>(
      HomeDashboardRangeNotifier.new,
    );

class HomeWorkbenchData {
  const HomeWorkbenchData({
    required this.ticketCount,
    required this.ticketAmountInCents,
    required this.pendingTicketCount,
    required this.pendingTicketAmountInCents,
    required this.reimbursementSheetCount,
    required this.recentTickets,
    required this.recentReimbursementSheets,
  });

  final int ticketCount;
  final int ticketAmountInCents;
  final int pendingTicketCount;
  final int pendingTicketAmountInCents;
  final int reimbursementSheetCount;
  final List<Ticket> recentTickets;
  final List<ReimbursementSheet> recentReimbursementSheets;
}

final homeWorkbenchProvider = FutureProvider.autoDispose<HomeWorkbenchData>((
  ref,
) async {
  final ticketRepository = ref.watch(ticketRepositoryProvider);
  final reimbursementRepository = ref.watch(reimbursementRepositoryProvider);
  final currentDate = ref.watch(homeCurrentDateProvider);
  final selectedRange = ref.watch(homeDashboardRangeProvider);
  final selectedMonth = _resolveRangeMonth(selectedRange, currentDate);

  final recentTicketsFuture = ticketRepository.listTickets();
  final reimbursementSheetsFuture = reimbursementRepository
      .listReimbursementSheets();
  final rangeTicketsFuture = selectedMonth == null
      ? ticketRepository.listTickets()
      : ticketRepository.filterTickets(month: selectedMonth);
  final pendingTicketsFuture = ticketRepository.filterTickets(
    status: 'pending',
    month: selectedMonth,
  );

  final recentTickets = await recentTicketsFuture;
  final rangeTickets = await rangeTicketsFuture;
  final pendingTickets = await pendingTicketsFuture;
  final reimbursementSheets = await reimbursementSheetsFuture;

  return HomeWorkbenchData(
    ticketCount: rangeTickets.length,
    ticketAmountInCents: _sumTicketAmounts(rangeTickets),
    pendingTicketCount: pendingTickets.length,
    pendingTicketAmountInCents: _sumTicketAmounts(pendingTickets),
    reimbursementSheetCount: reimbursementSheets.length,
    recentTickets: recentTickets.take(3).toList(growable: false),
    recentReimbursementSheets: reimbursementSheets
        .take(3)
        .toList(growable: false),
  );
});

class HomeDashboardRangeNotifier extends Notifier<HomeDashboardRange> {
  @override
  HomeDashboardRange build() => HomeDashboardRange.currentMonth;

  void setRange(HomeDashboardRange range) {
    state = range;
  }
}

DateTime? _resolveRangeMonth(HomeDashboardRange range, DateTime currentDate) {
  switch (range) {
    case HomeDashboardRange.currentMonth:
      return DateTime(currentDate.year, currentDate.month);
    case HomeDashboardRange.previousMonth:
      return DateTime(currentDate.year, currentDate.month - 1);
    case HomeDashboardRange.all:
      return null;
  }
}

int _sumTicketAmounts(List<Ticket> tickets) {
  return tickets.fold<int>(
    0,
    (totalAmount, ticket) => totalAmount + ticket.amountInCents,
  );
}
