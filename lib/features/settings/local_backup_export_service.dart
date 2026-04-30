import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

const localBackupDatabaseDirectoryName = 'database';
const localBackupAttachmentsDirectoryName = 'attachments';
const localBackupExportsDirectoryName = 'backup_exports';

class LocalBackupExportResult {
  const LocalBackupExportResult({
    required this.fileName,
    required this.filePath,
    required this.attachmentFileCount,
  });

  final String fileName;
  final String filePath;
  final int attachmentFileCount;
}

class LocalBackupExportService {
  LocalBackupExportService({
    required TicketFileService ticketFileService,
    Future<String> Function()? databasePathResolver,
    Future<Directory> Function()? exportsDirectoryBuilder,
  }) : _attachmentsDirectoryBuilder = ticketFileService.attachmentsDirectory,
       _databasePathResolver =
           databasePathResolver ?? AppDatabase.resolveDefaultPath,
       _exportsDirectoryBuilder =
           exportsDirectoryBuilder ?? _defaultExportsDirectory;

  final Future<Directory> Function() _attachmentsDirectoryBuilder;
  final Future<String> Function() _databasePathResolver;
  final Future<Directory> Function() _exportsDirectoryBuilder;

  Future<LocalBackupExportResult> exportBackup() async {
    final databasePath = await _databasePathResolver();
    final databaseFile = File(databasePath);
    if (!await databaseFile.exists()) {
      throw FileSystemException('Database file not found', databasePath);
    }

    final attachmentsDirectory = await _attachmentsDirectoryBuilder();
    final exportDirectory = await _exportsDirectoryBuilder();
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    final fileName = '票据盒备份_${_timestamp(DateTime.now())}.zip';
    final filePath = path.join(exportDirectory.path, fileName);

    final archive = Archive();
    await _addFileToArchive(
      archive: archive,
      file: databaseFile,
      archivePath: path.posix.join(
        localBackupDatabaseDirectoryName,
        path.basename(databasePath),
      ),
    );

    var attachmentFileCount = 0;
    if (await attachmentsDirectory.exists()) {
      await for (final entity in attachmentsDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) {
          continue;
        }

        final relativePath = path.relative(
          entity.path,
          from: attachmentsDirectory.path,
        );
        final archivePath = path.posix.join(
          localBackupAttachmentsDirectoryName,
          path.split(relativePath).join('/'),
        );
        await _addFileToArchive(
          archive: archive,
          file: entity,
          archivePath: archivePath,
        );
        attachmentFileCount += 1;
      }
    }

    final encodedBytes = ZipEncoder().encode(archive);
    await File(filePath).writeAsBytes(encodedBytes, flush: true);

    return LocalBackupExportResult(
      fileName: fileName,
      filePath: filePath,
      attachmentFileCount: attachmentFileCount,
    );
  }

  Future<Directory> exportsDirectory() {
    return _exportsDirectoryBuilder();
  }

  static Future<Directory> _defaultExportsDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    return Directory(
      path.join(temporaryDirectory.path, localBackupExportsDirectoryName),
    );
  }

  Future<void> _addFileToArchive({
    required Archive archive,
    required File file,
    required String archivePath,
  }) async {
    final bytes = await file.readAsBytes();
    archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
  }

  String _timestamp(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    return '$year$month$day-$hour$minute$second';
  }
}
