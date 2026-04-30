import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

const appDatabaseName = 'ticket_box';

class ReimbursementSheets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get status => text().withDefault(const Constant('draft'))();

  TextColumn get description => text().nullable()();

  DateTimeColumn get submittedAt => dateTime().nullable()();

  DateTimeColumn get reimbursedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Tickets extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  IntColumn get amountInCents => integer()();

  DateTimeColumn get occurredOn => dateTime()();

  TextColumn get type => text()();

  TextColumn get status => text()();

  TextColumn get note => text().nullable()();

  TextColumn get filePath => text().nullable()();

  TextColumn get fileName => text().nullable()();

  TextColumn get fileType => text().nullable()();

  IntColumn get reimbursementSheetId => integer().nullable().references(
    ReimbursementSheets,
    #id,
    onDelete: KeyAction.setNull,
  )();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TicketTags extends Table {
  IntColumn get ticketId =>
      integer().references(Tickets, #id, onDelete: KeyAction.cascade)();

  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {ticketId, tagId};
}

class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text().nullable()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [Tickets, ReimbursementSheets, Tags, TicketTags, AppSettings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: appDatabaseName));

  static Future<String> resolveDefaultPath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return path.join(documentsDirectory.path, '$appDatabaseName.sqlite');
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(tickets, tickets.fileName);
        await migrator.addColumn(tickets, tickets.fileType);
      }
      if (from < 3) {
        await migrator.addColumn(tickets, tickets.deletedAt);
      }
      if (from < 4) {
        await migrator.addColumn(
          reimbursementSheets,
          reimbursementSheets.deletedAt,
        );
      }
    },
    beforeOpen: (details) async {
      // SQLite disables foreign keys by default, so enable them explicitly.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
