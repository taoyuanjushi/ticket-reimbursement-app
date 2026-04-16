import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/ticket_repository.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';
import 'package:ticket_box/features/reminders/reminder_notification_service.dart';
import 'package:ticket_box/features/settings/local_maintenance_service.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

class _FakeTicketFileService extends TicketFileService {
  _FakeTicketFileService(this.directory);

  final Directory directory;

  @override
  Future<Directory> attachmentsDirectory() async => directory;
}

class _FakeReminderNotificationService extends ReminderNotificationService {
  bool cancelAllCalled = false;

  @override
  Future<void> cancelAllNotifications() async {
    cancelAllCalled = true;
  }
}

void main() {
  test(
    'detects invalid attachment references and clears only invalid metadata',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final tempDirectory = await Directory.systemTemp.createTemp(
        'ticket_box_local_maintenance_test',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final validFile = File(path.join(tempDirectory.path, 'valid.pdf'));
      await validFile.writeAsString('valid');

      final ticketRepository = TicketRepository(database);
      final validTicketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '有效附件票据',
          amountInCents: 5800,
          occurredOn: DateTime(2026, 4, 15),
          type: 'office',
          status: 'pending',
          filePath: Value(validFile.path),
          fileName: const Value('valid.pdf'),
          fileType: const Value('pdf'),
        ),
      );
      final invalidTicketId = await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '无效附件票据',
          amountInCents: 3200,
          occurredOn: DateTime(2026, 4, 14),
          type: 'meal',
          status: 'submitted',
          filePath: Value(path.join(tempDirectory.path, 'missing.pdf')),
          fileName: const Value('missing.pdf'),
          fileType: const Value('pdf'),
        ),
      );
      await ticketRepository.createTicket(
        TicketsCompanion.insert(
          title: '无附件票据',
          amountInCents: 1500,
          occurredOn: DateTime(2026, 4, 13),
          type: 'transport',
          status: 'pending',
        ),
      );

      final service = LocalMaintenanceService(
        ticketRepository: ticketRepository,
        ticketFileService: _FakeTicketFileService(tempDirectory),
        reimbursementCsvExportService: ReimbursementCsvExportService(
          exportsDirectoryBuilder: () async => tempDirectory,
        ),
        reminderNotificationService: _FakeReminderNotificationService(),
        databasePathResolver: () async =>
            path.join(tempDirectory.path, 'ticket_box.sqlite'),
      );

      final infoBeforeCleanup = await service.getMaintenanceInfo();
      expect(infoBeforeCleanup.invalidAttachmentCount, 1);

      final cleanedCount = await service.clearInvalidAttachmentReferences();
      expect(cleanedCount, 1);

      final validTicket = await ticketRepository.getTicketById(validTicketId);
      final invalidTicket = await ticketRepository.getTicketById(
        invalidTicketId,
      );

      expect(validTicket, isNotNull);
      expect(validTicket!.filePath, validFile.path);
      expect(validTicket.fileName, 'valid.pdf');
      expect(validTicket.fileType, 'pdf');
      expect(validFile.existsSync(), isTrue);

      expect(invalidTicket, isNotNull);
      expect(invalidTicket!.filePath, isNull);
      expect(invalidTicket.fileName, isNull);
      expect(invalidTicket.fileType, isNull);

      final infoAfterCleanup = await service.getMaintenanceInfo();
      expect(infoAfterCleanup.invalidAttachmentCount, 0);
    },
  );
}
