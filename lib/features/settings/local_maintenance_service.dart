import 'dart:io';

import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';
import 'package:ticket_box/features/reminders/reminder_notification_service.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

class LocalMaintenanceInfo {
  const LocalMaintenanceInfo({
    required this.databasePath,
    required this.attachmentDirectoryPath,
    required this.reimbursementExportDirectoryPath,
    required this.invalidAttachmentCount,
  });

  final String databasePath;
  final String attachmentDirectoryPath;
  final String reimbursementExportDirectoryPath;
  final int invalidAttachmentCount;
}

class LocalMaintenanceService {
  LocalMaintenanceService({
    required TicketRepository ticketRepository,
    required TicketFileService ticketFileService,
    required ReimbursementCsvExportService reimbursementCsvExportService,
    required ReminderNotificationService reminderNotificationService,
    Future<String> Function()? databasePathResolver,
  }) : _ticketRepository = ticketRepository,
       _ticketFileService = ticketFileService,
       _reimbursementCsvExportService = reimbursementCsvExportService,
       _reminderNotificationService = reminderNotificationService,
       _databasePathResolver =
           databasePathResolver ?? AppDatabase.resolveDefaultPath;

  final TicketRepository _ticketRepository;
  final TicketFileService _ticketFileService;
  final ReimbursementCsvExportService _reimbursementCsvExportService;
  final ReminderNotificationService _reminderNotificationService;
  final Future<String> Function() _databasePathResolver;

  Future<LocalMaintenanceInfo> getMaintenanceInfo() async {
    final databasePath = await _databasePathResolver();
    final attachmentDirectory = await _ticketFileService.attachmentsDirectory();
    final exportDirectory = await _reimbursementCsvExportService
        .exportsDirectory();
    final invalidAttachmentTickets = await _loadInvalidAttachmentTickets();

    return LocalMaintenanceInfo(
      databasePath: databasePath,
      attachmentDirectoryPath: attachmentDirectory.path,
      reimbursementExportDirectoryPath: exportDirectory.path,
      invalidAttachmentCount: invalidAttachmentTickets.length,
    );
  }

  Future<int> clearExportedCsvFiles() {
    return _reimbursementCsvExportService.clearExportedCsvFiles();
  }

  Future<void> cancelAllPendingNotifications() {
    return _reminderNotificationService.cancelAllNotifications();
  }

  Future<int> clearInvalidAttachmentReferences() async {
    final invalidAttachmentTickets = await _loadInvalidAttachmentTickets();
    final invalidTicketIds = invalidAttachmentTickets
        .map((ticket) => ticket.id)
        .toList(growable: false);

    return _ticketRepository.clearAttachmentMetadataForTickets(
      invalidTicketIds,
    );
  }

  Future<List<Ticket>> _loadInvalidAttachmentTickets() async {
    final tickets = await _ticketRepository.listTicketsWithAttachments();
    final invalidTickets = <Ticket>[];

    for (final ticket in tickets) {
      if (await _hasInvalidAttachmentReference(ticket)) {
        invalidTickets.add(ticket);
      }
    }

    return invalidTickets;
  }

  Future<bool> _hasInvalidAttachmentReference(Ticket ticket) async {
    final filePath = ticket.filePath;
    if (filePath == null || filePath.isEmpty) {
      return false;
    }

    try {
      return !await File(filePath).exists();
    } catch (_) {
      return true;
    }
  }
}
