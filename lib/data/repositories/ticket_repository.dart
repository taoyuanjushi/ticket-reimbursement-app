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
    return moveTicketToTrash(id);
  }

  Future<int> moveTicketToTrash(int id) {
    final now = DateTime.now();
    return (database.update(database.tickets)
          ..where((ticket) => ticket.id.equals(id) & ticket.deletedAt.isNull()))
        .write(TicketsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  Future<int> restoreTicket(int id) {
    return (database.update(database.tickets)..where(
          (ticket) => ticket.id.equals(id) & ticket.deletedAt.isNotNull(),
        ))
        .write(
          TicketsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> permanentlyDeleteTicket(int id) {
    return database.transaction(() async {
      final deletedCount =
          await (database.delete(database.tickets)..where(
                (ticket) => ticket.id.equals(id) & ticket.deletedAt.isNotNull(),
              ))
              .go();

      if (deletedCount > 0) {
        await (database.delete(
          database.ticketTags,
        )..where((row) => row.ticketId.equals(id))).go();
      }

      return deletedCount;
    });
  }

  Future<Ticket?> getTicketById(int id, {bool includeTrashed = false}) {
    final query = database.select(database.tickets)
      ..where((ticket) => ticket.id.equals(id));
    if (!includeTrashed) {
      query.where((ticket) => ticket.deletedAt.isNull());
    }

    return query.getSingleOrNull();
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

  Future<List<Ticket>> listTrashedTickets() {
    final query = database.select(database.tickets)
      ..where((ticket) => ticket.deletedAt.isNotNull())
      ..orderBy([
        (ticket) =>
            OrderingTerm(expression: ticket.deletedAt, mode: OrderingMode.desc),
        (ticket) =>
            OrderingTerm(expression: ticket.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.get();
  }

  Future<List<Ticket>> filterTickets({
    String? status,
    String? type,
    DateTime? month,
    int? tagId,
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

    if (tagId != null) {
      final taggedTicketIds = database.selectOnly(database.ticketTags)
        ..addColumns([database.ticketTags.ticketId])
        ..where(database.ticketTags.tagId.equals(tagId));

      statement.where((ticket) => ticket.id.isInQuery(taggedTicketIds));
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

    final statement = database.update(
      database.tickets,
    )..where((ticket) => ticket.id.isIn(ticketIds) & ticket.deletedAt.isNull());

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

    return (database.update(database.tickets)..where(
          (ticket) => ticket.id.isIn(ticketIds) & ticket.deletedAt.isNull(),
        ))
        .write(
          TicketsCompanion(
            status: Value(status),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> deleteTickets(List<int> ids) {
    return moveTicketsToTrash(ids);
  }

  Future<int> moveTicketsToTrash(List<int> ids) {
    if (ids.isEmpty) {
      return Future.value(0);
    }

    final now = DateTime.now();
    return (database.update(database.tickets)
          ..where((ticket) => ticket.id.isIn(ids) & ticket.deletedAt.isNull()))
        .write(TicketsCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  SimpleSelectStatement<Tickets, Ticket> _orderedTicketQuery({
    TicketSortField sortField = TicketSortField.date,
    TicketSortDirection sortDirection = TicketSortDirection.descending,
  }) {
    final query = database.select(database.tickets);
    query.where((ticket) => ticket.deletedAt.isNull());

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
