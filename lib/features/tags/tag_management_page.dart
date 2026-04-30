import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/data/local/app_database.dart';
import 'package:ticket_box/data/repositories/tag_repository.dart';
import 'package:ticket_box/features/tags/tag_providers.dart';
import 'package:ticket_box/features/tickets/ticket_support.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class TagManagementPage extends ConsumerWidget {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagSummariesAsync = ref.watch(tagSummaryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTag(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建标签'),
      ),
      body: SafeArea(
        child: tagSummariesAsync.when(
          data: (tagSummaries) {
            return ListView(
              key: const ValueKey('tag-management-page'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                AppSurfaceCard(
                  color: const Color(0xFFF8FBF9),
                  child: const AppSectionHeader(
                    title: '本地标签',
                    subtitle: '用自定义标签整理票据，可在票据表单中多选。',
                  ),
                ),
                const SizedBox(height: 16),
                if (tagSummaries.isEmpty)
                  _TagEmptyState(onCreate: () => _createTag(context, ref))
                else
                  for (final summary in tagSummaries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TagListItem(
                        summary: summary,
                        onEdit: () => _editTag(context, ref, summary.tag),
                        onDelete: () => _deleteTag(context, ref, summary.tag),
                      ),
                    ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppSurfaceCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('加载标签失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.invalidate(tagSummaryListProvider),
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createTag(BuildContext context, WidgetRef ref) async {
    final tagName = await _showTagNameDialog(
      context: context,
      title: '新建标签',
      confirmLabel: '创建',
    );
    if (tagName == null) {
      return;
    }

    try {
      await ref.read(tagRepositoryProvider).createTag(tagName);
      ref.invalidate(tagListProvider);
      ref.invalidate(tagSummaryListProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签已创建')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('创建标签失败，请检查名称是否重复')));
    }
  }

  Future<void> _editTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final tagName = await _showTagNameDialog(
      context: context,
      title: '编辑标签',
      confirmLabel: '保存',
      initialValue: tag.name,
    );
    if (tagName == null) {
      return;
    }

    try {
      await ref
          .read(tagRepositoryProvider)
          .updateTag(tagId: tag.id, name: tagName);
      ref.invalidate(tagListProvider);
      ref.invalidate(tagSummaryListProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签已更新')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('更新标签失败，请检查名称是否重复')));
    }
  }

  Future<void> _deleteTag(BuildContext context, WidgetRef ref, Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除标签'),
          content: Text('删除“${tag.name}”后，会从相关票据中移除这个标签。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(tagRepositoryProvider).deleteTag(tag.id);
      ref.invalidate(tagListProvider);
      ref.invalidate(tagSummaryListProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标签已删除')));
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('删除标签失败')));
    }
  }

  Future<String?> _showTagNameDialog({
    required BuildContext context,
    required String title,
    required String confirmLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: '标签名称',
              hintText: '例如：差旅',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return null;
    }

    return result.trim();
  }
}

class _TagEmptyState extends StatelessWidget {
  const _TagEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        children: [
          const Icon(Icons.label_outline_rounded, size: 40),
          const SizedBox(height: 12),
          const Text('还没有标签'),
          const SizedBox(height: 8),
          const Text('先创建几个常用标签，之后可在票据表单里直接选择。', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建标签'),
          ),
        ],
      ),
    );
  }
}

class _TagListItem extends StatelessWidget {
  const _TagListItem({
    required this.summary,
    required this.onEdit,
    required this.onDelete,
  });

  final TagSummary summary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tag = summary.tag;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.label_rounded,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tag.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑标签',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除标签',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(
                icon: Icons.receipt_long_outlined,
                label: '${summary.ticketCount} 张票据',
              ),
              _SummaryBadge(
                icon: Icons.payments_outlined,
                label: formatTicketAmount(summary.totalAmountInCents),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
