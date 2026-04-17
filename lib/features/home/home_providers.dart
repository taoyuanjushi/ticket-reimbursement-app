import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';

class HomeWorkbenchData {
  const HomeWorkbenchData({
    required this.ticketCount,
    required this.pendingTicketCount,
    required this.reimbursementSheetCount,
    required this.recentTickets,
    required this.recentReimbursementSheets,
  });

  final int ticketCount;
  final int pendingTicketCount;
  final int reimbursementSheetCount;
  final List<Ticket> recentTickets;
  final List<ReimbursementSheet> recentReimbursementSheets;
}

final homeWorkbenchProvider = FutureProvider.autoDispose<HomeWorkbenchData>((
  ref,
) async {
  final ticketRepository = ref.watch(ticketRepositoryProvider);
  final reimbursementRepository = ref.watch(reimbursementRepositoryProvider);

  final ticketsFuture = ticketRepository.listTickets();
  final pendingTicketsFuture = ticketRepository.filterTickets(
    status: 'pending',
  );
  final reimbursementSheetsFuture = reimbursementRepository
      .listReimbursementSheets();

  final tickets = await ticketsFuture;
  final pendingTickets = await pendingTicketsFuture;
  final reimbursementSheets = await reimbursementSheetsFuture;

  return HomeWorkbenchData(
    ticketCount: tickets.length,
    pendingTicketCount: pendingTickets.length,
    reimbursementSheetCount: reimbursementSheets.length,
    recentTickets: tickets.take(3).toList(growable: false),
    recentReimbursementSheets: reimbursementSheets
        .take(3)
        .toList(growable: false),
  );
});
