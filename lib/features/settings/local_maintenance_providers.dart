import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/reminders/reminder_providers.dart';
import 'package:ticket_box/features/settings/local_maintenance_service.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';

final localMaintenanceServiceProvider = Provider<LocalMaintenanceService>((
  ref,
) {
  return LocalMaintenanceService(
    ticketRepository: ref.watch(ticketRepositoryProvider),
    ticketFileService: ref.watch(ticketFileServiceProvider),
    reimbursementCsvExportService: ref.watch(
      reimbursementCsvExportServiceProvider,
    ),
    reminderNotificationService: ref.watch(reminderNotificationServiceProvider),
  );
});

final localMaintenanceInfoProvider = FutureProvider<LocalMaintenanceInfo>((
  ref,
) {
  return ref.watch(localMaintenanceServiceProvider).getMaintenanceInfo();
});
