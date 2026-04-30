import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';

void main() {
  test(
    'soft delete moves reimbursement sheets to trash without unlinking tickets',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final ticketRepository = TicketRepository(database);
      final reimbursementRepository = ReimbursementRepository(database);
      final sheetId = await reimbursementRepository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '四月报销单',
          status: const Value('draft'),
        ),
      );
      final ticketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '高铁票',
          amountInCents: 18800,
          occurredOn: DateTime(2026, 4, 18),
          type: 'transport',
          status: 'pending',
          filePath: const Value('/local/attachments/train.jpg'),
          fileName: const Value('train.jpg'),
          fileType: const Value('image'),
        ),
      );
      await reimbursementRepository.attachTicketToReimbursementSheet(
        ticketId: ticketId,
        reimbursementSheetId: sheetId,
      );

      await reimbursementRepository.moveReimbursementSheetToTrash(sheetId);

      expect(
        await reimbursementRepository.getReimbursementSheetById(sheetId),
        isNull,
      );
      expect(await reimbursementRepository.listReimbursementSheets(), isEmpty);
      expect(await reimbursementRepository.listLinkedTickets(sheetId), isEmpty);

      final trashedSheets = await reimbursementRepository
          .listTrashedReimbursementSheets();
      expect(trashedSheets.single.id, sheetId);
      expect(trashedSheets.single.deletedAt, isNotNull);

      final linkedTicket = await ticketRepository.getTicketById(ticketId);
      expect(linkedTicket, isNotNull);
      expect(linkedTicket!.reimbursementSheetId, sheetId);
      expect(linkedTicket.filePath, '/local/attachments/train.jpg');
    },
  );

  test(
    'restore returns reimbursement sheet and linked tickets to normal flows',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final ticketRepository = TicketRepository(database);
      final reimbursementRepository = ReimbursementRepository(database);
      final sheetId = await reimbursementRepository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '五月报销单',
          status: const Value('draft'),
        ),
      );
      final ticketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '住宿票',
          amountInCents: 32800,
          occurredOn: DateTime(2026, 5, 2),
          type: 'travel',
          status: 'pending',
        ),
      );
      await reimbursementRepository.attachTicketToReimbursementSheet(
        ticketId: ticketId,
        reimbursementSheetId: sheetId,
      );

      await reimbursementRepository.moveReimbursementSheetToTrash(sheetId);
      await reimbursementRepository.restoreReimbursementSheet(sheetId);

      expect(
        await reimbursementRepository.listTrashedReimbursementSheets(),
        isEmpty,
      );
      expect(
        (await reimbursementRepository.listReimbursementSheets()).single.id,
        sheetId,
      );
      expect(
        (await reimbursementRepository.listLinkedTickets(sheetId)).single.id,
        ticketId,
      );
    },
  );

  test(
    'permanent delete removes only trashed sheet and keeps tickets and attachments',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final ticketRepository = TicketRepository(database);
      final reimbursementRepository = ReimbursementRepository(database);
      final sheetId = await reimbursementRepository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '六月报销单',
          status: const Value('draft'),
        ),
      );
      final ticketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '餐饮票',
          amountInCents: 6600,
          occurredOn: DateTime(2026, 6, 6),
          type: 'meal',
          status: 'pending',
          filePath: const Value('/local/attachments/meal.pdf'),
          fileName: const Value('meal.pdf'),
          fileType: const Value('pdf'),
        ),
      );
      await reimbursementRepository.attachTicketToReimbursementSheet(
        ticketId: ticketId,
        reimbursementSheetId: sheetId,
      );

      await reimbursementRepository.moveReimbursementSheetToTrash(sheetId);
      await reimbursementRepository.permanentlyDeleteReimbursementSheet(
        sheetId,
      );

      expect(
        await reimbursementRepository.getReimbursementSheetById(
          sheetId,
          includeTrashed: true,
        ),
        isNull,
      );
      expect(
        await reimbursementRepository.listTrashedReimbursementSheets(),
        isEmpty,
      );

      final remainingTicket = await ticketRepository.getTicketById(ticketId);
      expect(remainingTicket, isNotNull);
      expect(remainingTicket!.reimbursementSheetId, isNull);
      expect(remainingTicket.filePath, '/local/attachments/meal.pdf');
      expect(remainingTicket.fileName, 'meal.pdf');
      expect(remainingTicket.fileType, 'pdf');
    },
  );
}
