import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';
import 'package:ticket_box/features/tickets/ticket_providers.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';

class TicketFormPage extends ConsumerStatefulWidget {
  const TicketFormPage({this.initialTicket, super.key});

  final Ticket? initialTicket;

  @override
  ConsumerState<TicketFormPage> createState() => _TicketFormPageState();
}

class _TicketFormPageState extends ConsumerState<TicketFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedType;
  String? _selectedStatus;
  bool _isSaving = false;
  _TicketAttachmentDraft? _attachment;

  bool get _isEditing => widget.initialTicket != null;

  @override
  void initState() {
    super.initState();

    final initialTicket = widget.initialTicket;
    if (initialTicket == null) {
      _selectedDate = DateTime.now();
      _selectedType = ticketTypeOptions.first.value;
      _selectedStatus = ticketStatusOptions.first.value;
    } else {
      _titleController.text = initialTicket.title;
      _amountController.text = formatTicketAmountInput(
        initialTicket.amountInCents,
      );
      _selectedDate = initialTicket.occurredOn;
      _selectedType = initialTicket.type;
      _selectedStatus = initialTicket.status;
      _noteController.text = initialTicket.note ?? '';

      if ((initialTicket.filePath ?? '').trim().isNotEmpty) {
        _attachment = _TicketAttachmentDraft.stored(
          filePath: initialTicket.filePath!,
          fileName: resolveTicketFileName(
            fileName: initialTicket.fileName,
            filePath: initialTicket.filePath,
          ),
          fileType: resolveTicketFileType(
            fileType: initialTicket.fileType,
            fileName: initialTicket.fileName,
            filePath: initialTicket.filePath,
          ),
        );
      }
    }

    _dateController.text = formatTicketDate(_selectedDate!);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑票据' : '新增票据')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? '更新票据信息' : '录入票据',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '只保留必要字段，附件会保存到本地。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '例如：高铁票',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return '请输入标题';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: '金额',
                        hintText: '例如：128.50',
                        prefixText: '¥ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final amountInCents = parseAmountInCents(value ?? '');
                        if (amountInCents == null || amountInCents <= 0) {
                          return '请输入正确金额';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '日期',
                        suffixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      onTap: _pickDate,
                      validator: (_) {
                        if (_selectedDate == null) {
                          return '请选择日期';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: '类型'),
                      items: [
                        for (final option in ticketTypeOptions)
                          DropdownMenuItem<String>(
                            value: option.value,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请选择类型';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: [
                        for (final option in ticketStatusOptions)
                          DropdownMenuItem<String>(
                            value: option.value,
                            child: Text(option.label),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请选择状态';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        hintText: '可选',
                      ),
                      maxLines: 4,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 20),
                    _AttachmentSection(
                      attachment: _attachment,
                      onPickImage: _pickImage,
                      onPickPdf: _pickPdf,
                      onRemove: _removeAttachment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _saveTicket,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? '保存中...' : (_isEditing ? '更新票据' : '保存票据')),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      locale: const Locale('zh', 'CN'),
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
      _dateController.text = formatTicketDate(pickedDate);
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ref.read(ticketFileServiceProvider).pickImage();
    if (pickedFile == null || !mounted) {
      return;
    }

    setState(() {
      _attachment = _TicketAttachmentDraft.imported(
        sourcePath: pickedFile.sourcePath,
        fileName: pickedFile.fileName,
        fileType: pickedFile.fileType,
      );
    });
  }

  Future<void> _pickPdf() async {
    final pickedFile = await ref.read(ticketFileServiceProvider).pickPdf();
    if (pickedFile == null || !mounted) {
      return;
    }

    setState(() {
      _attachment = _TicketAttachmentDraft.imported(
        sourcePath: pickedFile.sourcePath,
        fileName: pickedFile.fileName,
        fileType: pickedFile.fileType,
      );
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachment = null;
    });
  }

  Future<void> _saveTicket() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final attachmentValidationMessage = _validateAttachmentDraft();
    if (attachmentValidationMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(attachmentValidationMessage)));
      return;
    }

    final amountInCents = parseAmountInCents(_amountController.text);
    if (amountInCents == null || amountInCents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确金额')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repository = ref.read(ticketRepositoryProvider);
    final fileService = ref.read(ticketFileServiceProvider);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final initialTicket = widget.initialTicket;
    final existingFilePath = initialTicket?.filePath;
    final linkedSheetId = initialTicket?.reimbursementSheetId;
    TicketStoredFile? storedFile;
    var createdNewFile = false;

    try {
      if (_attachment != null) {
        if (_attachment!.isStored) {
          storedFile = TicketStoredFile(
            filePath: _attachment!.storedPath!,
            fileName: _attachment!.fileName,
            fileType: _attachment!.fileType,
          );
        } else {
          storedFile = await fileService.importFile(
            TicketImportedFile(
              sourcePath: _attachment!.sourcePath!,
              fileName: _attachment!.fileName,
              fileType: _attachment!.fileType,
            ),
          );
          createdNewFile = true;
        }
      }

      if (_isEditing) {
        await repository.updateTicket(
          Ticket(
            id: initialTicket!.id,
            title: _titleController.text.trim(),
            amountInCents: amountInCents,
            occurredOn: _selectedDate!,
            type: _selectedType!,
            status: _selectedStatus!,
            note: note,
            filePath: storedFile?.filePath,
            fileName: storedFile?.fileName,
            fileType: storedFile?.fileType,
            reimbursementSheetId: initialTicket.reimbursementSheetId,
            createdAt: initialTicket.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
        ref.invalidate(ticketByIdProvider(initialTicket.id));
      } else {
        await repository.createTicket(
          TicketsCompanion.insert(
            title: _titleController.text.trim(),
            amountInCents: amountInCents,
            occurredOn: _selectedDate!,
            type: _selectedType!,
            status: _selectedStatus!,
            note: note == null ? const drift.Value.absent() : drift.Value(note),
            filePath: storedFile == null
                ? const drift.Value.absent()
                : drift.Value(storedFile.filePath),
            fileName: storedFile == null
                ? const drift.Value.absent()
                : drift.Value(storedFile.fileName),
            fileType: storedFile == null
                ? const drift.Value.absent()
                : drift.Value(storedFile.fileType),
          ),
        );
      }

      if (existingFilePath != null &&
          (storedFile == null || storedFile.filePath != existingFilePath)) {
        await fileService.deleteStoredFile(existingFilePath);
      }

      ref.invalidate(ticketListProvider);
      ref.invalidate(ticketRecentListProvider);
      ref.invalidate(reimbursementAvailableTicketsProvider);
      if (linkedSheetId != null) {
        ref.invalidate(reimbursementLinkedTicketsProvider(linkedSheetId));
      }
    } catch (_) {
      if (createdNewFile && storedFile != null) {
        await fileService.deleteStoredFile(storedFile.filePath);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_isEditing ? '票据已更新' : '票据已保存')));
    Navigator.of(context).pop();
  }

  String? _validateAttachmentDraft() {
    final attachment = _attachment;
    if (attachment == null) {
      return null;
    }

    final previewPath = attachment.previewPath;
    if (previewPath == null || previewPath.trim().isEmpty) {
      return '当前附件无效，请重新导入或移除';
    }

    if (File(previewPath).existsSync()) {
      return null;
    }

    return attachment.isStored ? '当前附件文件不存在，请先移除或重新导入' : '所选附件不存在，请重新导入';
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.attachment,
    required this.onPickImage,
    required this.onPickPdf,
    required this.onRemove,
  });

  final _TicketAttachmentDraft? attachment;
  final VoidCallback onPickImage;
  final VoidCallback onPickPdf;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final previewPath = attachment?.previewPath;
    final fileExists =
        previewPath != null &&
        previewPath.trim().isNotEmpty &&
        File(previewPath).existsSync();
    final showImagePreview =
        attachment != null &&
        isImageTicketFile(attachment!.fileType) &&
        fileExists;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '附件',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            attachment == null
                ? '未附加图片或 PDF'
                : '已选择 ${ticketFileTypeLabel(attachment!.fileType)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (attachment != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isImageTicketFile(attachment!.fileType)
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment!.fileName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        attachment!.isStored
                            ? fileExists
                                  ? '已保存到本地'
                                  : '附件不可用，请重选'
                            : fileExists
                            ? '保存后会复制到本地'
                            : '附件不可用，请重选',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fileExists
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onRemove, child: const Text('移除')),
              ],
            ),
            if (showImagePreview) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(previewPath),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('导入图片'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('导入 PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketAttachmentDraft {
  const _TicketAttachmentDraft._({
    required this.fileName,
    required this.fileType,
    this.storedPath,
    this.sourcePath,
  });

  factory _TicketAttachmentDraft.stored({
    required String filePath,
    required String fileName,
    required String fileType,
  }) {
    return _TicketAttachmentDraft._(
      fileName: fileName,
      fileType: fileType,
      storedPath: filePath,
    );
  }

  factory _TicketAttachmentDraft.imported({
    required String sourcePath,
    required String fileName,
    required String fileType,
  }) {
    return _TicketAttachmentDraft._(
      fileName: fileName,
      fileType: fileType,
      sourcePath: sourcePath,
    );
  }

  final String fileName;
  final String fileType;
  final String? storedPath;
  final String? sourcePath;

  bool get isStored => storedPath != null;

  String? get previewPath => storedPath ?? sourcePath;
}
