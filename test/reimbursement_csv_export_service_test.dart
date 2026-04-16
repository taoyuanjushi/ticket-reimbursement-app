import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';

void main() {
  test(
    'exports linked tickets to a local csv file with chinese headers',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'ticket_box_csv_export_test',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final service = ReimbursementCsvExportService(
        exportsDirectoryBuilder: () async => tempDirectory,
      );

      final result = await service.exportSheetTickets(
        sheetTitle: '四月差旅报销',
        tickets: [
          Ticket(
            id: 1,
            title: '高铁票',
            amountInCents: 12850,
            occurredOn: DateTime(2026, 4, 15),
            type: 'transport',
            status: 'submitted',
            note: '往返客户现场',
            filePath: 'D:/exports/ticket_1.pdf',
            fileName: '高铁票.pdf',
            fileType: 'pdf',
            reimbursementSheetId: 3,
            createdAt: DateTime(2026, 4, 15, 8),
            updatedAt: DateTime(2026, 4, 15, 9),
          ),
        ],
      );

      expect(File(result.filePath).existsSync(), isTrue);
      expect(result.fileName, contains('四月差旅报销'));
      expect(result.exportedCount, 1);

      final content = utf8.decode(await File(result.filePath).readAsBytes());
      final normalized = content.replaceFirst('\uFEFF', '');

      expect(
        normalized,
        contains('"标题","金额","日期","类型","状态","备注","文件名","文件类型"'),
      );
      expect(
        normalized,
        contains(
          '"高铁票","128.50","2026-04-15","交通","已提交","往返客户现场","高铁票.pdf","PDF"',
        ),
      );
    },
  );
}
