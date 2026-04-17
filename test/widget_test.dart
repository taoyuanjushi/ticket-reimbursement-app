import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/app/app.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/home/home_page.dart';
import 'package:ticket_box/data/repositories/reimbursement_repository.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_detail_page.dart';
import 'package:ticket_box/features/reimbursements/reimbursements_page.dart';
import 'package:ticket_box/features/settings/local_maintenance_providers.dart';
import 'package:ticket_box/features/settings/local_maintenance_service.dart';
import 'package:ticket_box/features/settings/settings_page.dart';
import 'package:ticket_box/features/tickets/ticket_detail_page.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/features/tickets/tickets_page.dart';

const _fakeMaintenanceInfo = LocalMaintenanceInfo(
  databasePath: '/local/ticket_box.sqlite',
  attachmentDirectoryPath: '/local/ticket_attachments',
  reimbursementExportDirectoryPath: '/local/reimbursement_exports',
  invalidAttachmentCount: 2,
);

Finder _settingsScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('settings-page-content')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Finder _ticketsScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('tickets-page')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Finder _homeScrollable() {
  return find
      .descendant(
        of: find.byKey(const ValueKey('home-page-content')),
        matching: find.byType(Scrollable),
      )
      .first;
}

void main() {
  testWidgets('home page shows workbench summary and recent items', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final reimbursementRepository = ReimbursementRepository(database);

    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '打车票据',
        amountInCents: 4200,
        occurredOn: DateTime(2026, 4, 16),
        type: 'transport',
        status: 'pending',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '午餐票据',
        amountInCents: 3600,
        occurredOn: DateTime(2026, 4, 15),
        type: 'meal',
        status: 'submitted',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '办公票据',
        amountInCents: 9800,
        occurredOn: DateTime(2026, 4, 14),
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
    await reimbursementRepository.createReimbursementSheet(
      ReimbursementSheetsCompanion.insert(
        title: '项目采购报销',
        status: const Value('submitted'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增票据'), findsOneWidget);
    expect(find.text('新建报销单'), findsOneWidget);
    expect(find.text('工作概览'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-summary-total-tickets')),
        matching: find.text('3'),
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
        of: find.byKey(const ValueKey('home-summary-reimbursement-sheets')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('最近票据'), findsOneWidget);
    expect(find.text('打车票据'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('最近报销单'),
      300,
      scrollable: _homeScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('最近报销单'), findsOneWidget);
    expect(find.text('项目采购报销'), findsOneWidget);
    expect(find.text('四月差旅报销'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between main sections', (
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
        child: const TicketBoxApp(),
      ),
    );

    expect(find.byKey(const ValueKey('home-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-tickets')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tickets-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-reimbursements')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reimbursements-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(find.text('提醒设置'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('本地维护'),
      300,
      scrollable: _settingsScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('本地维护'), findsOneWidget);
  });

  testWidgets('settings page renders reminder and maintenance controls', (
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

    expect(find.text('开启本地提醒'), findsOneWidget);
    expect(find.text('默认提醒时间'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('本地数据库路径'),
      300,
      scrollable: _settingsScrollable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('本地数据库路径'), findsOneWidget);
    expect(find.text('无效附件引用：2 条'), findsOneWidget);
    expect(find.text('清空导出 CSV'), findsOneWidget);
    expect(find.text('清理无效附件引用'), findsOneWidget);
    expect(find.text('取消全部待提醒通知'), findsOneWidget);
  });

  testWidgets(
    'tickets page shows archive guidance and latest three tickets by default',
    (WidgetTester tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final repository = TicketRepository(database);
      await repository.createTicket(
        TicketsCompanion.insert(
          title: '第一张票据',
          amountInCents: 1000,
          occurredOn: DateTime(2026, 4, 12),
          type: 'meal',
          status: 'pending',
        ),
      );
      await repository.createTicket(
        TicketsCompanion.insert(
          title: '第二张票据',
          amountInCents: 2000,
          occurredOn: DateTime(2026, 4, 13),
          type: 'meal',
          status: 'pending',
        ),
      );
      await repository.createTicket(
        TicketsCompanion.insert(
          title: '第三张票据',
          amountInCents: 3000,
          occurredOn: DateTime(2026, 4, 14),
          type: 'meal',
          status: 'pending',
        ),
      );
      await repository.createTicket(
        TicketsCompanion.insert(
          title: '第四张票据',
          amountInCents: 4000,
          occurredOn: DateTime(2026, 4, 15),
          type: 'meal',
          status: 'pending',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: Scaffold(body: TicketsPage())),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TicketsPage)),
      );
      expect(container.read(ticketArchiveResultsVisibleProvider), isFalse);
      expect(
        find.byKey(const ValueKey('ticket-archive-search-input')),
        findsOneWidget,
      );
      final ticketsScrollable = find.descendant(
        of: find.byKey(const ValueKey('tickets-page')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('最近 3 张票据'),
        300,
        scrollable: ticketsScrollable.first,
      );
      await tester.pumpAndSettle();
      expect(find.text('最近 3 张票据'), findsOneWidget);
      expect(find.text('默认仅显示最近票据。'), findsOneWidget);
      expect(find.text('第四张票据'), findsOneWidget);
      expect(find.text('第三张票据'), findsOneWidget);
      expect(find.text('第二张票据'), findsOneWidget);
      expect(find.text('第一张票据'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('先搜索，再看结果'),
        300,
        scrollable: ticketsScrollable.first,
      );
      await tester.pumpAndSettle();
      expect(find.text('先搜索，再看结果'), findsOneWidget);
      expect(find.text('查看全部票据'), findsOneWidget);
      expect(find.text('全部票据 4 张'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('ticket-view-all-button')));
      await tester.pumpAndSettle();

      expect(find.text('全部票据 4 张'), findsOneWidget);
      expect(find.text('第一张票据'), findsOneWidget);
      expect(find.text('第二张票据'), findsOneWidget);
      expect(find.text('第三张票据'), findsOneWidget);
      expect(find.text('第四张票据'), findsOneWidget);
    },
  );

  testWidgets('tickets page supports batch add to reimbursement sheets', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final reimbursementRepository = ReimbursementRepository(database);
    final sheetId = await reimbursementRepository.createReimbursementSheet(
      ReimbursementSheetsCompanion.insert(
        title: '四月批量报销',
        status: const Value('draft'),
      ),
    );
    final firstTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '打车票',
        amountInCents: 4800,
        occurredOn: DateTime(2026, 4, 15),
        type: 'transport',
        status: 'pending',
      ),
    );
    final secondTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '午餐票',
        amountInCents: 3600,
        occurredOn: DateTime(2026, 4, 16),
        type: 'meal',
        status: 'pending',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: TicketsPage())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TicketsPage)),
    );
    container.read(ticketShowAllProvider.notifier).showAll();
    container.read(ticketSelectionProvider.notifier).start();
    await container.read(ticketListProvider.future);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('已选 0 张票据'),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();

    expect(find.text('已选 0 张票据'), findsOneWidget);
    expect(find.text('加入报销单'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('全部票据 2 张'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('ticket-card-$firstTicketId')),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ticket-card-$firstTicketId')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('ticket-card-$secondTicketId')),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ticket-card-$secondTicketId')));
    await tester.pumpAndSettle();

    expect(find.text('已选 2 张票据'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-batch-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('四月批量报销').first);
    await tester.pumpAndSettle();

    expect(find.text('已选 0 张票据'), findsOneWidget);
    expect(
      (await reimbursementRepository.listLinkedTickets(
        sheetId,
      )).map((ticket) => ticket.title),
      ['午餐票', '打车票'],
    );
  });

  testWidgets('tickets page supports batch delete', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final deleteTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '待删票据',
        amountInCents: 5200,
        occurredOn: DateTime(2026, 4, 15),
        type: 'office',
        status: 'pending',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '保留票据',
        amountInCents: 6200,
        occurredOn: DateTime(2026, 4, 16),
        type: 'office',
        status: 'pending',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: TicketsPage())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TicketsPage)),
    );
    container.read(ticketShowAllProvider.notifier).showAll();
    container.read(ticketSelectionProvider.notifier).start();
    await container.read(ticketListProvider.future);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('ticket-card-$deleteTicketId')),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ticket-card-$deleteTicketId')));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 张票据'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-batch-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(
      (await ticketRepository.listTickets()).map((ticket) => ticket.title),
      ['保留票据'],
    );
    expect(find.text('待删票据'), findsNothing);
    expect(find.text('保留票据'), findsOneWidget);
    expect(find.text('已选 0 张票据'), findsOneWidget);
  });

  testWidgets('tickets page supports batch status update', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    final firstTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '状态票据 A',
        amountInCents: 2000,
        occurredOn: DateTime(2026, 4, 15),
        type: 'transport',
        status: 'pending',
      ),
    );
    final secondTicketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '状态票据 B',
        amountInCents: 2400,
        occurredOn: DateTime(2026, 4, 16),
        type: 'meal',
        status: 'pending',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: TicketsPage())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TicketsPage)),
    );
    container.read(ticketShowAllProvider.notifier).showAll();
    container.read(ticketSelectionProvider.notifier).start();
    await container.read(ticketListProvider.future);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('ticket-card-$firstTicketId')),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ticket-card-$firstTicketId')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('ticket-card-$secondTicketId')),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('ticket-card-$secondTicketId')));
    await tester.pumpAndSettle();

    expect(find.text('已选 2 张票据'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ticket-batch-status-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已提交').first);
    await tester.pumpAndSettle();

    final tickets = await ticketRepository.getTicketsByIds([
      firstTicketId,
      secondTicketId,
    ]);
    expect(tickets.map((ticket) => ticket.status), ['submitted', 'submitted']);
    expect(find.text('已选 0 张票据'), findsOneWidget);
  });

  testWidgets('tickets page supports sorting results by amount', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final ticketRepository = TicketRepository(database);
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '高金额票',
        amountInCents: 9600,
        occurredOn: DateTime(2026, 4, 15),
        type: 'office',
        status: 'submitted',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '低金额票',
        amountInCents: 1800,
        occurredOn: DateTime(2026, 4, 16),
        type: 'office',
        status: 'submitted',
      ),
    );
    await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '中金额票',
        amountInCents: 4200,
        occurredOn: DateTime(2026, 4, 17),
        type: 'office',
        status: 'submitted',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: TicketsPage())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TicketsPage)),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ticket-view-all-button')),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ticket-view-all-button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('ticket-sort-field-input')),
      -300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ticket-sort-field-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('按金额').last);
    await container.read(ticketListProvider.future);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ticket-sort-direction-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('升序').last);
    await container.read(ticketListProvider.future);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('低金额票'),
      300,
      scrollable: _ticketsScrollable(),
    );
    await tester.pumpAndSettle();

    final lowY = tester.getTopLeft(find.text('低金额票')).dy;
    final middleY = tester.getTopLeft(find.text('中金额票')).dy;
    final highY = tester.getTopLeft(find.text('高金额票')).dy;

    expect(lowY, lessThan(middleY));
    expect(middleY, lessThan(highY));
    expect(find.textContaining('排序：按金额 · 升序'), findsOneWidget);
  });

  testWidgets('ticket detail page shows reminder action', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = TicketRepository(database);
    final ticketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '餐饮发票',
        amountInCents: 6800,
        occurredOn: DateTime(2026, 4, 15),
        type: 'meal',
        status: 'pending',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: TicketDetailPage(ticketId: ticketId)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('创建提醒'), 300);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ticket-detail-page')), findsOneWidget);
    expect(find.text('创建提醒'), findsOneWidget);
  });

  testWidgets('reimbursements page renders local sheets from repository', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final repository = ReimbursementRepository(database);
    await repository.createReimbursementSheet(
      ReimbursementSheetsCompanion.insert(
        title: '四月差旅报销',
        status: const Value('draft'),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: Scaffold(body: ReimbursementsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('四月差旅报销'), findsOneWidget);
  });

  testWidgets('reimbursement detail page shows linked tickets and actions', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final reimbursementRepository = ReimbursementRepository(database);
    final ticketRepository = TicketRepository(database);

    final sheetId = await reimbursementRepository.createReimbursementSheet(
      ReimbursementSheetsCompanion.insert(
        title: '项目采购报销',
        status: const Value('submitted'),
      ),
    );
    final ticketId = await ticketRepository.createTicket(
      TicketsCompanion.insert(
        title: '显示器发票',
        amountInCents: 259900,
        occurredOn: DateTime(2026, 4, 16),
        type: 'office',
        status: 'submitted',
      ),
    );
    await reimbursementRepository.attachTicketToReimbursementSheet(
      ticketId: ticketId,
      reimbursementSheetId: sheetId,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          home: ReimbursementDetailPage(reimbursementSheetId: sheetId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('创建提醒'), 300);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reimbursement-detail-page')),
      findsOneWidget,
    );
    expect(find.text('显示器发票'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('创建提醒'), findsOneWidget);
  });
}
