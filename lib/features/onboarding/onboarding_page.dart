import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticket_box/features/onboarding/onboarding_providers.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(onboardingCompletedProvider);

    return completedAsync.when(
      data: (completed) {
        if (completed) {
          return child;
        }

        return const OnboardingPage();
      },
      loading: () => const _OnboardingLoadingScreen(),
      error: (error, stackTrace) => child,
    );
  }
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  var _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _onboardingItems.length - 1;

    return Scaffold(
      key: const ValueKey('onboarding-page'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('onboarding-skip-button'),
                  onPressed: _completeOnboarding,
                  child: const Text('跳过'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _onboardingItems.length,
                  onPageChanged: (index) => setState(() {
                    _currentIndex = index;
                  }),
                  itemBuilder: (context, index) {
                    final item = _onboardingItems[index];
                    return _OnboardingStepView(item: item);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < _onboardingItems.length; index++)
                    _OnboardingIndicator(isActive: index == _currentIndex),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('onboarding-primary-button'),
                  onPressed: isLastPage ? _completeOnboarding : _nextPage,
                  child: Text(isLastPage ? '开始使用' : '下一步'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _completeOnboarding() async {
    await ref.read(onboardingRepositoryProvider).markCompleted();
    ref.invalidate(onboardingCompletedProvider);
  }
}

class _OnboardingStepView extends StatelessWidget {
  const _OnboardingStepView({required this.item});

  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Icon(item.icon, size: 44, color: colors.onSecondaryContainer),
        ),
        const SizedBox(height: 32),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Text(
          item.description,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _OnboardingIndicator extends StatelessWidget {
  const _OnboardingIndicator({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? colors.primary : colors.outlineVariant,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _OnboardingLoadingScreen extends StatelessWidget {
  const _OnboardingLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _onboardingItems = <_OnboardingItem>[
  _OnboardingItem(
    icon: Icons.receipt_long_outlined,
    title: '本地整理票据',
    description: '把日常票据、金额、日期和附件保存在当前设备，方便之后查找。',
  ),
  _OnboardingItem(
    icon: Icons.account_balance_wallet_outlined,
    title: '管理报销单并导出材料',
    description: '把票据加入报销单，可导出 CSV 或完整报销材料包。',
  ),
  _OnboardingItem(
    icon: Icons.manage_search_outlined,
    title: '用 OCR、标签和搜索提高效率',
    description: '图片 OCR 只做辅助建议，配合标签、搜索和筛选快速整理大量票据。',
  ),
  _OnboardingItem(
    icon: Icons.backup_outlined,
    title: '定期备份，避免数据丢失',
    description: '数据主要保存在本机，重要资料建议定期在设置中导出本地备份。',
  ),
];
