import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/inspections/reimbursement_completeness_inspection_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_form_page.dart';

void main() {
  testWidgets(
    'reimbursement completeness inspection page shows repair suggestions and opens detail',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = ReimbursementRepository(database);
      final sheetId = await repository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '空报销单',
          status: const Value('draft'),
        ),
      );

      await _pumpInspectionPage(tester, database);

      expect(
        find.byKey(const ValueKey('problematic-reimbursement-count')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reimbursement-completeness-issue-count')),
        findsOneWidget,
      );
      expect(find.text('空报销单'), findsOneWidget);
      expect(find.text('处理建议'), findsOneWidget);
      expect(find.text('查看报销单'), findsOneWidget);
      expect(find.text('去编辑'), findsOneWidget);

      await _scrollToActions(tester);
      await tester.tap(
        find.byKey(ValueKey('reimbursement-repair-detail-$sheetId')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('reimbursement-detail-page')),
        findsOneWidget,
      );
    },
  );

  testWidgets('reimbursement repair edit action opens existing form', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = ReimbursementRepository(database);
    final sheetId = await repository.createReimbursementSheet(
      ReimbursementSheetsCompanion.insert(
        title: '空报销单',
        status: const Value('draft'),
      ),
    );

    await _pumpInspectionPage(tester, database);
    await _scrollToActions(tester);

    await tester.tap(
      find.byKey(ValueKey('reimbursement-repair-edit-$sheetId')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReimbursementFormPage), findsOneWidget);
  });

  testWidgets(
    'reimbursement repair ticket action opens related ticket detail',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final reimbursementRepository = ReimbursementRepository(database);
      final ticketRepository = TicketRepository(database);

      final sheetId = await reimbursementRepository.createReimbursementSheet(
        ReimbursementSheetsCompanion.insert(
          title: '差旅报销',
          status: const Value('draft'),
          description: const Value('差旅材料'),
        ),
      );
      final ticketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '',
          amountInCents: 0,
          occurredOn: DateTime(2026, 4, 15),
          type: 'travel',
          status: 'pending',
        ),
      );
      await reimbursementRepository.attachTicketToReimbursementSheet(
        ticketId: ticketId,
        reimbursementSheetId: sheetId,
      );

      await _pumpInspectionPage(tester, database);

      expect(find.text('处理票据'), findsOneWidget);

      await _scrollToActions(tester);
      await tester.tap(
        find.byKey(ValueKey('reimbursement-repair-tickets-$sheetId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('处理关联票据'), findsOneWidget);
      expect(
        find.byKey(ValueKey('reimbursement-problem-ticket-$ticketId')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey('reimbursement-problem-ticket-$ticketId')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ticket-detail-page')), findsOneWidget);
    },
  );
}

Future<void> _pumpInspectionPage(
  WidgetTester tester,
  AppDatabase database,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MaterialApp(home: ReimbursementCompletenessInspectionPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToActions(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('reimbursement-completeness-inspection-page')),
    const Offset(0, -260),
  );
  await tester.pumpAndSettle();
}
