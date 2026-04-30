import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/inspections/duplicate_ticket_inspection_service.dart';

void main() {
  test('detects possible duplicate tickets without changing data', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    final duplicateTicketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票',
        amountInCents: 12850,
        occurredOn: DateTime(2026, 4, 15),
        type: 'transport',
        status: 'pending',
      ),
    );
    final similarTicketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票据',
        amountInCents: 12850,
        occurredOn: DateTime(2026, 4, 15),
        type: 'transport',
        status: 'submitted',
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '午餐票据',
        amountInCents: 12850,
        occurredOn: DateTime(2026, 4, 15),
        type: 'meal',
        status: 'pending',
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票',
        amountInCents: 9800,
        occurredOn: DateTime(2026, 4, 15),
        type: 'transport',
        status: 'pending',
      ),
    );

    final service = DuplicateTicketInspectionService(repository);
    final result = await service.inspect();

    expect(result.groupCount, 1);
    expect(result.ticketCount, 2);
    expect(result.groups.single.tickets.map((ticket) => ticket.id).toSet(), {
      duplicateTicketId,
      similarTicketId,
    });
    expect(await repository.getTicketById(duplicateTicketId), isNotNull);
    expect(await repository.getTicketById(similarTicketId), isNotNull);
  });
}
