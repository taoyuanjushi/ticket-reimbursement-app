import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';

class TicketFilePreviewPage extends StatelessWidget {
  const TicketFilePreviewPage({
    required this.filePath,
    required this.fileName,
    required this.fileType,
    super.key,
  });

  final String filePath;
  final String fileName;
  final String fileType;

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    final exists = file.existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(isImageTicketFile(fileType) ? '图片预览' : 'PDF 附件'),
      ),
      body: SafeArea(
        child: exists
            ? isImageTicketFile(fileType)
                  ? _ImagePreview(filePath: filePath, fileName: fileName)
                  : _PdfPreview(filePath: filePath, fileName: fileName)
            : _MissingFileState(fileName: fileName),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          fileName,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '显示本地保存版本。',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            child: Image.file(File(filePath), fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 56,
                color: colors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                fileName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '当前仅显示文件信息。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SelectableText(
                filePath,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissingFileState extends StatelessWidget {
  const _MissingFileState({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              '未找到附件文件',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(fileName, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
