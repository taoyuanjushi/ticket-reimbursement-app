import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/inspections/ticket_completeness_inspection_service.dart';

void main() {
  test('detects incomplete ticket records without changing data', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final tempDirectory = await Directory.systemTemp.createTemp(
      'ticket_box_completeness_test',
    );
    addTearDown(database.close);
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final repository = TicketRepository(database);
    final emptyTicketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '',
        amountInCents: 0,
        occurredOn: DateTime(2026, 4, 15),
        type: 'other',
        status: 'pending',
      ),
    );
    final missingFileTicketId = await repository.createTicket(
      TicketsCompanion.insert(
        title: '住宿票据',
        amountInCents: 36000,
        occurredOn: DateTime(2026, 4, 16),
        type: 'travel',
        status: 'pending',
        filePath: Value('${tempDirectory.path}/missing.pdf'),
        fileName: const Value('missing.pdf'),
        fileType: const Value('pdf'),
      ),
    );
    await repository.createTicket(
      TicketsCompanion.insert(
        title: '正常票据',
        amountInCents: 6800,
        occurredOn: DateTime(2026, 4, 17),
        type: 'meal',
        status: 'submitted',
      ),
    );

    final service = TicketCompletenessInspectionService(repository);
    final result = await service.inspect();

    expect(result.incompleteTicketCount, 2);
    expect(result.totalIssueCount, 4);
    expect(result.issueCountsByType[TicketCompletenessIssueType.emptyTitle], 1);
    expect(
      result.issueCountsByType[TicketCompletenessIssueType.missingAmount],
      1,
    );
    expect(
      result.issueCountsByType[TicketCompletenessIssueType
          .pendingWithoutAttachment],
      1,
    );
    expect(
      result.issueCountsByType[TicketCompletenessIssueType
          .missingAttachmentFile],
      1,
    );
    expect(result.records.map((record) => record.ticket.id).toSet(), {
      emptyTicketId,
      missingFileTicketId,
    });
    expect((await repository.listTickets()).length, 3);
  });
}
