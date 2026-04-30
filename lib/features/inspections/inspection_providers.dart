import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/inspections/duplicate_ticket_inspection_service.dart';
import 'package:ticket_box/features/inspections/reimbursement_completeness_inspection_service.dart';
import 'package:ticket_box/features/inspections/ticket_completeness_inspection_service.dart';

final duplicateTicketInspectionServiceProvider =
    Provider<DuplicateTicketInspectionService>((ref) {
      return DuplicateTicketInspectionService(
        ref.watch(ticketRepositoryProvider),
      );
    });

final duplicateTicketInspectionProvider =
    FutureProvider<DuplicateTicketInspectionResult>((ref) {
      return ref.watch(duplicateTicketInspectionServiceProvider).inspect();
    });

final ticketCompletenessInspectionServiceProvider =
    Provider<TicketCompletenessInspectionService>((ref) {
      return TicketCompletenessInspectionService(
        ref.watch(ticketRepositoryProvider),
      );
    });

final ticketCompletenessInspectionProvider =
    FutureProvider<TicketCompletenessInspectionResult>((ref) {
      return ref.watch(ticketCompletenessInspectionServiceProvider).inspect();
    });

final reimbursementCompletenessInspectionServiceProvider =
    Provider<ReimbursementCompletenessInspectionService>((ref) {
      return ReimbursementCompletenessInspectionService(
        ref.watch(reimbursementRepositoryProvider),
      );
    });

final reimbursementCompletenessInspectionProvider =
    FutureProvider<ReimbursementCompletenessInspectionResult>((ref) {
      return ref
          .watch(reimbursementCompletenessInspectionServiceProvider)
          .inspect();
    });
