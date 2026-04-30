import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/home/home_page.dart';
import 'package:ticket_box/features/home/home_providers.dart';

void main() {
  testWidgets('home page supports switching dashboard statistics range', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final reimbursementRepository = ReimbursementRepository(database);

    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '四月交通票据',
        amountInCents: 4200,
        occurredOn: DateTime(2026, 4, 16),
        type: 'transport',
        status: 'pending',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '四月餐饮票据',
        amountInCents: 3600,
        occurredOn: DateTime(2026, 4, 15),
        type: 'meal',
        status: 'submitted',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '三月办公票据',
        amountInCents: 9800,
        occurredOn: DateTime(2026, 3, 14),
        type: 'office',
        status: 'pending',
      ),
    );

    await reimbursementRepository.createReimbursementSheet(
      ReimbursementSheetsCompanion.insert(
        title: '四月差旅报销',
        status: const Value('draft'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          homeCurrentDateProvider.overrideWithValue(DateTime(2026, 4, 29)),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-range-currentMonth')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-range-previousMonth')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-range-all')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-ticket-count')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-ticket-amount')),
        matching: find.text('¥78.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-pending-tickets')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-pending-amount')),
        matching: find.text('¥42.00'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home-range-previousMonth')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-ticket-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-ticket-amount')),
        matching: find.text('¥98.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-pending-tickets')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-pending-amount')),
        matching: find.text('¥98.00'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home-range-all')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-ticket-count')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-ticket-amount')),
        matching: find.text('¥176.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-pending-tickets')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-pending-amount')),
        matching: find.text('¥140.00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-reimbursement-sheets')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });
}
