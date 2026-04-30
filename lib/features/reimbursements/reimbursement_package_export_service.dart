import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_support.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';

const reimbursementPackageExportsDirectoryName = 'reimbursement_packages';

class ReimbursementPackageExportResult {
  const ReimbursementPackageExportResult({
    required this.fileName,
    required this.filePath,
    required this.ticketCount,
    required this.attachmentFileCount,
    required this.missingAttachmentCount,
  });

  final String fileName;
  final String filePath;
  final int ticketCount;
  final int attachmentFileCount;
  final int missingAttachmentCount;
}

class ReimbursementPackagePreview {
  const ReimbursementPackagePreview({
    required this.ticketCount,
    required this.availableAttachmentCount,
    required this.noAttachmentTicketCount,
    required this.missingAttachmentFileCount,
  });

  final int ticketCount;
  final int availableAttachmentCount;
  final int noAttachmentTicketCount;
  final int missingAttachmentFileCount;
}

class ReimbursementPackageExportService {
  ReimbursementPackageExportService({
    required ReimbursementCsvExportService csvExportService,
    Future<Directory> Function()? exportsDirectoryBuilder,
    DateTime Function()? nowBuilder,
  }) : _csvExportService = csvExportService,
       _exportsDirectoryBuilder =
           exportsDirectoryBuilder ?? _defaultExportsDirectory,
       _nowBuilder = nowBuilder ?? DateTime.now;

  final ReimbursementCsvExportService _csvExportService;
  final Future<Directory> Function() _exportsDirectoryBuilder;
  final DateTime Function() _nowBuilder;

  Future<ReimbursementPackagePreview> previewPackage({
    required List<Ticket> tickets,
  }) async {
    final inspection = await _inspectAttachments(tickets);

    return ReimbursementPackagePreview(
      ticketCount: tickets.length,
      availableAttachmentCount: inspection.availableAttachments.length,
      noAttachmentTicketCount: inspection.noAttachmentNotes.length,
      missingAttachmentFileCount: inspection.missingAttachmentNotes.length,
    );
  }

  Future<ReimbursementPackageExportResult> exportPackage({
    required ReimbursementSheet sheet,
    required List<Ticket> tickets,
  }) async {
    final exportsDirectory = await _exportsDirectoryBuilder();
    if (!await exportsDirectory.exists()) {
      await exportsDirectory.create(recursive: true);
    }

    final now = _nowBuilder();
    final fileName = _buildPackageFileName(sheet.title, now);
    final filePath = path.join(exportsDirectory.path, fileName);
    final archive = Archive()
      ..addFile(ArchiveFile.directory('reimbursement_package/'))
      ..addFile(ArchiveFile.directory('reimbursement_package/附件/'));

    final csvBytes = await _buildCsvBytes(sheet: sheet, tickets: tickets);
    archive.addFile(
      ArchiveFile('reimbursement_package/报销清单.csv', csvBytes.length, csvBytes),
    );

    final attachmentInspection = await _inspectAttachments(tickets);
    final usedAttachmentFileNames = <String>{};
    for (final attachment in attachmentInspection.availableAttachments) {
      final archiveFileName = _buildAttachmentFileName(
        ticket: attachment.ticket,
        sequence: attachment.sequence,
        usedFileNames: usedAttachmentFileNames,
      );
      await _addFileToArchive(
        archive: archive,
        file: attachment.file,
        archivePath: path.posix.join(
          'reimbursement_package',
          '附件',
          archiveFileName,
        ),
      );
    }

    final readmeBytes = utf8.encode(
      _buildReadme(
        sheet: sheet,
        tickets: tickets,
        attachmentInspection: attachmentInspection,
        generatedAt: now,
      ),
    );
    archive.addFile(
      ArchiveFile(
        'reimbursement_package/说明.txt',
        readmeBytes.length,
        readmeBytes,
      ),
    );

    final encodedBytes = ZipEncoder().encode(archive);
    await File(filePath).writeAsBytes(encodedBytes, flush: true);

    return ReimbursementPackageExportResult(
      fileName: fileName,
      filePath: filePath,
      ticketCount: tickets.length,
      attachmentFileCount: attachmentInspection.availableAttachments.length,
      missingAttachmentCount:
          attachmentInspection.noAttachmentNotes.length +
          attachmentInspection.missingAttachmentNotes.length,
    );
  }

  Future<Directory> exportsDirectory() {
    return _exportsDirectoryBuilder();
  }

  static Future<Directory> _defaultExportsDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    return Directory(
      path.join(
        temporaryDirectory.path,
        reimbursementPackageExportsDirectoryName,
      ),
    );
  }

  Future<List<int>> _buildCsvBytes({
    required ReimbursementSheet sheet,
    required List<Ticket> tickets,
  }) async {
    final csvResult = await _csvExportService.exportSheetTickets(
      sheetTitle: sheet.title,
      tickets: tickets,
    );
    final csvFile = File(csvResult.filePath);
    final bytes = await csvFile.readAsBytes();

    try {
      if (await csvFile.exists()) {
        await csvFile.delete();
      }
    } catch (_) {
      // The package export already has the CSV bytes; stale temp CSV cleanup is best effort.
    }

    return bytes;
  }

  Future<void> _addFileToArchive({
    required Archive archive,
    required File file,
    required String archivePath,
  }) async {
    final bytes = await file.readAsBytes();
    archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
  }

  String _buildReadme({
    required ReimbursementSheet sheet,
    required List<Ticket> tickets,
    required _PackageAttachmentInspection attachmentInspection,
    required DateTime generatedAt,
  }) {
    final missingAttachmentCount =
        attachmentInspection.noAttachmentNotes.length +
        attachmentInspection.missingAttachmentNotes.length;
    final lines = <String>[
      '报销材料包',
      '',
      '报销单：${sheet.title}',
      '状态：${reimbursementStatusLabel(sheet.status)}',
      '票据数量：${tickets.length}',
      '票据总金额：${formatTicketAmount(_sumTicketAmounts(tickets))}',
      '附件文件：${attachmentInspection.availableAttachments.length}',
      '缺失附件：$missingAttachmentCount',
      '生成时间：${formatTicketDate(generatedAt)}',
    ];

    if (attachmentInspection.noAttachmentNotes.isNotEmpty) {
      lines
        ..add('')
        ..add('未附加文件的票据：')
        ..addAll(attachmentInspection.noAttachmentNotes);
    }

    if (attachmentInspection.missingAttachmentNotes.isNotEmpty) {
      lines
        ..add('')
        ..add('附件文件缺失明细：')
        ..addAll(attachmentInspection.missingAttachmentNotes);
    }

    return lines.join('\n');
  }

  Future<_PackageAttachmentInspection> _inspectAttachments(
    List<Ticket> tickets,
  ) async {
    final availableAttachments = <_PackageAttachment>[];
    final noAttachmentNotes = <String>[];
    final missingAttachmentNotes = <String>[];

    for (var index = 0; index < tickets.length; index += 1) {
      final ticket = tickets[index];
      final sequence = (index + 1).toString().padLeft(3, '0');
      final filePath = ticket.filePath?.trim();

      if (filePath == null || filePath.isEmpty) {
        noAttachmentNotes.add('$sequence ${ticket.title}：未附加文件');
        continue;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        missingAttachmentNotes.add(
          '$sequence ${ticket.title}：文件不存在（$filePath）',
        );
        continue;
      }

      availableAttachments.add(
        _PackageAttachment(sequence: sequence, ticket: ticket, file: file),
      );
    }

    return _PackageAttachmentInspection(
      availableAttachments: availableAttachments,
      noAttachmentNotes: noAttachmentNotes,
      missingAttachmentNotes: missingAttachmentNotes,
    );
  }

  int _sumTicketAmounts(List<Ticket> tickets) {
    return tickets.fold<int>(0, (sum, ticket) => sum + ticket.amountInCents);
  }

  String _buildPackageFileName(String sheetTitle, DateTime dateTime) {
    final safeSheetTitle = _sanitizeFileName(sheetTitle, fallback: '未命名报销单');
    return '${safeSheetTitle}_${_dateStamp(dateTime)}_报销材料包.zip';
  }

  String _buildAttachmentFileName({
    required Ticket ticket,
    required String sequence,
    required Set<String> usedFileNames,
  }) {
    final safeTitle = _sanitizeFileName(ticket.title, fallback: '未命名票据');
    final extension = _resolveExtension(ticket);
    var fileName = '${sequence}_$safeTitle$extension';
    var suffix = 2;

    while (usedFileNames.contains(fileName)) {
      fileName = '${sequence}_${safeTitle}_$suffix$extension';
      suffix += 1;
    }

    usedFileNames.add(fileName);
    return fileName;
  }

  String _resolveExtension(Ticket ticket) {
    final fileNameExtension = path.extension(ticket.fileName ?? '');
    if (fileNameExtension.isNotEmpty) {
      return fileNameExtension;
    }

    final filePathExtension = path.extension(ticket.filePath ?? '');
    if (filePathExtension.isNotEmpty) {
      return filePathExtension;
    }

    if (ticket.fileType == 'pdf') {
      return '.pdf';
    }

    if (ticket.fileType == 'image') {
      return '.jpg';
    }

    return '';
  }

  String _sanitizeFileName(String input, {required String fallback}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    final sanitized = trimmed
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');
    if (sanitized.isEmpty) {
      return fallback;
    }

    final shortened = sanitized.length <= 80
        ? sanitized
        : sanitized.substring(0, 80);
    final cleaned = shortened.replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _dateStamp(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

class _PackageAttachmentInspection {
  const _PackageAttachmentInspection({
    required this.availableAttachments,
    required this.noAttachmentNotes,
    required this.missingAttachmentNotes,
  });

  final List<_PackageAttachment> availableAttachments;
  final List<String> noAttachmentNotes;
  final List<String> missingAttachmentNotes;
}

class _PackageAttachment {
  const _PackageAttachment({
    required this.sequence,
    required this.ticket,
    required this.file,
  });

  final String sequence;
  final Ticket ticket;
  final File file;
}
