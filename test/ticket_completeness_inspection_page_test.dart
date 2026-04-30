import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/inspections/ticket_completeness_inspection_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';

void main() {
  testWidgets(
    'ticket completeness inspection page shows issues and opens detail',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = TicketRepository(database);
      final ticketId = await repository.createTicket(
        TicketsCompanion.insert(
          title: '',
          amountInCents: 0,
          occurredOn: DateTime(2026, 4, 15),
          type: 'other',
          status: 'pending',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: TicketCompletenessInspectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('票据完整性检查'), findsOneWidget);
      expect(find.text('票据完整性'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('incomplete-ticket-count')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ticket-completeness-issue-count')),
        findsOneWidget,
      );
      expect(find.text('未命名票据'), findsOneWidget);
      expect(find.text('标题为空'), findsWidgets);
      expect(find.text('金额缺失'), findsWidgets);
      expect(find.text('待报销无附件'), findsWidgets);
      expect(find.text('处理建议'), findsOneWidget);
      expect(find.text('去编辑'), findsOneWidget);
      expect(find.text('补充附件'), findsOneWidget);
      expect(find.text('查看详情'), findsOneWidget);

      final detailAction = find.byKey(
        ValueKey('ticket-repair-detail-$ticketId'),
      );
      await tester.drag(
        find.byKey(const ValueKey('ticket-completeness-inspection-page')),
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
      await tester.tap(detailAction);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ticket-detail-page')), findsOneWidget);
    },
  );

  testWidgets('ticket repair edit action opens existing ticket form', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    final ticketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '',
        amountInCents: 0,
        occurredOn: DateTime(2026, 4, 15),
        type: 'other',
        status: 'pending',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TicketCompletenessInspectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('ticket-repair-attachment-$ticketId')),
      findsOneWidget,
    );

    final editAction = find.byKey(ValueKey('ticket-repair-edit-$ticketId'));
    await tester.drag(
      find.byKey(const ValueKey('ticket-completeness-inspection-page')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(editAction);
    await tester.pumpAndSettle();

    expect(find.byType(TicketFormPage), findsOneWidget);
  });
}
