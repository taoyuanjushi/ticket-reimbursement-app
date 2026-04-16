import 'package:drift/drift.dart';
import 'package:ticket_box/data/local/app_database.dart';

class TicketRepository {
  TicketRepository(this.database);

  final AppDatabase database;

  Future<int> createTicket(TicketsCompanion ticket) {
    return database.into(database.tickets).insert(ticket);
  }

  Future<bool> updateTicket(Ticket ticket) {
    return database
        .update(database.tickets)
        .replace(ticket.copyWith(updatedAt: DateTime.now()));
  }

  Future<int> deleteTicket(int id) {
    return (database.delete(
      database.tickets,
    )..where((ticket) => ticket.id.equals(id))).go();
  }

  Future<Ticket?> getTicketById(int id) {
    return (database.select(
      database.tickets,
    )..where((ticket) => ticket.id.equals(id))).getSingleOrNull();
  }

  Future<List<Ticket>> listTickets() {
    return _orderedTicketQuery().get();
  }

  Future<List<Ticket>> listTicketsWithAttachments() {
    final query = _orderedTicketQuery();
    query.where((ticket) => ticket.filePath.isNotNull());
    return query.get();
  }

  Future<List<Ticket>> filterTickets({
    String? status,
    String? type,
    DateTime? month,
    String? keyword,
  }) {
    final statement = _orderedTicketQuery();

    if (status != null && status.isNotEmpty) {
      statement.where((ticket) => ticket.status.equals(status));
    }

    if (type != null && type.isNotEmpty) {
      statement.where((ticket) => ticket.type.equals(type));
    }

    if (month != null) {
      final monthStart = DateTime(month.year, month.month);
      final nextMonthStart = DateTime(month.year, month.month + 1);

      statement.where(
        (ticket) =>
            ticket.occurredOn.isBiggerOrEqualValue(monthStart) &
            ticket.occurredOn.isSmallerThanValue(nextMonthStart),
      );
    }

    final searchQuery = keyword?.trim();
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final pattern = '%$searchQuery%';
      statement.where(
        (ticket) =>
            ticket.title.like(pattern) |
            ticket.note.like(pattern) |
            ticket.fileName.like(pattern),
      );
    }

    return statement.get();
  }

  Future<int> clearAttachmentMetadataForTickets(List<int> ticketIds) {
    if (ticketIds.isEmpty) {
      return Future.value(0);
    }

    final statement = database.update(database.tickets)
      ..where((ticket) => ticket.id.isIn(ticketIds));

    return statement.write(
      TicketsCompanion(
        filePath: const Value(null),
        fileName: const Value(null),
        fileType: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  SimpleSelectStatement<Tickets, Ticket> _orderedTicketQuery() {
    final query = database.select(database.tickets);

    query.orderBy([
      (ticket) =>
          OrderingTerm(expression: ticket.occurredOn, mode: OrderingMode.desc),
      (ticket) =>
          OrderingTerm(expression: ticket.createdAt, mode: OrderingMode.desc),
    ]);

    return query;
  }
}
