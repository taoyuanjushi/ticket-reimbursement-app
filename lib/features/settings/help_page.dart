import 'package:flutter/material.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('使用帮助')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('help-page'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            AppSurfaceCard(
              color: const Color(0xFFF8FBF9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: AppSectionHeader(
                      title: '快速上手',
                      subtitle: '按这些流程整理票据、报销单和本地备份。',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HelpStep(
                    title: '新建票据',
                    description: '在票据页点新建，填写标题、金额、日期、类型、状态和备注。',
                  ),
                  _HelpStep(
                    title: '添加图片/PDF附件',
                    description: '在票据表单中选择图片或 PDF，文件会保存到应用本地目录。',
                  ),
                  _HelpStep(
                    title: '使用图片 OCR 辅助录入',
                    description: '图片附件可识别文字，并手动应用标题、金额、日期建议。',
                  ),
                  _HelpStep(
                    title: '创建报销单',
                    description: '在报销单页新建报销单，填写名称、状态和备注。',
                  ),
                  _HelpStep(
                    title: '关联票据',
                    description: '进入报销单详情，选择已有票据加入当前报销单。',
                  ),
                  _HelpStep(
                    title: '导出 CSV',
                    description: '在报销单详情导出关联票据清单，便于提交或留档。',
                  ),
                  _HelpStep(
                    title: '导出报销材料包',
                    description: '材料包会包含 CSV、说明文件和可用附件。',
                  ),
                  _HelpStep(
                    title: '本地备份与恢复',
                    description: '在设置中导出本地备份；恢复备份会覆盖当前本地数据。',
                  ),
                  _HelpStep(
                    title: '回收站恢复',
                    description: '误删票据或报销单后，可在设置的回收站中恢复。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_circle_right_outlined, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
