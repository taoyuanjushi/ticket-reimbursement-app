import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:ticket_box/features/settings/local_backup_export_service.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

class _FakeTicketFileService extends TicketFileService {
  _FakeTicketFileService(this.directory);

  final Directory directory;

  @override
  Future<Directory> attachmentsDirectory() async => directory;
}

void main() {
  test('exports a zip backup with database and attachment files', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'ticket_box_backup_export_test',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final databaseFile = File(
      path.join(tempDirectory.path, 'ticket_box.sqlite'),
    );
    await databaseFile.writeAsString('database-content');

    final attachmentsDirectory = Directory(
      path.join(tempDirectory.path, 'ticket_attachments'),
    );
    await attachmentsDirectory.create(recursive: true);
    await File(
      path.join(attachmentsDirectory.path, 'receipt.jpg'),
    ).writeAsString('image-content');
    final nestedDirectory = Directory(
      path.join(attachmentsDirectory.path, 'nested'),
    );
    await nestedDirectory.create(recursive: true);
    await File(
      path.join(nestedDirectory.path, 'invoice.pdf'),
    ).writeAsString('pdf-content');

    final exportsDirectory = Directory(
      path.join(tempDirectory.path, 'exports'),
    );

    final service = LocalBackupExportService(
      ticketFileService: _FakeTicketFileService(attachmentsDirectory),
      databasePathResolver: () async => databaseFile.path,
      exportsDirectoryBuilder: () async => exportsDirectory,
    );

    final result = await service.exportBackup();

    expect(result.fileName, endsWith('.zip'));
    expect(result.attachmentFileCount, 2);
    expect(File(result.filePath).existsSync(), isTrue);

    final archive = ZipDecoder().decodeBytes(
      await File(result.filePath).readAsBytes(),
    );
    final archivedNames = archive.files.map((file) => file.name).toSet();

    expect(archivedNames, contains('database/ticket_box.sqlite'));
    expect(archivedNames, contains('attachments/receipt.jpg'));
    expect(archivedNames, contains('attachments/nested/invoice.pdf'));
  });
}
