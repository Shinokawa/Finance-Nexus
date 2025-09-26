import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';
import '../providers/account_summary_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../portfolios/views/portfolio_detail_page.dart';
import 'account_form_page.dart';
import 'portfolio_form_page.dart';

class AccountsTabView extends ConsumerStatefulWidget {
  const AccountsTabView({super.key});

  @override
  ConsumerState<AccountsTabView> createState() => _AccountsTabViewState();
}

class _AccountsTabViewState extends ConsumerState<AccountsTabView> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('账户管理'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddOptions(),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Tab 切换器
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _selectedTab,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('账户列表'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('投资组合'),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTab = value);
                  }
                },
              ),
            ),
            // 内容区域
            Expanded(
              child: _selectedTab == 0 
                  ? const _AccountsList()
                  : const _PortfoliosList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOptions() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择类型'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToAccountForm();
            },
            child: const Text('新建账户'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToPortfolioForm();
            },
            child: const Text('新建组合'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _navigateToAccountForm([Account? account]) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => AccountFormPage(account: account),
      ),
    );
    if (result == true) {
      // 刷新数据
      ref.invalidate(accountsStreamProvider);
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _navigateToPortfolioForm([Portfolio? portfolio]) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => PortfolioFormPage(portfolio: portfolio),
      ),
    );
    if (result == true) {
      // 刷新数据
      ref.invalidate(portfoliosStreamProvider);
      ref.invalidate(dashboardDataProvider);
    }
  }
}

class _AccountsList extends ConsumerWidget {
  const _AccountsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const _EmptyStateView(
            icon: CupertinoIcons.creditcard,
            title: '暂无账户',
            subtitle: '点击右上角 + 号创建第一个账户',
          );
        }

        // 按类型分组
        final investmentAccounts = accounts
            .where((a) => a.type == AccountType.investment)
            .toList();
        final cashAccounts = accounts
            .where((a) => a.type == AccountType.cash)
            .toList();
        final liabilityAccounts = accounts
            .where((a) => a.type == AccountType.liability)
            .toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (investmentAccounts.isNotEmpty) ...[
              _AccountSection(
                title: '投资账户',
                accounts: investmentAccounts,
                dashboardAsync: dashboardAsync,
              ),
              const SizedBox(height: 24),
            ],
            if (cashAccounts.isNotEmpty) ...[
              _AccountSection(
                title: '现金账户',
                accounts: cashAccounts,
                dashboardAsync: dashboardAsync,
              ),
              const SizedBox(height: 24),
            ],
            if (liabilityAccounts.isNotEmpty) ...[
              _AccountSection(
                title: '负债账户',
                accounts: liabilityAccounts,
                dashboardAsync: dashboardAsync,
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => _ErrorView(message: error.toString()),
    );
  }
}

class _PortfoliosList extends ConsumerWidget {
  const _PortfoliosList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfoliosAsync = ref.watch(portfoliosStreamProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return portfoliosAsync.when(
      data: (portfolios) {
        if (portfolios.isEmpty) {
          return const _EmptyStateView(
            icon: CupertinoIcons.chart_pie,
            title: '暂无组合',
            subtitle: '点击右上角 + 号创建第一个投资组合',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: portfolios.length,
          itemBuilder: (context, index) {
            final portfolio = portfolios[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PortfolioCard(
                portfolio: portfolio,
                dashboardAsync: dashboardAsync,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => _ErrorView(message: error.toString()),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.title,
    required this.accounts,
    required this.dashboardAsync,
  });

  final String title;
  final List<Account> accounts;
  final AsyncValue<DashboardData> dashboardAsync;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: QHTypography.title3.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Column(
          children: accounts
              .map((account) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AccountCard(
                      account: account,
                      dashboardAsync: dashboardAsync,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({
    required this.account,
    required this.dashboardAsync,
  });

  final Account account;
  final AsyncValue<DashboardData> dashboardAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    // 获取账户快照数据
    final snapshot = dashboardAsync.valueOrNull?.accountSnapshots[account.id];
    final totalValue = snapshot?.totalValue ?? account.balance;
    final unrealizedProfit = snapshot?.unrealizedProfit;
    final todayProfit = snapshot?.todayProfit;

    return GestureDetector(
      onTap: () => _showAccountOptions(context, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: QHTypography.subheadline.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.type.displayName,
                        style: QHTypography.footnote.copyWith(
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(totalValue),
                      style: QHTypography.subheadline.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account.type == AccountType.investment && unrealizedProfit != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatSignedCurrency(unrealizedProfit),
                        style: QHTypography.footnote.copyWith(
                          color: _resolveChangeColor(unrealizedProfit),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (account.type == AccountType.investment && snapshot != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AccountMetric(
                      label: '持仓市值',
                      value: _formatCurrency(snapshot.marketValue),
                    ),
                  ),
                  Expanded(
                    child: _AccountMetric(
                      label: '现金余额',
                      value: _formatCurrency(snapshot.cashBalance),
                    ),
                  ),
                  if (todayProfit != null)
                    Expanded(
                      child: _AccountMetric(
                        label: '今日盈亏',
                        value: _formatSignedCurrency(todayProfit),
                        valueColor: _resolveChangeColor(todayProfit),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(account.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToEdit(context, ref);
            },
            child: const Text('编辑账户'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteConfirmation(context, ref);
            },
            isDestructiveAction: true,
            child: const Text('删除账户'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => AccountFormPage(account: account),
      ),
    );
    if (result == true) {
      ref.invalidate(accountsStreamProvider);
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除「${account.name}」吗？\n此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(accountRepositoryProvider).deleteAccount(account.id);
                ref.invalidate(accountsStreamProvider);
                ref.invalidate(dashboardDataProvider);
              } catch (e) {
                if (context.mounted) {
                  showCupertinoDialog<void>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('删除失败'),
                      content: Text(e.toString()),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('好的'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _PortfolioCard extends ConsumerWidget {
  const _PortfolioCard({
    required this.portfolio,
    required this.dashboardAsync,
  });

  final Portfolio portfolio;
  final AsyncValue<DashboardData> dashboardAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    // 获取组合快照数据
    final snapshot = dashboardAsync.valueOrNull?.portfolioSnapshots[portfolio.id];
    final marketValue = snapshot?.marketValue ?? 0.0;
    final unrealizedProfit = snapshot?.unrealizedProfit;
    final todayProfit = snapshot?.todayProfit;
    final holdingsCount = snapshot?.holdingsCount ?? 0;

    return GestureDetector(
      onTap: () {
        print('🔍 DEBUG: Portfolio card tapped: ${portfolio.name}');
        _navigateToPortfolioDetail(context);
      },
      onLongPress: () {
        print('🔍 DEBUG: Portfolio card long pressed: ${portfolio.name}');
        _showPortfolioOptions(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          // 添加明显的边框用于调试
          border: Border.all(color: CupertinoColors.systemBlue, width: 2),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        portfolio.name,
                        style: QHTypography.subheadline.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (portfolio.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          portfolio.description!,
                          style: QHTypography.footnote.copyWith(
                            color: secondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(marketValue),
                      style: QHTypography.subheadline.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (unrealizedProfit != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatSignedCurrency(unrealizedProfit),
                        style: QHTypography.footnote.copyWith(
                          color: _resolveChangeColor(unrealizedProfit),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (snapshot != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AccountMetric(
                      label: '持仓数量',
                      value: '$holdingsCount 项',
                    ),
                  ),
                  Expanded(
                    child: _AccountMetric(
                      label: '总成本',
                      value: _formatCurrency(snapshot.costBasis),
                    ),
                  ),
                  if (todayProfit != null)
                    Expanded(
                      child: _AccountMetric(
                        label: '今日盈亏',
                        value: _formatSignedCurrency(todayProfit),
                        valueColor: _resolveChangeColor(todayProfit),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToPortfolioDetail(BuildContext context) {
    print('🔍 DEBUG: _navigateToPortfolioDetail called for portfolio: ${portfolio.name}');
    print('🔍 DEBUG: Portfolio ID: ${portfolio.id}');
    
    try {
      Navigator.of(context).push<void>(
        CupertinoPageRoute(
          builder: (context) {
            print('🔍 DEBUG: Building PortfolioDetailPage');
            return PortfolioDetailPage(portfolio: portfolio);
          },
        ),
      );
      print('🔍 DEBUG: Navigation push completed');
    } catch (e) {
      print('❌ DEBUG: Navigation error: $e');
    }
  }

  void _showPortfolioOptions(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(portfolio.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToEdit(context, ref);
            },
            child: const Text('编辑组合'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteConfirmation(context, ref);
            },
            isDestructiveAction: true,
            child: const Text('删除组合'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => PortfolioFormPage(portfolio: portfolio),
      ),
    );
    if (result == true) {
      ref.invalidate(portfoliosStreamProvider);
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除组合'),
        content: Text('确定要删除「${portfolio.name}」吗？\n此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(portfolioRepositoryProvider).deletePortfolio(portfolio.id);
                ref.invalidate(portfoliosStreamProvider);
                ref.invalidate(dashboardDataProvider);
              } catch (e) {
                if (context.mounted) {
                  showCupertinoDialog<void>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('删除失败'),
                      content: Text(e.toString()),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('好的'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final resolvedValueColor = CupertinoDynamicColor.resolve(
      valueColor ?? CupertinoColors.label,
      context,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.footnote.copyWith(
            color: resolvedValueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: secondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: QHTypography.title3.copyWith(
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: QHTypography.subheadline.copyWith(
                color: secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: QHTypography.title3.copyWith(
                color: CupertinoColors.systemRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QHTypography.subheadline.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 辅助函数
Color _resolveChangeColor(double? value) {
  if (value == null) {
    return CupertinoColors.secondaryLabel;
  }
  if (value > 0) {
    return QHColors.profit;
  }
  if (value < 0) {
    return QHColors.loss;
  }
  return CupertinoColors.secondaryLabel;
}

String _formatCurrency(double value) {
  final isNegative = value < 0;
  final absValue = value.abs();
  final formatted = absValue.toStringAsFixed(2);
  return isNegative ? '-¥$formatted' : '¥$formatted';
}

String _formatSignedCurrency(double? value) {
  if (value == null) {
    return '--';
  }
  final absValue = value.abs().toStringAsFixed(2);
  if (value == 0) {
    return '¥$absValue';
  }
  final sign = value > 0 ? '+' : '-';
  return '$sign¥$absValue';
}
