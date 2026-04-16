import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';

final reimbursementListProvider = FutureProvider<List<ReimbursementSheet>>((
  ref,
) {
  return ref.watch(reimbursementRepositoryProvider).listReimbursementSheets();
});

final reimbursementByIdProvider =
    FutureProvider.family<ReimbursementSheet?, int>((ref, id) {
      return ref
          .watch(reimbursementRepositoryProvider)
          .getReimbursementSheetById(id);
    });

final reimbursementLinkedTicketsProvider =
    FutureProvider.family<List<Ticket>, int>((ref, reimbursementSheetId) {
      return ref
          .watch(reimbursementRepositoryProvider)
          .listLinkedTickets(reimbursementSheetId);
    });

final reimbursementAvailableTicketsProvider = FutureProvider<List<Ticket>>((
  ref,
) {
  return ref.watch(reimbursementRepositoryProvider).listAvailableTickets();
});

final reimbursementCsvExportServiceProvider =
    Provider<ReimbursementCsvExportService>((ref) {
      return ReimbursementCsvExportService();
    });
