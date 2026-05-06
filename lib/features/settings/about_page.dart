import 'package:flutter/material.dart';
import 'package:ticket_box/app/app_metadata.dart';
import 'package:ticket_box/shared/widgets/app_section_header.dart';
import 'package:ticket_box/shared/widgets/app_surface_card.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('关于票据盒')),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('about-page'),
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
                      Icons.receipt_long_rounded,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '版本 $appDisplayVersion',
                          key: const ValueKey('about-version'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const AppSurfaceCard(
              child: AppSectionHeader(
                title: '本地优先',
                subtitle: '票据盒是一款个人本地票据管理工具。',
              ),
            ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _AboutInfoItem(
                    icon: Icons.folder_outlined,
                    title: '本地保存',
                    description: '票据、报销单和附件数据保存在当前设备本地。',
                  ),
                  SizedBox(height: 16),
                  _AboutInfoItem(
                    icon: Icons.person_outline_rounded,
                    title: '个人使用',
                    description: '当前版本面向个人和本地场景，用于整理票据、报销单和导出材料。',
                  ),
                  SizedBox(height: 16),
                  _AboutInfoItem(
                    icon: Icons.cloud_off_outlined,
                    title: '无在线服务',
                    description: '不包含登录、云同步、后台服务或在线票据校验。',
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

class _AboutInfoItem extends StatelessWidget {
  const _AboutInfoItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: colors.primary),
        ),
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
