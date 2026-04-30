import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/inspections/reimbursement_completeness_inspection_service.dart';

void main() {
  test(
    'detects incomplete reimbursement sheets without changing data',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final tempDirectory = await Directory.systemTemp.createTemp(
        'ticket_box_reimbursement_completeness_test',
      );
      addTearDown(database.close);
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final reimbursementRepository = ReimbursementRepository(database);
      final ticketRepository = TicketRepository(database);

      final emptySheetId = await reimbursementRepository
          .createReimbursementSheet(
            ReimbursementSheetsCompanion.insert(
              title: '空报销单',
              status: const Value('draft'),
            ),
          );
      final sheetWithTicketIssuesId = await reimbursementRepository
          .createReimbursementSheet(
            ReimbursementSheetsCompanion.insert(
              title: '差旅报销',
              status: const Value('submitted'),
              description: const Value('差旅材料'),
            ),
          );
      final emptyTitleTicketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '',
          amountInCents: 0,
          occurredOn: DateTime(2026, 4, 15),
          type: 'travel',
          status: 'submitted',
          filePath: Value('${tempDirectory.path}/missing.pdf'),
          fileName: const Value('missing.pdf'),
          fileType: const Value('pdf'),
        ),
      );
      final noAttachmentTicketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '餐饮票据',
          amountInCents: 6800,
          occurredOn: DateTime(2026, 4, 16),
          type: 'meal',
          status: 'submitted',
        ),
      );
      await reimbursementRepository.attachTicketsToReimbursementSheet(
        ticketIds: [emptyTitleTicketId, noAttachmentTicketId],
        reimbursementSheetId: sheetWithTicketIssuesId,
      );

      final service = ReimbursementCompletenessInspectionService(
        reimbursementRepository,
      );
      final result = await service.inspect();

      expect(result.problematicSheetCount, 2);
      expect(result.totalIssueCount, 6);
      expect(
        result.issueCountsByType[ReimbursementCompletenessIssueType
            .noLinkedTickets],
        1,
      );
      expect(
        result.issueCountsByType[ReimbursementCompletenessIssueType
            .linkedTicketWithoutAttachment],
        1,
      );
      expect(
        result.issueCountsByType[ReimbursementCompletenessIssueType
            .linkedTicketMissingAttachmentFile],
        1,
      );
      expect(
        result.issueCountsByType[ReimbursementCompletenessIssueType
            .linkedTicketInvalidAmount],
        1,
      );
      expect(
        result.issueCountsByType[ReimbursementCompletenessIssueType
            .linkedTicketEmptyTitle],
        1,
      );
      expect(
        result.issueCountsByType[ReimbursementCompletenessIssueType.emptyNote],
        1,
      );
      expect(result.records.map((record) => record.sheet.id).toSet(), {
        emptySheetId,
        sheetWithTicketIssuesId,
      });
      final sheetWithTicketIssuesRecord = result.records.singleWhere(
        (record) => record.sheet.id == sheetWithTicketIssuesId,
      );
      expect(
        sheetWithTicketIssuesRecord.problematicTickets
            .map((ticket) => ticket.id)
            .toSet(),
        {emptyTitleTicketId, noAttachmentTicketId},
      );
      expect(
        (await reimbursementRepository.listReimbursementSheets()).length,
        2,
      );
    },
  );
}
