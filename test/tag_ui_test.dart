import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/data/repositories/tag_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/tags/tag_management_page.dart';
import 'package:ticket_box/features/settings/local_maintenance_providers.dart';
import 'package:ticket_box/features/settings/local_maintenance_service.dart';
import 'package:ticket_box/features/settings/settings_page.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_form_page.dart';

const _fakeMaintenanceInfo = LocalMaintenanceInfo(
  databasePath: '/local/ticket_box.sqlite',
  attachmentDirectoryPath: '/local/ticket_attachments',
  reimbursementExportDirectoryPath: '/local/reimbursement_exports',
  invalidAttachmentCount: 0,
);

Finder _settingsScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('settings-page-content')),
        matching: find.byType(Scrollable),
      )
      .first;
}

void main() {
  testWidgets('settings page shows tag management entry', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          localMaintenanceInfoProvider.overrideWith(
            (ref) async => _fakeMaintenanceInfo,
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('标签管理'),
      300,
      scrollable: _settingsScrollable(),
    );
    await tester.pumpAndSettle();

    expect(find.text('标签管理'), findsOneWidget);
    expect(find.text('管理本地标签'), findsOneWidget);
    expect(find.text('在票据表单里可多选标签'), findsOneWidget);
  });

  testWidgets('ticket form page shows local tags and supports selection', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final tagRepository = TagRepository(database);
    await tagRepository.createTag('差旅');
    await tagRepository.createTag('餐饮');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TicketFormPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('差旅'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('管理标签'), findsOneWidget);
    expect(find.text('差旅'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('未选择标签'), findsOneWidget);

    await tester.tap(find.text('差旅'));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 个标签'), findsOneWidget);
  });

  testWidgets('ticket detail page shows assigned tags', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final tagRepository = TagRepository(database);
    final ticketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '差旅发票',
        amountInCents: 12800,
        occurredOn: DateTime(2026, 4, 20),
        type: 'transport',
        status: 'pending',
      ),
    );
    final travelTagId = await tagRepository.createTag('差旅');
    final archiveTagId = await tagRepository.createTag('留档');
    await tagRepository.replaceTagsForTicket(
      ticketId: ticketId,
      tagIds: [travelTagId, archiveTagId],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: TicketDetailPage(ticketId: ticketId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('差旅'), 300);
    await tester.pumpAndSettle();

    expect(find.text('标签'), findsOneWidget);
    expect(find.text('差旅'), findsOneWidget);
    expect(find.text('留档'), findsOneWidget);
  });

  testWidgets('tag management page shows ticket count and total amount', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final tagRepository = TagRepository(database);
    final travelTagId = await tagRepository.createTag('差旅');
    final mealTagId = await tagRepository.createTag('餐饮');
    await tagRepository.createTag('备用');
    final firstTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '高铁票',
        amountInCents: 12800,
        occurredOn: DateTime(2026, 4, 20),
        type: 'transport',
        status: 'pending',
      ),
    );
    final secondTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '午餐票',
        amountInCents: 3600,
        occurredOn: DateTime(2026, 4, 20),
        type: 'meal',
        status: 'pending',
      ),
    );
    await tagRepository.replaceTagsForTicket(
      ticketId: firstTicketId,
      tagIds: [travelTagId],
    );
    await tagRepository.replaceTagsForTicket(
      ticketId: secondTicketId,
      tagIds: [travelTagId, mealTagId],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: TagManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 张票据'), findsOneWidget);
    expect(find.text('1 张票据'), findsOneWidget);
    expect(find.text('0 张票据'), findsOneWidget);
    expect(find.text('¥164.00'), findsOneWidget);
    expect(find.text('¥36.00'), findsOneWidget);
    expect(find.text('¥0.00'), findsOneWidget);
  });
}
