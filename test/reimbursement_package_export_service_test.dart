import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_csv_export_service.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_package_export_service.dart';

void main() {
  test(
    'previews and exports a reimbursement package with clear safe file names',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'ticket_box_package_export_test',
      );
      final csvDirectory = Directory('${tempDirectory.path}/csv');
      final packageDirectory = Directory('${tempDirectory.path}/packages');
      final attachmentDirectory = Directory(
        '${tempDirectory.path}/attachments',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      await attachmentDirectory.create(recursive: true);
      final imageFile = File('${attachmentDirectory.path}/receipt.JPG');
      await imageFile.writeAsBytes([1, 2, 3, 4]);
      final pdfFile = File('${attachmentDirectory.path}/fallback.pdf');
      await pdfFile.writeAsBytes([5, 6, 7, 8]);

      final service = ReimbursementPackageExportService(
        csvExportService: ReimbursementCsvExportService(
          exportsDirectoryBuilder: () async => csvDirectory,
        ),
        exportsDirectoryBuilder: () async => packageDirectory,
        nowBuilder: () => DateTime(2026, 4, 29, 10, 30, 5),
      );
      final tickets = [
        Ticket(
          id: 1,
          title: '高铁/票',
          amountInCents: 12850,
          occurredOn: DateTime(2026, 4, 15),
          type: 'transport',
          status: 'submitted',
          note: null,
          filePath: imageFile.path,
          fileName: '原始.JPG',
          fileType: 'image',
          reimbursementSheetId: 1,
          createdAt: DateTime(2026, 4, 15),
          updatedAt: DateTime(2026, 4, 15),
        ),
        Ticket(
          id: 2,
          title: '住宿票据',
          amountInCents: 36000,
          occurredOn: DateTime(2026, 4, 16),
          type: 'travel',
          status: 'submitted',
          note: null,
          filePath: '${attachmentDirectory.path}/missing.pdf',
          fileName: '住宿票据.pdf',
          fileType: 'pdf',
          reimbursementSheetId: 1,
          createdAt: DateTime(2026, 4, 16),
          updatedAt: DateTime(2026, 4, 16),
        ),
        Ticket(
          id: 3,
          title: '餐饮票据',
          amountInCents: 6800,
          occurredOn: DateTime(2026, 4, 17),
          type: 'meal',
          status: 'submitted',
          note: null,
          filePath: null,
          fileName: null,
          fileType: null,
          reimbursementSheetId: 1,
          createdAt: DateTime(2026, 4, 17),
          updatedAt: DateTime(2026, 4, 17),
        ),
        Ticket(
          id: 4,
          title: '///',
          amountInCents: 9900,
          occurredOn: DateTime(2026, 4, 18),
          type: 'office',
          status: 'submitted',
          note: null,
          filePath: pdfFile.path,
          fileName: null,
          fileType: 'pdf',
          reimbursementSheetId: 1,
          createdAt: DateTime(2026, 4, 18),
          updatedAt: DateTime(2026, 4, 18),
        ),
      ];

      final preview = await service.previewPackage(tickets: tickets);

      expect(preview.ticketCount, 4);
      expect(preview.availableAttachmentCount, 2);
      expect(preview.noAttachmentTicketCount, 1);
      expect(preview.missingAttachmentFileCount, 1);

      final result = await service.exportPackage(
        sheet: ReimbursementSheet(
          id: 1,
          title: '四月/差旅:报销',
          status: 'submitted',
          description: null,
          submittedAt: null,
          reimbursedAt: null,
          createdAt: DateTime(2026, 4, 29),
          updatedAt: DateTime(2026, 4, 29),
        ),
        tickets: tickets,
      );

      expect(result.fileName, '四月_差旅_报销_2026-04-29_报销材料包.zip');
      expect(File(result.filePath).existsSync(), isTrue);
      expect(result.ticketCount, 4);
      expect(result.attachmentFileCount, 2);
      expect(result.missingAttachmentCount, 2);

      final archive = ZipDecoder().decodeBytes(
        await File(result.filePath).readAsBytes(),
      );
      final archivedNames = archive.files.map((file) => file.name).toSet();

      expect(archivedNames, contains('reimbursement_package/报销清单.csv'));
      expect(archivedNames, contains('reimbursement_package/说明.txt'));
      expect(archivedNames, contains('reimbursement_package/附件/001_高铁_票.JPG'));
      expect(archivedNames, contains('reimbursement_package/附件/004_未命名票据.pdf'));

      final csvEntry = archive.files.singleWhere(
        (file) => file.name == 'reimbursement_package/报销清单.csv',
      );
      final csvContent = utf8.decode(csvEntry.content);
      expect(csvContent, contains('高铁/票'));
      expect(csvContent, contains('住宿票据'));
      expect(csvContent, contains('餐饮票据'));

      final readmeEntry = archive.files.singleWhere(
        (file) => file.name == 'reimbursement_package/说明.txt',
      );
      final readme = utf8.decode(readmeEntry.content);
      expect(readme, contains('报销单：四月/差旅:报销'));
      expect(readme, contains('附件文件：2'));
      expect(readme, contains('缺失附件：2'));
      expect(readme, contains('002 住宿票据：文件不存在'));
      expect(readme, contains('003 餐饮票据：未附加文件'));
    },
  );

  test(
    'uses a safe fallback package name when the sheet title is invalid',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'ticket_box_package_name_test',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final service = ReimbursementPackageExportService(
        csvExportService: ReimbursementCsvExportService(
          exportsDirectoryBuilder: () async =>
              Directory('${tempDirectory.path}/csv'),
        ),
        exportsDirectoryBuilder: () async =>
            Directory('${tempDirectory.path}/packages'),
        nowBuilder: () => DateTime(2026, 4, 29),
      );

      final result = await service.exportPackage(
        sheet: ReimbursementSheet(
          id: 1,
          title: '///',
          status: 'draft',
          description: null,
          submittedAt: null,
          reimbursedAt: null,
          createdAt: DateTime(2026, 4, 29),
          updatedAt: DateTime(2026, 4, 29),
        ),
        tickets: const [],
      );

      expect(result.fileName, '未命名报销单_2026-04-29_报销材料包.zip');
    },
  );
}
