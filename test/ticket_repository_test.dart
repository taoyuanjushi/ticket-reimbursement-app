import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/tag_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';

void main() {
  test('search matches title note and file name', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票',
        amountInCents: 12000,
        occurredOn: DateTime(2026, 4, 10),
        type: 'transport',
        status: 'pending',
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '午餐发票',
        amountInCents: 3600,
        occurredOn: DateTime(2026, 4, 11),
        type: 'meal',
        status: 'submitted',
        note: const Value('客户接待补贴'),
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '办公用品',
        amountInCents: 5800,
        occurredOn: DateTime(2026, 3, 20),
        type: 'office',
        status: 'submitted',
        fileName: const Value('stationery_receipt.pdf'),
      ),
    );

    expect(
      (await repository.filterTickets(keyword: '高铁')).map((item) => item.title),
      ['高铁票'],
    );
    expect(
      (await repository.filterTickets(keyword: '补贴')).map((item) => item.title),
      ['午餐发票'],
    );
    expect(
      (await repository.filterTickets(
        keyword: 'receipt',
      )).map((item) => item.title),
      ['办公用品'],
    );
  });

  test('search works together with status type and month filters', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '四月午餐',
        amountInCents: 4500,
        occurredOn: DateTime(2026, 4, 15),
        type: 'meal',
        status: 'submitted',
        note: const Value('项目报销'),
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '四月交通',
        amountInCents: 9000,
        occurredOn: DateTime(2026, 4, 15),
        type: 'transport',
        status: 'submitted',
        note: const Value('项目报销'),
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '三月午餐',
        amountInCents: 3800,
        occurredOn: DateTime(2026, 3, 15),
        type: 'meal',
        status: 'pending',
        note: const Value('项目报销'),
      ),
    );

    final results = await repository.filterTickets(
      keyword: '项目',
      status: 'submitted',
      type: 'meal',
      month: DateTime(2026, 4),
    );

    expect(results.map((item) => item.title), ['四月午餐']);
  });

  test('tag filter works together with search and other filters', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final tagRepository = TagRepository(database);
    final travelTagId = await tagRepository.createTag('差旅');
    final officeTagId = await tagRepository.createTag('办公');
    final travelTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票',
        amountInCents: 18800,
        occurredOn: DateTime(2026, 4, 18),
        type: 'transport',
        status: 'submitted',
        note: const Value('项目出差'),
      ),
    );
    final otherTravelTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '酒店票',
        amountInCents: 32800,
        occurredOn: DateTime(2026, 4, 19),
        type: 'travel',
        status: 'submitted',
        note: const Value('项目出差'),
      ),
    );
    final officeTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '显示器',
        amountInCents: 259900,
        occurredOn: DateTime(2026, 4, 20),
        type: 'office',
        status: 'submitted',
        note: const Value('项目采购'),
      ),
    );

    await tagRepository.replaceTagsForTicket(
      ticketId: travelTicketId,
      tagIds: [travelTagId],
    );
    await tagRepository.replaceTagsForTicket(
      ticketId: otherTravelTicketId,
      tagIds: [travelTagId],
    );
    await tagRepository.replaceTagsForTicket(
      ticketId: officeTicketId,
      tagIds: [officeTagId],
    );

    final results = await ticketRepository.filterTickets(
      keyword: '项目',
      status: 'submitted',
      type: 'transport',
      month: DateTime(2026, 4),
      tagId: travelTagId,
    );

    expect(results.map((item) => item.title), ['高铁票']);
  });

  test('sorting works with list queries and filtered results', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '高金额票据',
        amountInCents: 9800,
        occurredOn: DateTime(2026, 4, 12),
        type: 'office',
        status: 'submitted',
        note: const Value('项目采购'),
        createdAt: Value(DateTime(2026, 4, 12, 9)),
        updatedAt: Value(DateTime(2026, 4, 12, 9)),
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '低金额票据',
        amountInCents: 1800,
        occurredOn: DateTime(2026, 4, 18),
        type: 'office',
        status: 'submitted',
        note: const Value('项目采购'),
        createdAt: Value(DateTime(2026, 4, 18, 9)),
        updatedAt: Value(DateTime(2026, 4, 18, 10)),
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '中金额票据',
        amountInCents: 4500,
        occurredOn: DateTime(2026, 4, 15),
        type: 'office',
        status: 'submitted',
        note: const Value('项目采购'),
        createdAt: Value(DateTime(2026, 4, 15, 9)),
        updatedAt: Value(DateTime(2026, 4, 18, 11)),
      ),
    );

    final amountSorted = await repository.listTickets(
      sortField: TicketSortField.amount,
      sortDirection: TicketSortDirection.ascending,
    );
    expect(amountSorted.map((ticket) => ticket.title), [
      '低金额票据',
      '中金额票据',
      '高金额票据',
    ]);

    final updatedSorted = await repository.filterTickets(
      keyword: '项目',
      status: 'submitted',
      type: 'office',
      month: DateTime(2026, 4),
      sortField: TicketSortField.updatedAt,
      sortDirection: TicketSortDirection.descending,
    );
    expect(updatedSorted.map((ticket) => ticket.title), [
      '中金额票据',
      '低金额票据',
      '高金额票据',
    ]);
  });

  test(
    'batch operations attach tickets to a reimbursement sheet and delete',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final ticketRepository = TicketRepository(database);
      final reimbursementRepository = ReimbursementRepository(database);

      final firstId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '停车票',
          amountInCents: 2000,
          occurredOn: DateTime(2026, 4, 12),
          type: 'transport',
          status: 'pending',
        ),
      );
      final secondId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '午餐票',
          amountInCents: 3500,
          occurredOn: DateTime(2026, 4, 13),
          type: 'meal',
          status: 'pending',
        ),
      );
      final thirdId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '文具票',
          amountInCents: 1800,
          occurredOn: DateTime(2026, 4, 14),
          type: 'office',
          status: 'pending',
        ),
      );
      final sheetId = await reimbursementRepository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '四月报销单',
          status: const Value('draft'),
        ),
      );

      await reimbursementRepository.attachTicketsToReimbursementSheet(
        ticketIds: [firstId, secondId],
        reimbursementSheetId: sheetId,
      );

      final attachedTickets = await ticketRepository.getTicketsByIds([
        firstId,
        secondId,
        thirdId,
      ]);
      expect(
        attachedTickets
            .where((ticket) => ticket.reimbursementSheetId == sheetId)
            .map((ticket) => ticket.title),
        ['午餐票', '停车票'],
      );

      await ticketRepository.deleteTickets([firstId, secondId]);
      expect(
        (await ticketRepository.listTickets()).map((ticket) => ticket.title),
        ['文具票'],
      );
    },
  );

  test(
    'batch status update applies the same status to selected tickets',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = TicketRepository(database);
      final firstId = await repository.createTicket(
        TicketsCompanion.insert(
          title: '地铁票',
          amountInCents: 3000,
          occurredOn: DateTime(2026, 4, 15),
          type: 'transport',
          status: 'pending',
        ),
      );
      final secondId = await repository.createTicket(
        TicketsCompanion.insert(
          title: '午餐票',
          amountInCents: 4200,
          occurredOn: DateTime(2026, 4, 16),
          type: 'meal',
          status: 'pending',
        ),
      );

      await repository.updateTicketStatuses(
        ticketIds: [firstId, secondId],
        status: 'submitted',
      );

      final tickets = await repository.getTicketsByIds([firstId, secondId]);
      expect(tickets.map((ticket) => ticket.status), [
        'submitted',
        'submitted',
      ]);
    },
  );

  test(
    'soft delete moves tickets to recycle bin and supports restore',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = TicketRepository(database);
      final ticketId = await repository.createTicket(
        TicketsCompanion.insert(
          title: '可恢复票据',
          amountInCents: 4200,
          occurredOn: DateTime(2026, 4, 20),
          type: 'meal',
          status: 'pending',
        ),
      );

      await repository.moveTicketToTrash(ticketId);

      expect(await repository.getTicketById(ticketId), isNull);
      expect(await repository.listTickets(), isEmpty);

      final trashedTickets = await repository.listTrashedTickets();
      expect(trashedTickets.single.id, ticketId);
      expect(trashedTickets.single.deletedAt, isNotNull);

      await repository.restoreTicket(ticketId);

      expect((await repository.listTrashedTickets()), isEmpty);
      expect((await repository.listTickets()).single.id, ticketId);
    },
  );

  test('permanent delete removes trashed ticket and tag links', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final tagRepository = TagRepository(database);
    final tagId = await tagRepository.createTag('待清理');
    final ticketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '永久删除票据',
        amountInCents: 5200,
        occurredOn: DateTime(2026, 4, 21),
        type: 'office',
        status: 'pending',
      ),
    );
    await tagRepository.replaceTagsForTicket(
      ticketId: ticketId,
      tagIds: [tagId],
    );

    await ticketRepository.moveTicketToTrash(ticketId);
    await ticketRepository.permanentlyDeleteTicket(ticketId);

    expect(
      await ticketRepository.getTicketById(ticketId, includeTrashed: true),
      isNull,
    );
    expect(await tagRepository.listTagIdsForTicket(ticketId), isEmpty);
  });

  test('reimbursement ticket lists exclude recycled tickets', () async {
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
        title: '关联票据',
        amountInCents: 6600,
        occurredOn: DateTime(2026, 4, 22),
        type: 'transport',
        status: 'pending',
      ),
    );
    await reimbursementRepository.attachTicketToReimbursementSheet(
      ticketId: ticketId,
      reimbursementSheetId: sheetId,
    );

    expect(
      (await reimbursementRepository.listLinkedTickets(sheetId)),
      hasLength(1),
    );

    await ticketRepository.moveTicketToTrash(ticketId);

    expect(await reimbursementRepository.listLinkedTickets(sheetId), isEmpty);

    await ticketRepository.restoreTicket(ticketId);

    expect(
      (await reimbursementRepository.listLinkedTickets(sheetId)),
      hasLength(1),
    );
  });
}
