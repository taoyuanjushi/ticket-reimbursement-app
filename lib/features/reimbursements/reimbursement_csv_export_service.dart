import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';

class ReimbursementCsvExportResult {
  const ReimbursementCsvExportResult({
    required this.fileName,
    required this.filePath,
    required this.exportedCount,
  });

  final String fileName;
  final String filePath;
  final int exportedCount;
}

class ReimbursementCsvExportService {
  ReimbursementCsvExportService({
    Future<Directory> Function()? exportsDirectoryBuilder,
  }) : _exportsDirectoryBuilder =
           exportsDirectoryBuilder ?? _defaultExportsDirectory;

  final Future<Directory> Function() _exportsDirectoryBuilder;

  Future<ReimbursementCsvExportResult> exportSheetTickets({
    required String sheetTitle,
    required List<Ticket> tickets,
  }) async {
    final exportsDirectory = await _exportsDirectoryBuilder();
    if (!await exportsDirectory.exists()) {
      await exportsDirectory.create(recursive: true);
    }

    final timestamp = _timestamp(DateTime.now());
    final safeSheetTitle = _sanitizeFileName(sheetTitle);
    final fileName = '报销单_${safeSheetTitle}_$timestamp.csv';
    final filePath = path.join(exportsDirectory.path, fileName);
    final file = File(filePath);

    final rows = <List<String>>[
      const ['标题', '金额', '日期', '类型', '状态', '备注', '文件名', '文件类型'],
      for (final ticket in tickets)
        [
          ticket.title,
          formatTicketAmountInput(ticket.amountInCents),
          formatTicketDate(ticket.occurredOn),
          ticketTypeLabel(ticket.type),
          ticketStatusLabel(ticket.status),
          ticket.note ?? '',
          ticket.fileName ?? '',
          ticket.fileType == null ? '' : ticketFileTypeLabel(ticket.fileType),
        ],
    ];

    final csvContent = rows.map(_buildCsvRow).join('\n');
    await file.writeAsBytes(utf8.encode('\uFEFF$csvContent'), flush: true);

    return ReimbursementCsvExportResult(
      fileName: fileName,
      filePath: filePath,
      exportedCount: tickets.length,
    );
  }

  Future<Directory> exportsDirectory() {
    return _exportsDirectoryBuilder();
  }

  Future<int> clearExportedCsvFiles() async {
    final exportsDirectory = await _exportsDirectoryBuilder();
    if (!await exportsDirectory.exists()) {
      return 0;
    }

    var deletedCount = 0;
    await for (final entity in exportsDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      if (path.extension(entity.path).toLowerCase() != '.csv') {
        continue;
      }

      await entity.delete();
      deletedCount += 1;
    }

    return deletedCount;
  }

  static Future<Directory> _defaultExportsDirectory() async {
    final temporaryDirectory = await getTemporaryDirectory();
    return Directory(
      path.join(temporaryDirectory.path, 'reimbursement_exports'),
    );
  }

  String _buildCsvRow(List<String> values) {
    return values.map(_escapeCsvValue).join(',');
  }

  String _escapeCsvValue(String value) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final escaped = normalized.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _sanitizeFileName(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '未命名报销单';
    }

    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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
