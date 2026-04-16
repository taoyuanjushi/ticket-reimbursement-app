import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/providers/database_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_providers.dart';
import 'package:ticket_box/features/reimbursements/reimbursement_support.dart';

class ReimbursementFormPage extends ConsumerStatefulWidget {
  const ReimbursementFormPage({this.initialSheet, super.key});

  final ReimbursementSheet? initialSheet;

  @override
  ConsumerState<ReimbursementFormPage> createState() =>
      _ReimbursementFormPageState();
}

class _ReimbursementFormPageState extends ConsumerState<ReimbursementFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedStatus;
  bool _isSaving = false;

  bool get _isEditing => widget.initialSheet != null;

  @override
  void initState() {
    super.initState();

    final initialSheet = widget.initialSheet;
    if (initialSheet == null) {
      _selectedStatus = reimbursementStatusOptions.first.value;
    } else {
      _nameController.text = initialSheet.title;
      _noteController.text = initialSheet.description ?? '';
      _selectedStatus = initialSheet.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑报销单' : '新建报销单')),
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
                      _isEditing ? '更新报销单信息' : '新建报销单',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '先保存基础信息，后续再关联票据。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        hintText: '例如：四月出差报销',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return '请输入名称';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: [
                        for (final option in reimbursementStatusOptions)
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
            onPressed: _isSaving ? null : _saveSheet,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _isSaving ? '保存中...' : (_isEditing ? '更新报销单' : '保存报销单'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSheet() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final repository = ref.read(reimbursementRepositoryProvider);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    try {
      if (_isEditing) {
        final initialSheet = widget.initialSheet!;
        await repository.updateReimbursementSheet(
          ReimbursementSheet(
            id: initialSheet.id,
            title: _nameController.text.trim(),
            status: _selectedStatus!,
            description: note,
            submittedAt: initialSheet.submittedAt,
            reimbursedAt: initialSheet.reimbursedAt,
            createdAt: initialSheet.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
        ref.invalidate(reimbursementByIdProvider(initialSheet.id));
      } else {
        await repository.createReimbursementSheet(
          ReimbursementSheetsCompanion.insert(
            title: _nameController.text.trim(),
            status: drift.Value(_selectedStatus!),
            description: note == null
                ? const drift.Value.absent()
                : drift.Value(note),
          ),
        );
      }

      ref.invalidate(reimbursementListProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_isEditing ? '报销单已更新' : '报销单已保存')));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
      setState(() {
        _isSaving = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });
  }
}
