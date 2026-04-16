import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
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
}
