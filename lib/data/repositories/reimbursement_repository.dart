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

  Future<int> deleteReimbursementSheet(int id) {
    return moveReimbursementSheetToTrash(id);
  }

  Future<int> moveReimbursementSheetToTrash(int id) {
    final now = DateTime.now();
    return (database.update(
      database.reimbursementSheets,
    )..where((sheet) => sheet.id.equals(id) & sheet.deletedAt.isNull())).write(
      ReimbursementSheetsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> restoreReimbursementSheet(int id) {
    return (database.update(database.reimbursementSheets)
          ..where((sheet) => sheet.id.equals(id) & sheet.deletedAt.isNotNull()))
        .write(
          ReimbursementSheetsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> permanentlyDeleteReimbursementSheet(int id) {
    return database.transaction(() async {
      final trashedSheet =
          await (database.select(database.reimbursementSheets)..where(
                (sheet) => sheet.id.equals(id) & sheet.deletedAt.isNotNull(),
              ))
              .getSingleOrNull();
      if (trashedSheet == null) {
        return 0;
      }

      await (database.update(
        database.tickets,
      )..where((ticket) => ticket.reimbursementSheetId.equals(id))).write(
        TicketsCompanion(
          reimbursementSheetId: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

      return (database.delete(
        database.reimbursementSheets,
      )..where((sheet) => sheet.id.equals(id))).go();
    });
  }

  Future<List<ReimbursementSheet>> listReimbursementSheets() {
    final query = database.select(database.reimbursementSheets)
      ..where((sheet) => sheet.deletedAt.isNull());

    query.orderBy([
      (sheet) =>
          OrderingTerm(expression: sheet.createdAt, mode: OrderingMode.desc),
    ]);

    return query.get();
  }

  Future<List<ReimbursementSheet>> listTrashedReimbursementSheets() {
    final query = database.select(database.reimbursementSheets)
      ..where((sheet) => sheet.deletedAt.isNotNull())
      ..orderBy([
        (sheet) =>
            OrderingTerm(expression: sheet.deletedAt, mode: OrderingMode.desc),
        (sheet) =>
            OrderingTerm(expression: sheet.updatedAt, mode: OrderingMode.desc),
      ]);

    return query.get();
  }

  Future<ReimbursementSheet?> getReimbursementSheetById(
    int id, {
    bool includeTrashed = false,
  }) {
    final query = database.select(database.reimbursementSheets)
      ..where((sheet) => sheet.id.equals(id));
    if (!includeTrashed) {
      query.where((sheet) => sheet.deletedAt.isNull());
    }

    return query.getSingleOrNull();
  }

  Future<List<Ticket>> listLinkedTickets(int reimbursementSheetId) async {
    final sheet = await getReimbursementSheetById(reimbursementSheetId);
    if (sheet == null) {
      return const <Ticket>[];
    }

    final query = database.select(database.tickets)
      ..where(
        (ticket) =>
            ticket.reimbursementSheetId.equals(reimbursementSheetId) &
            ticket.deletedAt.isNull(),
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
      ..where(
        (ticket) =>
            ticket.reimbursementSheetId.isNull() & ticket.deletedAt.isNull(),
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

  Future<int> attachTicketToReimbursementSheet({
    required int ticketId,
    required int reimbursementSheetId,
  }) async {
    if (!await _activeSheetExists(reimbursementSheetId)) {
      return 0;
    }

    return (database.update(database.tickets)..where(
          (ticket) => ticket.id.equals(ticketId) & ticket.deletedAt.isNull(),
        ))
        .write(
          TicketsCompanion(
            reimbursementSheetId: Value(reimbursementSheetId),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> attachTicketsToReimbursementSheet({
    required List<int> ticketIds,
    required int reimbursementSheetId,
  }) async {
    if (ticketIds.isEmpty) {
      return Future.value(0);
    }
    if (!await _activeSheetExists(reimbursementSheetId)) {
      return 0;
    }

    return (database.update(database.tickets)..where(
          (ticket) => ticket.id.isIn(ticketIds) & ticket.deletedAt.isNull(),
        ))
        .write(
          TicketsCompanion(
            reimbursementSheetId: Value(reimbursementSheetId),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<int> removeTicketFromReimbursementSheet({required int ticketId}) {
    return (database.update(database.tickets)..where(
          (ticket) => ticket.id.equals(ticketId) & ticket.deletedAt.isNull(),
        ))
        .write(
          TicketsCompanion(
            reimbursementSheetId: Value<int?>(null),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<bool> _activeSheetExists(int reimbursementSheetId) async {
    final sheet = await getReimbursementSheetById(reimbursementSheetId);
    return sheet != null;
  }
}
