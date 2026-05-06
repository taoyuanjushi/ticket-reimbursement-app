import 'package:flutter/material.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('隐私说明')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('privacy-page'),
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
                      Icons.privacy_tip_outlined,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: AppSectionHeader(
                      title: '本地优先的隐私设计',
                      subtitle: '票据盒不要求登录，数据默认保存在当前设备。',
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
                  _PrivacyItem(
                    title: '数据保存在设备上',
                    description: '票据、报销单、标签、设置和附件记录存储在当前设备本地。',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    title: '无需登录',
                    description: '当前版本不需要账号，也不包含登录、云同步或后台服务。',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    title: '附件本地存储',
                    description: '图片和 PDF 附件会复制到应用本地目录中保存。',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    title: '备份由你手动导出',
                    description: '本地备份文件只会在你主动选择导出或分享时生成。',
                  ),
                  SizedBox(height: 16),
                  _PrivacyItem(
                    title: '卸载前请先备份',
                    description: '卸载应用可能移除本地数据。重要资料请先导出本地备份。',
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

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline_rounded, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
    );
  }
}
