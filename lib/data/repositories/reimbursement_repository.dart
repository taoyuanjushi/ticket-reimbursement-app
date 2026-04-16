import 'package:drift/drift.dart';
import 'package:ticket_box/data/local/app_database.dart';

class ReimbursementRepository {
  ReimbursementRepository(this.database);

  final AppDatabase database;

  Future<int> createReimbursementSheet(ReimbursementSheetsCompanion sheet) {
    return database.into(database.reimbursementSheets).insert(sheet);
  }

  Future<bool> updateReimbursementSheet(ReimbursementSheet sheet) {
    return database
        .update(database.reimbursementSheets)
        .replace(sheet.copyWith(updatedAt: DateTime.now()));
  }

  Future<List<ReimbursementSheet>> listReimbursementSheets() {
    final query = database.select(database.reimbursementSheets);

    query.orderBy([
      (sheet) =>
          OrderingTerm(expression: sheet.createdAt, mode: OrderingMode.desc),
    ]);

    return query.get();
  }

  Future<ReimbursementSheet?> getReimbursementSheetById(int id) {
    return (database.select(
      database.reimbursementSheets,
    )..where((sheet) => sheet.id.equals(id))).getSingleOrNull();
  }

  Future<List<Ticket>> listLinkedTickets(int reimbursementSheetId) {
    final query = database.select(database.tickets)
      ..where(
        (ticket) => ticket.reimbursementSheetId.equals(reimbursementSheetId),
      )
      ..orderBy([
        (ticket) => OrderingTerm(
          expression: ticket.occurredOn,
          mode: OrderingMode.desc,
        ),
        (ticket) =>
            OrderingTerm(expression: ticket.createdAt, mode: OrderingMode.desc),
      ]);

    return query.get();
  }

  Future<List<Ticket>> listAvailableTickets() {
    final query = database.select(database.tickets)
      ..where((ticket) => ticket.reimbursementSheetId.isNull())
      ..orderBy([
        (ticket) => OrderingTerm(
          expression: ticket.occurredOn,
          mode: OrderingMode.desc,
        ),
        (ticket) =>
            OrderingTerm(expression: ticket.createdAt, mode: OrderingMode.desc),
      ]);

    return query.get();
  }

  Future<int> attachTicketToReimbursementSheet({
    required int ticketId,
    required int reimbursementSheetId,
  }) {
    return (database.update(
      database.tickets,
    )..where((ticket) => ticket.id.equals(ticketId))).write(
      TicketsCompanion(
        reimbursementSheetId: Value(reimbursementSheetId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> removeTicketFromReimbursementSheet({required int ticketId}) {
    return (database.update(
      database.tickets,
    )..where((ticket) => ticket.id.equals(ticketId))).write(
      TicketsCompanion(
        reimbursementSheetId: Value<int?>(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
