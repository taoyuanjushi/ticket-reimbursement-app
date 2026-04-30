import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/inspections/duplicate_ticket_inspection_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';

void main() {
  testWidgets(
    'duplicate inspection page shows review suggestions and opens ticket detail',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = TicketRepository(database);
      final firstTicketId = await _createDuplicateTickets(repository);

      await _pumpInspectionPage(tester, database);

      expect(find.text('处理建议'), findsOneWidget);
      expect(find.text('同日同金额，标题相近'), findsOneWidget);
      expect(find.text('对比后手动处理'), findsOneWidget);
      expect(find.text('查看票据'), findsWidgets);
      expect(find.text('编辑票据'), findsWidgets);
      expect(
        find.byKey(const ValueKey('duplicate-group-count')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('duplicate-ticket-count')),
        findsOneWidget,
      );

      await _scrollToDuplicateActions(tester);
      await tester.tap(
        find.byKey(ValueKey('duplicate-ticket-view-$firstTicketId')).first,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ticket-detail-page')), findsOneWidget);
    },
  );

  testWidgets('duplicate ticket edit shortcut opens existing ticket form', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    final firstTicketId = await _createDuplicateTickets(repository);

    await _pumpInspectionPage(tester, database);
    await _scrollToDuplicateActions(tester);

    await tester.tap(
      find.byKey(ValueKey('duplicate-ticket-edit-$firstTicketId')).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TicketFormPage), findsOneWidget);
  });

  testWidgets('duplicate group review action opens manual review sheet', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    final firstTicketId = await _createDuplicateTickets(repository);

    await _pumpInspectionPage(tester, database);
    await _scrollToDuplicateActions(tester);

    await tester.tap(find.byKey(const ValueKey('duplicate-review-action')));
    await tester.pumpAndSettle();

    expect(find.text('重复票据复核'), findsOneWidget);
    expect(
      find.byKey(ValueKey('duplicate-ticket-view-$firstTicketId')),
      findsWidgets,
    );
    expect(
      find.byKey(ValueKey('duplicate-ticket-edit-$firstTicketId')),
      findsWidgets,
    );
  });
}

Future<int> _createDuplicateTickets(TicketRepository repository) async {
  final firstTicketId = await repository.createTicket(
    TicketsCompanion.insert(
      title: '高铁票',
      amountInCents: 12850,
      occurredOn: DateTime(2026, 4, 15),
      type: 'transport',
      status: 'pending',
    ),
  );
  await repository.createTicket(
    TicketsCompanion.insert(
      title: '高铁票据',
      amountInCents: 12850,
      occurredOn: DateTime(2026, 4, 15),
      type: 'transport',
      status: 'submitted',
    ),
  );

  return firstTicketId;
}

Future<void> _pumpInspectionPage(
  WidgetTester tester,
  AppDatabase database,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const MaterialApp(home: DuplicateTicketInspectionPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToDuplicateActions(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('duplicate-ticket-inspection-page')),
    const Offset(0, -300),
  );
  await tester.pumpAndSettle();
}
