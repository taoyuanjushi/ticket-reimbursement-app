import 'package:drift/drift.dart';
import 'package:ticket_box/data/local/app_database.dart';

enum TicketSortField { date, amount, updatedAt }

enum TicketSortDirection { ascending, descending }

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

  Future<List<Ticket>> listTickets({
    TicketSortField sortField = TicketSortField.date,
    TicketSortDirection sortDirection = TicketSortDirection.descending,
  }) {
    return _orderedTicketQuery(
      sortField: sortField,
      sortDirection: sortDirection,
    ).get();
  }

  Future<List<Ticket>> getTicketsByIds(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value(const []);
    }

    final query = _orderedTicketQuery();
    query.where((ticket) => ticket.id.isIn(ids));
    return query.get();
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
    TicketSortField sortField = TicketSortField.date,
    TicketSortDirection sortDirection = TicketSortDirection.descending,
  }) {
    final statement = _orderedTicketQuery(
      sortField: sortField,
      sortDirection: sortDirection,
    );

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

  Future<int> updateTicketStatuses({
    required List<int> ticketIds,
    required String status,
  }) {
    if (ticketIds.isEmpty) {
      return Future.value(0);
    }

    return (database.update(
      database.tickets,
    )..where((ticket) => ticket.id.isIn(ticketIds))).write(
      TicketsCompanion(status: Value(status), updatedAt: Value(DateTime.now())),
    );
  }

  Future<int> deleteTickets(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value(0);
    }

    return (database.delete(
      database.tickets,
    )..where((ticket) => ticket.id.isIn(ids))).go();
  }

  SimpleSelectStatement<Tickets, Ticket> _orderedTicketQuery({
    TicketSortField sortField = TicketSortField.date,
    TicketSortDirection sortDirection = TicketSortDirection.descending,
  }) {
    final query = database.select(database.tickets);

    query.orderBy(_buildOrdering(sortField, sortDirection));

    return query;
  }

  List<OrderingTerm Function(Tickets)> _buildOrdering(
    TicketSortField sortField,
    TicketSortDirection sortDirection,
  ) {
    final primaryMode = sortDirection == TicketSortDirection.ascending
        ? OrderingMode.asc
        : OrderingMode.desc;

    switch (sortField) {
      case TicketSortField.date:
        return [
          (ticket) =>
              OrderingTerm(expression: ticket.occurredOn, mode: primaryMode),
          (ticket) => OrderingTerm(
            expression: ticket.updatedAt,
            mode: OrderingMode.desc,
          ),
          (ticket) => OrderingTerm(
            expression: ticket.createdAt,
            mode: OrderingMode.desc,
          ),
        ];
      case TicketSortField.amount:
        return [
          (ticket) =>
              OrderingTerm(expression: ticket.amountInCents, mode: primaryMode),
          (ticket) => OrderingTerm(
            expression: ticket.occurredOn,
            mode: OrderingMode.desc,
          ),
          (ticket) => OrderingTerm(
            expression: ticket.createdAt,
            mode: OrderingMode.desc,
          ),
        ];
      case TicketSortField.updatedAt:
        return [
          (ticket) =>
              OrderingTerm(expression: ticket.updatedAt, mode: primaryMode),
          (ticket) => OrderingTerm(
            expression: ticket.occurredOn,
            mode: OrderingMode.desc,
          ),
          (ticket) => OrderingTerm(
            expression: ticket.createdAt,
            mode: OrderingMode.desc,
          ),
        ];
    }
  }
}
