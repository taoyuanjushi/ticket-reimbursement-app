import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:ticket_box/features/settings/local_backup_export_service.dart';
import 'package:ticket_box/features/settings/local_backup_restore_service.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

class _FakeTicketFileService extends TicketFileService {
  _FakeTicketFileService(this.directory);

  final Directory directory;

  @override
  Future<Directory> attachmentsDirectory() async => directory;
}

void main() {
  test('restores database and attachments from a local backup zip', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'ticket_box_backup_restore_test',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final backupSourceDirectory = Directory(
      path.join(tempDirectory.path, 'backup_source'),
    );
    await backupSourceDirectory.create(recursive: true);
    final backupSourceDatabaseFile = File(
      path.join(backupSourceDirectory.path, 'ticket_box.sqlite'),
    );
    await backupSourceDatabaseFile.writeAsString('backup-database');

    final backupSourceAttachmentsDirectory = Directory(
      path.join(backupSourceDirectory.path, 'ticket_attachments'),
    );
    await backupSourceAttachmentsDirectory.create(recursive: true);
    await File(
      path.join(backupSourceAttachmentsDirectory.path, 'receipt.jpg'),
    ).writeAsString('backup-image');
    final nestedBackupDirectory = Directory(
      path.join(backupSourceAttachmentsDirectory.path, 'nested'),
    );
    await nestedBackupDirectory.create(recursive: true);
    await File(
      path.join(nestedBackupDirectory.path, 'invoice.pdf'),
    ).writeAsString('backup-pdf');

    final exportService = LocalBackupExportService(
      ticketFileService: _FakeTicketFileService(
        backupSourceAttachmentsDirectory,
      ),
      databasePathResolver: () async => backupSourceDatabaseFile.path,
      exportsDirectoryBuilder: () async =>
          Directory(path.join(tempDirectory.path, 'exports')),
    );
    final backupResult = await exportService.exportBackup();

    final liveDirectory = Directory(path.join(tempDirectory.path, 'live'));
    await liveDirectory.create(recursive: true);
    final liveDatabaseFile = File(
      path.join(liveDirectory.path, 'ticket_box.sqlite'),
    );
    await liveDatabaseFile.writeAsString('live-database');
    final liveAttachmentsDirectory = Directory(
      path.join(liveDirectory.path, 'ticket_attachments'),
    );
    await liveAttachmentsDirectory.create(recursive: true);
    await File(
      path.join(liveAttachmentsDirectory.path, 'old.txt'),
    ).writeAsString('old-attachment');

    final restoreService = LocalBackupRestoreService(
      ticketFileService: _FakeTicketFileService(liveAttachmentsDirectory),
      databasePathResolver: () async => liveDatabaseFile.path,
      workingDirectoryBuilder: () async =>
          Directory(path.join(tempDirectory.path, 'working')),
    );

    final inspection = await restoreService.inspectBackup(
      backupResult.filePath,
    );
    expect(inspection.attachmentFileCount, 2);

    final restoreResult = await restoreService.restoreBackup(
      backupResult.filePath,
    );

    expect(restoreResult.attachmentFileCount, 2);
    expect(await liveDatabaseFile.readAsString(), 'backup-database');
    expect(
      File(path.join(liveAttachmentsDirectory.path, 'old.txt')).existsSync(),
      isFalse,
    );
    expect(
      await File(
        path.join(liveAttachmentsDirectory.path, 'receipt.jpg'),
      ).readAsString(),
      'backup-image',
    );
    expect(
      await File(
        path.join(liveAttachmentsDirectory.path, 'nested', 'invoice.pdf'),
      ).readAsString(),
      'backup-pdf',
    );
  });

  test('invalid backup zip does not modify current local data', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'ticket_box_invalid_backup_restore_test',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final invalidArchive = Archive()
      ..addFile(ArchiveFile.string('notes.txt', 'not-a-backup'));
    final invalidBackupFile = File(
      path.join(tempDirectory.path, 'invalid.zip'),
    );
    await invalidBackupFile.writeAsBytes(ZipEncoder().encode(invalidArchive));

    final liveDirectory = Directory(path.join(tempDirectory.path, 'live'));
    await liveDirectory.create(recursive: true);
    final liveDatabaseFile = File(
      path.join(liveDirectory.path, 'ticket_box.sqlite'),
    );
    await liveDatabaseFile.writeAsString('live-database');
    final liveAttachmentsDirectory = Directory(
      path.join(liveDirectory.path, 'ticket_attachments'),
    );
    await liveAttachmentsDirectory.create(recursive: true);
    final liveAttachmentFile = File(
      path.join(liveAttachmentsDirectory.path, 'keep.txt'),
    );
    await liveAttachmentFile.writeAsString('keep-me');

    final restoreService = LocalBackupRestoreService(
      ticketFileService: _FakeTicketFileService(liveAttachmentsDirectory),
      databasePathResolver: () async => liveDatabaseFile.path,
      workingDirectoryBuilder: () async =>
          Directory(path.join(tempDirectory.path, 'working')),
    );

    await expectLater(
      () => restoreService.restoreBackup(invalidBackupFile.path),
      throwsA(isA<LocalBackupValidationException>()),
    );

    expect(await liveDatabaseFile.readAsString(), 'live-database');
    expect(await liveAttachmentFile.readAsString(), 'keep-me');
  });
}
