import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/settings/local_backup_export_service.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';

class LocalBackupValidationException implements Exception {
  const LocalBackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalBackupInspectionResult {
  const LocalBackupInspectionResult({
    required this.fileName,
    required this.filePath,
    required this.attachmentFileCount,
  });

  final String fileName;
  final String filePath;
  final int attachmentFileCount;
}

class LocalBackupRestoreResult {
  const LocalBackupRestoreResult({
    required this.fileName,
    required this.attachmentFileCount,
  });

  final String fileName;
  final int attachmentFileCount;
}

class LocalBackupRestoreService {
  LocalBackupRestoreService({
    required TicketFileService ticketFileService,
    Future<String> Function()? databasePathResolver,
    Future<Directory> Function()? workingDirectoryBuilder,
    Future<String?> Function()? backupFilePicker,
  }) : _attachmentsDirectoryBuilder = ticketFileService.attachmentsDirectory,
       _databasePathResolver =
           databasePathResolver ?? AppDatabase.resolveDefaultPath,
       _workingDirectoryBuilder =
           workingDirectoryBuilder ?? _defaultWorkingDirectory,
       _backupFilePicker = backupFilePicker ?? _defaultBackupFilePicker;

  final Future<Directory> Function() _attachmentsDirectoryBuilder;
  final Future<String> Function() _databasePathResolver;
  final Future<Directory> Function() _workingDirectoryBuilder;
  final Future<String?> Function() _backupFilePicker;

  Future<String?> pickBackupFilePath() {
    return _backupFilePicker();
  }

  Future<LocalBackupInspectionResult> inspectBackup(
    String backupFilePath,
  ) async {
    final archive = await _decodeArchive(backupFilePath);
    final backupContent = _inspectArchive(archive, backupFilePath);

    return LocalBackupInspectionResult(
      fileName: path.basename(backupFilePath),
      filePath: backupFilePath,
      attachmentFileCount: backupContent.attachmentFileCount,
    );
  }

  Future<LocalBackupRestoreResult> restoreBackup(String backupFilePath) async {
    final workingDirectory = await _workingDirectoryBuilder();
    await workingDirectory.create(recursive: true);

    final sessionDirectory = Directory(
      path.join(
        workingDirectory.path,
        'backup_restore_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await sessionDirectory.create(recursive: true);

    final backupFileName = path.basename(backupFilePath);

    try {
      final archive = await _decodeArchive(backupFilePath);
      final backupContent = _inspectArchive(archive, backupFilePath);
      final extractedBackup = await _extractBackup(
        archive: archive,
        backupContent: backupContent,
        sessionDirectory: sessionDirectory,
      );

      final databasePath = await _databasePathResolver();
      final liveDatabaseFile = File(databasePath);
      final liveDatabaseDirectory = Directory(path.dirname(databasePath));
      final liveAttachmentsDirectory = await _attachmentsDirectoryBuilder();

      final liveBackupDirectory = Directory(
        path.join(sessionDirectory.path, 'live_backup'),
      );
      final liveDatabaseBackupFile = File(
        path.join(liveBackupDirectory.path, path.basename(databasePath)),
      );
      final liveAttachmentsBackupDirectory = Directory(
        path.join(
          liveBackupDirectory.path,
          localBackupAttachmentsDirectoryName,
        ),
      );

      final hadLiveDatabase = await liveDatabaseFile.exists();
      final hadLiveAttachments = await liveAttachmentsDirectory.exists();

      if (hadLiveDatabase) {
        await liveBackupDirectory.create(recursive: true);
        await liveDatabaseFile.copy(liveDatabaseBackupFile.path);
      }

      if (hadLiveAttachments) {
        await _copyDirectory(
          source: liveAttachmentsDirectory,
          destination: liveAttachmentsBackupDirectory,
        );
      }

      try {
        await liveDatabaseDirectory.create(recursive: true);
        if (await liveDatabaseFile.exists()) {
          await liveDatabaseFile.delete();
        }
        await extractedBackup.databaseFile.copy(liveDatabaseFile.path);

        if (await liveAttachmentsDirectory.exists()) {
          await liveAttachmentsDirectory.delete(recursive: true);
        }
        await liveAttachmentsDirectory.create(recursive: true);
        await _copyDirectoryContents(
          source: extractedBackup.attachmentsDirectory,
          destination: liveAttachmentsDirectory,
        );
      } catch (_) {
        await _rollbackLiveFiles(
          liveDatabaseFile: liveDatabaseFile,
          liveAttachmentsDirectory: liveAttachmentsDirectory,
          liveDatabaseBackupFile: liveDatabaseBackupFile,
          liveAttachmentsBackupDirectory: liveAttachmentsBackupDirectory,
          hadLiveDatabase: hadLiveDatabase,
          hadLiveAttachments: hadLiveAttachments,
        );
        rethrow;
      }

      return LocalBackupRestoreResult(
        fileName: backupFileName,
        attachmentFileCount: extractedBackup.attachmentFileCount,
      );
    } finally {
      if (await sessionDirectory.exists()) {
        await sessionDirectory.delete(recursive: true);
      }
    }
  }

  Future<Archive> _decodeArchive(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw const LocalBackupValidationException('备份文件不存在');
    }

    try {
      final bytes = await backupFile.readAsBytes();
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const LocalBackupValidationException('所选文件不是可用的本地备份');
    }
  }

  _BackupArchiveContent _inspectArchive(
    Archive archive,
    String backupFilePath,
  ) {
    ArchiveFile? databaseEntry;
    var attachmentFileCount = 0;

    for (final entry in archive.files) {
      final normalizedPath = _normalizeArchivePath(entry.name);
      if (entry.isDirectory) {
        continue;
      }

      if (entry.isSymbolicLink) {
        throw const LocalBackupValidationException('备份文件结构无效');
      }

      if (normalizedPath.startsWith('$localBackupDatabaseDirectoryName/')) {
        if (databaseEntry != null) {
          throw const LocalBackupValidationException('备份中包含多个数据库文件');
        }
        databaseEntry = entry;
        continue;
      }

      if (normalizedPath.startsWith('$localBackupAttachmentsDirectoryName/')) {
        attachmentFileCount += 1;
        continue;
      }

      throw LocalBackupValidationException(
        '所选文件不是可用的本地备份：${path.basename(backupFilePath)}',
      );
    }

    if (databaseEntry == null) {
      throw const LocalBackupValidationException('备份中缺少数据库文件');
    }

    return _BackupArchiveContent(
      databaseEntry: databaseEntry,
      attachmentFileCount: attachmentFileCount,
    );
  }

  Future<_ExtractedBackup> _extractBackup({
    required Archive archive,
    required _BackupArchiveContent backupContent,
    required Directory sessionDirectory,
  }) async {
    final extractRoot = Directory(path.join(sessionDirectory.path, 'extract'));
    await extractRoot.create(recursive: true);

    for (final entry in archive.files) {
      final normalizedPath = _normalizeArchivePath(entry.name);
      if (entry.isDirectory) {
        continue;
      }

      if (!normalizedPath.startsWith('$localBackupDatabaseDirectoryName/') &&
          !normalizedPath.startsWith('$localBackupAttachmentsDirectoryName/')) {
        continue;
      }

      final outputPath = path.join(
        extractRoot.path,
        path.joinAll(path.posix.split(normalizedPath)),
      );
      final normalizedOutputPath = path.normalize(outputPath);
      if (!path.isWithin(extractRoot.path, normalizedOutputPath) &&
          normalizedOutputPath != path.normalize(extractRoot.path)) {
        throw const LocalBackupValidationException('备份文件结构无效');
      }

      final outputFile = File(normalizedOutputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(entry.content, flush: true);
    }

    final extractedDatabaseFile = File(
      path.join(
        extractRoot.path,
        path.joinAll(
          path.posix.split(
            _normalizeArchivePath(backupContent.databaseEntry.name),
          ),
        ),
      ),
    );
    if (!await extractedDatabaseFile.exists()) {
      throw const LocalBackupValidationException('备份中的数据库文件无效');
    }

    final extractedAttachmentsDirectory = Directory(
      path.join(extractRoot.path, localBackupAttachmentsDirectoryName),
    );
    if (!await extractedAttachmentsDirectory.exists()) {
      await extractedAttachmentsDirectory.create(recursive: true);
    }

    return _ExtractedBackup(
      databaseFile: extractedDatabaseFile,
      attachmentsDirectory: extractedAttachmentsDirectory,
      attachmentFileCount: backupContent.attachmentFileCount,
    );
  }

  Future<void> _rollbackLiveFiles({
    required File liveDatabaseFile,
    required Directory liveAttachmentsDirectory,
    required File liveDatabaseBackupFile,
    required Directory liveAttachmentsBackupDirectory,
    required bool hadLiveDatabase,
    required bool hadLiveAttachments,
  }) async {
    if (hadLiveDatabase && await liveDatabaseBackupFile.exists()) {
      await liveDatabaseFile.parent.create(recursive: true);
      if (await liveDatabaseFile.exists()) {
        await liveDatabaseFile.delete();
      }
      await liveDatabaseBackupFile.copy(liveDatabaseFile.path);
    } else if (await liveDatabaseFile.exists()) {
      await liveDatabaseFile.delete();
    }

    if (hadLiveAttachments && await liveAttachmentsBackupDirectory.exists()) {
      if (await liveAttachmentsDirectory.exists()) {
        await liveAttachmentsDirectory.delete(recursive: true);
      }
      await _copyDirectory(
        source: liveAttachmentsBackupDirectory,
        destination: liveAttachmentsDirectory,
      );
    } else if (await liveAttachmentsDirectory.exists()) {
      await liveAttachmentsDirectory.delete(recursive: true);
    }
  }

  Future<void> _copyDirectory({
    required Directory source,
    required Directory destination,
  }) async {
    if (!await source.exists()) {
      return;
    }

    await destination.create(recursive: true);
    await _copyDirectoryContents(source: source, destination: destination);
  }

  Future<void> _copyDirectoryContents({
    required Directory source,
    required Directory destination,
  }) async {
    if (!await source.exists()) {
      return;
    }

    await destination.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = path.relative(entity.path, from: source.path);
      final targetPath = path.join(destination.path, relativePath);

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
        continue;
      }

      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  String _normalizeArchivePath(String rawPath) {
    final normalizedPath = path.posix.normalize(rawPath.replaceAll('\\', '/'));
    if (normalizedPath == '.' ||
        normalizedPath.isEmpty ||
        normalizedPath == '..' ||
        normalizedPath.startsWith('../') ||
        path.posix.isAbsolute(normalizedPath)) {
      throw const LocalBackupValidationException('备份文件结构无效');
    }

    return normalizedPath;
  }

  static Future<String?> _defaultBackupFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single.path;
  }

  static Future<Directory> _defaultWorkingDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    return Directory(path.join(temporaryDirectory.path, 'backup_restore_work'));
  }
}

class _BackupArchiveContent {
  const _BackupArchiveContent({
    required this.databaseEntry,
    required this.attachmentFileCount,
  });

  final ArchiveFile databaseEntry;
  final int attachmentFileCount;
}

class _ExtractedBackup {
  const _ExtractedBackup({
    required this.databaseFile,
    required this.attachmentsDirectory,
    required this.attachmentFileCount,
  });

  final File databaseFile;
  final Directory attachmentsDirectory;
  final int attachmentFileCount;
}
