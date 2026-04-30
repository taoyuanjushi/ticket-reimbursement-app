import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/tags/tag_management_page.dart';
import 'package:ticket_box/features/tags/tag_providers.dart';
import 'package:ticket_box/features/tickets/ticket_file_service.dart';
import 'package:ticket_box/features/tickets/ticket_ocr_parse_service.dart';
import 'package:ticket_box/features/tickets/ticket_ocr_service.dart';
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
  bool _isRecognizingText = false;
  _TicketAttachmentDraft? _attachment;
  TicketOcrResult? _ocrResult;
  Set<int> _selectedTagIds = <int>{};

  bool get _isEditing => widget.initialTicket != null;

  String? get _currentImageAttachmentPath {
    final attachment = _attachment;
    final previewPath = attachment?.previewPath;
    if (attachment == null ||
        !isImageTicketFile(attachment.fileType) ||
        previewPath == null ||
        previewPath.trim().isEmpty) {
      return null;
    }

    if (!File(previewPath).existsSync()) {
      return null;
    }

    return previewPath;
  }

  bool get _isTitleEmpty => _titleController.text.trim().isEmpty;

  bool get _isAmountEmpty => _amountController.text.trim().isEmpty;

  bool get _isDateEmpty =>
      _selectedDate == null || _dateController.text.trim().isEmpty;

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
    _loadInitialTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTags() async {
    final initialTicket = widget.initialTicket;
    if (initialTicket == null) {
      return;
    }

    final tagIds = await ref
        .read(tagRepositoryProvider)
        .listTagIdsForTicket(initialTicket.id);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedTagIds = tagIds.toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tagsAsync = ref.watch(tagListProvider);
    final ocrSuggestions = _ocrResult == null
        ? null
        : ref.read(ticketOcrParseServiceProvider).parse(_ocrResult!.text);
    final canFillBlankFields = ocrSuggestions != null
        ? _canFillBlankFields(ocrSuggestions)
        : false;

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
                    _TagSelectionSection(
                      tagsAsync: tagsAsync,
                      selectedTagIds: _selectedTagIds,
                      onToggleTag: _toggleTag,
                      onManageTags: _openTagManagement,
                    ),
                    const SizedBox(height: 20),
                    _AttachmentSection(
                      attachment: _attachment,
                      isRecognizingText: _isRecognizingText,
                      onPickImage: _pickImage,
                      onPickPdf: _pickPdf,
                      onRemove: _removeAttachment,
                      onRecognizeText: _currentImageAttachmentPath == null
                          ? null
                          : _recognizeImageText,
                    ),
                    if (_ocrResult != null) ...[
                      const SizedBox(height: 20),
                      _OcrResultSection(
                        result: _ocrResult!,
                        isRecognizingText: _isRecognizingText,
                        onCopy: _copyOcrResult,
                        onRetry: _recognizeImageText,
                        onClear: _clearOcrResult,
                      ),
                    ],
                    if (ocrSuggestions != null && ocrSuggestions.hasAny) ...[
                      const SizedBox(height: 20),
                      _OcrSuggestionSection(
                        suggestions: ocrSuggestions,
                        canFillBlankFields: canFillBlankFields,
                        onFillBlankFields: () =>
                            _fillBlankFieldsFromSuggestions(ocrSuggestions),
                        onApplyTitle: ocrSuggestions.title == null
                            ? null
                            : () =>
                                  _applyTitleSuggestion(ocrSuggestions.title!),
                        onApplyAmount: ocrSuggestions.amount == null
                            ? null
                            : () => _applyAmountSuggestion(
                                ocrSuggestions.amount!,
                              ),
                        onApplyDate: ocrSuggestions.date == null
                            ? null
                            : () => _applyDateSuggestion(ocrSuggestions.date!),
                      ),
                    ],
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

  void _toggleTag(int tagId, bool selected) {
    setState(() {
      final nextSelectedTagIds = Set<int>.from(_selectedTagIds);
      if (selected) {
        nextSelectedTagIds.add(tagId);
      } else {
        nextSelectedTagIds.remove(tagId);
      }
      _selectedTagIds = nextSelectedTagIds;
    });
  }

  Future<void> _openTagManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TagManagementPage()),
    );

    final tags = await ref.refresh(tagListProvider.future);
    if (!mounted) {
      return;
    }

    final availableTagIds = tags.map((tag) => tag.id).toSet();
    setState(() {
      _selectedTagIds = _selectedTagIds
          .where(availableTagIds.contains)
          .toSet();
    });
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
      _ocrResult = null;
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
      _ocrResult = null;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachment = null;
      _ocrResult = null;
    });
  }

  Future<void> _recognizeImageText() async {
    final imagePath = _currentImageAttachmentPath;
    if (imagePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择可用的图片附件')));
      return;
    }

    setState(() {
      _isRecognizingText = true;
    });

    try {
      final result = await ref
          .read(ticketOcrServiceProvider)
          .recognizeImageText(imagePath);

      if (!mounted) {
        return;
      }

      setState(() {
        _ocrResult = result;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已识别图片文字，可作为填写参考')));
    } on TicketOcrNoTextException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未识别到文字，请换一张更清晰的图片')));
    } on TicketOcrInvalidImageException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片不可用，请重新选择')));
    } on TicketOcrException {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('识别失败，请稍后重试')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('识别失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizingText = false;
        });
      }
    }
  }

  void _clearOcrResult() {
    if (_ocrResult == null) {
      return;
    }

    setState(() {
      _ocrResult = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清除识别结果')));
  }

  bool _canFillBlankFields(TicketOcrSuggestions suggestions) {
    return (suggestions.title != null && _isTitleEmpty) ||
        (suggestions.amount != null && _isAmountEmpty) ||
        (suggestions.date != null && _isDateEmpty);
  }

  void _fillBlankFieldsFromSuggestions(TicketOcrSuggestions suggestions) {
    if (!_canFillBlankFields(suggestions)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可填入的空白字段')));
      return;
    }

    setState(() {
      final title = suggestions.title;
      if (title != null && _isTitleEmpty) {
        final nextValue = title.value.trim();
        if (nextValue.isNotEmpty) {
          _titleController
            ..text = nextValue
            ..selection = TextSelection.collapsed(offset: nextValue.length);
        }
      }

      final amount = suggestions.amount;
      if (amount != null && _isAmountEmpty) {
        final nextValue = amount.displayValue;
        _amountController
          ..text = nextValue
          ..selection = TextSelection.collapsed(offset: nextValue.length);
      }

      final date = suggestions.date;
      if (date != null && _isDateEmpty) {
        _selectedDate = date.value;
        _dateController.text = date.displayValue;
      }
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已填入空白字段')));
  }

  Future<void> _copyOcrResult() async {
    final text = _ocrResult?.text.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('识别结果已复制')));
  }

  Future<void> _applyTitleSuggestion(
    TicketOcrSuggestion<String> suggestion,
  ) async {
    final nextValue = suggestion.value.trim();
    if (nextValue.isEmpty) {
      return;
    }

    final confirmed = await _confirmReplaceIfNeeded(
      fieldLabel: '标题',
      currentValue: _titleController.text,
      nextValue: nextValue,
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _titleController
        ..text = nextValue
        ..selection = TextSelection.collapsed(offset: nextValue.length);
    });
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已应用标题建议')));
  }

  Future<void> _applyAmountSuggestion(
    TicketOcrSuggestion<int> suggestion,
  ) async {
    final nextValue = suggestion.displayValue;
    final confirmed = await _confirmReplaceIfNeeded(
      fieldLabel: '金额',
      currentValue: _amountController.text,
      nextValue: nextValue,
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _amountController
        ..text = nextValue
        ..selection = TextSelection.collapsed(offset: nextValue.length);
    });
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已应用金额建议')));
  }

  Future<void> _applyDateSuggestion(
    TicketOcrSuggestion<DateTime> suggestion,
  ) async {
    final nextText = suggestion.displayValue;
    final currentText = _selectedDate == null
        ? ''
        : formatTicketDate(_selectedDate!);
    final confirmed = await _confirmReplaceIfNeeded(
      fieldLabel: '日期',
      currentValue: currentText,
      nextValue: nextText,
    );
    if (!confirmed) {
      return;
    }

    setState(() {
      _selectedDate = suggestion.value;
      _dateController.text = nextText;
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已应用日期建议')));
  }

  Future<bool> _confirmReplaceIfNeeded({
    required String fieldLabel,
    required String currentValue,
    required String nextValue,
  }) async {
    final normalizedCurrent = currentValue.trim();
    if (normalizedCurrent.isEmpty || normalizedCurrent == nextValue.trim()) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('替换$fieldLabel？'),
          content: Text('当前$fieldLabel已有内容，是否替换为识别建议？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('应用'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
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
    final tagRepository = ref.read(tagRepositoryProvider);
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
        await tagRepository.replaceTagsForTicket(
          ticketId: initialTicket.id,
          tagIds: _selectedTagIds.toList(growable: false),
        );
        ref.invalidate(ticketByIdProvider(initialTicket.id));
        ref.invalidate(ticketTagsProvider(initialTicket.id));
      } else {
        final createdTicketId = await repository.createTicket(
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
        await tagRepository.replaceTagsForTicket(
          ticketId: createdTicketId,
          tagIds: _selectedTagIds.toList(growable: false),
        );
        ref.invalidate(ticketTagsProvider(createdTicketId));
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

class _TagSelectionSection extends StatelessWidget {
  const _TagSelectionSection({
    required this.tagsAsync,
    required this.selectedTagIds,
    required this.onToggleTag,
    required this.onManageTags,
  });

  final AsyncValue<List<Tag>> tagsAsync;
  final Set<int> selectedTagIds;
  final void Function(int tagId, bool selected) onToggleTag;
  final VoidCallback onManageTags;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '标签',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedTagIds.isEmpty ? '未选择标签' : '已选 ${selectedTagIds.length} 个标签',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onManageTags, child: const Text('管理标签')),
            ],
          ),
          const SizedBox(height: 14),
          tagsAsync.when(
            data: (tags) {
              if (tags.isEmpty) {
                return Text(
                  '还没有标签，可先去管理标签。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text(tag.name),
                      selected: selectedTagIds.contains(tag.id),
                      onSelected: (selected) => onToggleTag(tag.id, selected),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) {
              return Text(
                '加载标签失败，请稍后重试。',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.error),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttachmentSection extends StatelessWidget {
  const _AttachmentSection({
    required this.attachment,
    required this.isRecognizingText,
    required this.onPickImage,
    required this.onPickPdf,
    required this.onRemove,
    required this.onRecognizeText,
  });

  final _TicketAttachmentDraft? attachment;
  final bool isRecognizingText;
  final VoidCallback onPickImage;
  final VoidCallback onPickPdf;
  final VoidCallback onRemove;
  final VoidCallback? onRecognizeText;

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
          if (onRecognizeText != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('ticket-ocr-button'),
              onPressed: isRecognizingText ? null : onRecognizeText,
              icon: isRecognizingText
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.text_snippet_outlined),
              label: Text(isRecognizingText ? '识别中...' : '识别图片文字'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OcrResultSection extends StatelessWidget {
  const _OcrResultSection({
    required this.result,
    required this.isRecognizingText,
    required this.onCopy,
    required this.onRetry,
    required this.onClear,
  });

  final TicketOcrResult result;
  final bool isRecognizingText;
  final VoidCallback onCopy;
  final VoidCallback onRetry;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('ticket-ocr-result-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '识别结果',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '仅作参考，不会自动填入表单。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 96, maxHeight: 220),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                result.text,
                key: const ValueKey('ticket-ocr-result-text'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '共 ${result.lineCount} 行文字',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: isRecognizingText ? null : onRetry,
                          icon: isRecognizingText
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_outlined),
                          label: Text(isRecognizingText ? '识别中...' : '重新识别'),
                        ),
                        OutlinedButton.icon(
                          onPressed: onCopy,
                          icon: const Icon(Icons.content_copy_outlined),
                          label: const Text('复制结果'),
                        ),
                        TextButton(
                          onPressed: onClear,
                          child: const Text('清除识别结果'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OcrSuggestionSection extends StatelessWidget {
  const _OcrSuggestionSection({
    required this.suggestions,
    required this.canFillBlankFields,
    required this.onFillBlankFields,
    required this.onApplyTitle,
    required this.onApplyAmount,
    required this.onApplyDate,
  });

  final TicketOcrSuggestions suggestions;
  final bool canFillBlankFields;
  final VoidCallback onFillBlankFields;
  final VoidCallback? onApplyTitle;
  final VoidCallback? onApplyAmount;
  final VoidCallback? onApplyDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('ticket-ocr-suggestion-card'),
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
            '建议填入',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '可逐项应用，也可先填入空白字段。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: canFillBlankFields ? onFillBlankFields : null,
            icon: const Icon(Icons.auto_fix_high_outlined),
            label: const Text('填入空白字段'),
          ),
          const SizedBox(height: 8),
          Text(
            '只会填入当前仍为空的字段，不会覆盖已有内容。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (suggestions.title != null) ...[
            const SizedBox(height: 16),
            _OcrSuggestionTile(
              fieldLabel: '标题',
              suggestion: suggestions.title!.displayValue,
              onApply: onApplyTitle!,
            ),
          ],
          if (suggestions.amount != null) ...[
            const SizedBox(height: 12),
            _OcrSuggestionTile(
              fieldLabel: '金额',
              suggestion: suggestions.amount!.displayValue,
              onApply: onApplyAmount!,
            ),
          ],
          if (suggestions.date != null) ...[
            const SizedBox(height: 12),
            _OcrSuggestionTile(
              fieldLabel: '日期',
              suggestion: suggestions.date!.displayValue,
              onApply: onApplyDate!,
            ),
          ],
        ],
      ),
    );
  }
}

class _OcrSuggestionTile extends StatelessWidget {
  const _OcrSuggestionTile({
    required this.fieldLabel,
    required this.suggestion,
    required this.onApply,
  });

  final String fieldLabel;
  final String suggestion;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fieldLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(onPressed: onApply, child: const Text('应用')),
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
