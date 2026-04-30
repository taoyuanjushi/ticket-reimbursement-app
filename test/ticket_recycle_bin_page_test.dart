import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/settings/ticket_recycle_bin_page.dart';

void main() {
  testWidgets('ticket recycle bin restores and permanently deletes tickets', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    final restorableTicketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '可恢复票据',
        amountInCents: 4200,
        occurredOn: DateTime(2026, 4, 20),
        type: 'meal',
        status: 'pending',
      ),
    );
    final permanentTicketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '待永久删除票据',
        amountInCents: 5200,
        occurredOn: DateTime(2026, 4, 21),
        type: 'office',
        status: 'pending',
      ),
    );
    await repository.moveTicketsToTrash([
      restorableTicketId,
      permanentTicketId,
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TicketRecycleBinPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回收站'), findsOneWidget);
    expect(find.text('回收站状态'), findsOneWidget);
    expect(find.text('回收站中的内容可以恢复。永久删除后无法恢复。'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('recycle-bin-ticket-count')))
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('recycle-bin-sheet-count')))
          .data,
      '0',
    );
    expect(find.text('可恢复票据'), findsOneWidget);
    expect(find.text('待永久删除票据'), findsOneWidget);
    expect(find.text('恢复'), findsWidgets);
    expect(find.text('永久删除'), findsWidgets);

    await tester.tap(
      find.byKey(ValueKey('restore-ticket-$restorableTicketId')),
    );
    await tester.pumpAndSettle();

    expect((await repository.listTickets()).map((ticket) => ticket.id), [
      restorableTicketId,
    ]);
    expect(find.text('可恢复票据'), findsNothing);

    await tester.tap(
      find.byKey(ValueKey('permanently-delete-ticket-$permanentTicketId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除').last);
    await tester.pumpAndSettle();

    expect(
      await repository.getTicketById(permanentTicketId, includeTrashed: true),
      isNull,
    );
    expect(await repository.listTrashedTickets(), isEmpty);
  });

  testWidgets(
    'recycle bin restores and permanently deletes reimbursement sheets',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = ReimbursementRepository(database);
      final restorableSheetId = await repository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '可恢复报销单',
          status: const Value('draft'),
        ),
      );
      final permanentSheetId = await repository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '待永久删除报销单',
          status: const Value('submitted'),
        ),
      );
      await repository.moveReimbursementSheetToTrash(restorableSheetId);
      await repository.moveReimbursementSheetToTrash(permanentSheetId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: TicketRecycleBinPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recycle-bin-sheet-count')))
            .data,
        '2',
      );
      expect(find.text('已删除报销单'), findsWidgets);
      await tester.scrollUntilVisible(find.text('可恢复报销单'), 300);
      await tester.pumpAndSettle();
      expect(find.text('可恢复报销单'), findsOneWidget);
      expect(find.text('待永久删除报销单'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(ValueKey('restore-reimbursement-$restorableSheetId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('restore-reimbursement-$restorableSheetId')),
      );
      await tester.pumpAndSettle();

      expect(
        (await repository.listReimbursementSheets()).map((sheet) => sheet.id),
        [restorableSheetId],
      );
      expect(find.text('可恢复报销单'), findsNothing);

      await tester.ensureVisible(
        find.byKey(
          ValueKey('permanently-delete-reimbursement-$permanentSheetId'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey('permanently-delete-reimbursement-$permanentSheetId'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('永久删除').last);
      await tester.pumpAndSettle();

      expect(
        await repository.getReimbursementSheetById(
          permanentSheetId,
          includeTrashed: true,
        ),
        isNull,
      );
      expect(await repository.listTrashedReimbursementSheets(), isEmpty);
    },
  );

  testWidgets('recycle bin shows clear empty guidance', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TicketRecycleBinPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回收站是空的'), findsOneWidget);
    expect(find.text('当前没有已删除内容。误删的票据或报销单会先进入这里。'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('recycle-bin-ticket-count')))
          .data,
      '0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('recycle-bin-sheet-count')))
          .data,
      '0',
    );
    expect(find.text('暂无已删除票据'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('暂无已删除报销单'), 300);
    await tester.pumpAndSettle();
    expect(find.text('暂无已删除报销单'), findsOneWidget);
  });
}
