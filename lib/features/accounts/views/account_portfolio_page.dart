import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../design/design_system.dart';
import '../models/account_summary.dart';
import '../models/portfolio_summary.dart';
import '../providers/account_summary_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../portfolios/views/portfolio_detail_page.dart';
import 'account_detail_page.dart';
import 'account_form_page.dart';
import 'portfolio_form_page.dart';

enum AccountSegment { accounts, portfolios }

class AccountPortfolioPage extends ConsumerStatefulWidget {
  const AccountPortfolioPage({super.key});

  @override
  ConsumerState<AccountPortfolioPage> createState() => _AccountPortfolioPageState();
}

class _AccountPortfolioPageState extends ConsumerState<AccountPortfolioPage> {
  AccountSegment _segment = AccountSegment.accounts;

  void _showAccountOptions(AccountSummary summary) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(summary.account.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _openAccountDetail(summary);
            },
            child: const Text('查看详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _openAccountForm(summary: summary);
            },
            child: const Text('编辑账户'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _openAccountDetail(AccountSummary summary) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => AccountDetailPage(accountSummary: summary),
      ),
    );
  }

  void _openAccountForm({AccountSummary? summary}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => AccountFormPage(account: summary?.account),
      ),
    );
  }

  void _openPortfolioForm({PortfolioSummary? summary}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PortfolioFormPage(portfolio: summary?.portfolio),
      ),
    );
  }

  void _openPortfolioDetail(PortfolioSummary summary) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PortfolioDetailPage(portfolio: summary.portfolio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedAccountsAsync = ref.watch(groupedAccountSummariesProvider);
    final portfoliosAsync = ref.watch(portfolioSummariesProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('账户'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (_segment == AccountSegment.accounts) {
                  _openAccountForm();
                } else {
                  _openPortfolioForm();
                }
              },
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: QHSpacing.pageHorizontal,
                vertical: 12,
              ),
              child: CupertinoSlidingSegmentedControl<AccountSegment>(
                groupValue: _segment,
                children: const {
                  AccountSegment.accounts: Text('账户列表'),
                  AccountSegment.portfolios: Text('组合列表'),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _segment = value);
                  }
                },
              ),
            ),
          ),
          ...(_segment == AccountSegment.accounts
              ? _buildAccountSections(context, groupedAccountsAsync, dashboardAsync)
              : _buildPortfolioSections(context, portfoliosAsync, dashboardAsync)),
        ],
      ),
    );
  }

  List<Widget> _buildAccountSections(
    BuildContext context,
    AsyncValue<Map<AccountType, List<AccountSummary>>> groupedAccounts,
    AsyncValue<DashboardData> dashboardAsync,
  ) {
    return groupedAccounts.when(
      data: (grouped) {
        final sections = AccountType.values
            .map((type) => _buildAccountSection(context, type, grouped[type] ?? [], dashboardAsync))
            .where((section) => section != null)
            .cast<Widget>()
            .toList();
        if (sections.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(message: '还没有账户，点击右上角的“加号”创建一个吧。'),
            ),
          ];
        }
        return sections;
      },
      loading: () => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ],
      error: (error, stackTrace) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(message: error.toString()),
        ),
      ],
    );
  }

  Widget? _buildAccountSection(
    BuildContext context,
    AccountType type,
    List<AccountSummary> summaries,
    AsyncValue<DashboardData> dashboardAsync,
  ) {
    if (summaries.isEmpty) {
      return null;
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: QHSpacing.pageHorizontal,
        vertical: 8,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
              child: Text(
                type.displayName,
                style: QHTypography.subheadline.copyWith(
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            ...summaries.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _AccountCard(
                  summary: summary,
                  dashboardAsync: dashboardAsync,
                  onTap: () => _openAccountDetail(summary),
                  onLongPress: () => _showAccountOptions(summary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPortfolioSections(
    BuildContext context,
    AsyncValue<List<PortfolioSummary>> portfolios,
    AsyncValue<DashboardData> dashboardAsync,
  ) {
    return portfolios.when(
      data: (items) {
        if (items.isEmpty) {
          return const [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(message: '还没有投资组合，点击右上角的“加号”创建一个吧。'),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: QHSpacing.pageHorizontal,
              vertical: 8,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
                    child: Text(
                      '投资组合',
                      style: QHTypography.subheadline.copyWith(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                  ...items.map(
                    (summary) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PortfolioCard(
                        summary: summary,
                        dashboardAsync: dashboardAsync,
                        onTap: () => _openPortfolioDetail(summary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ];
      },
      loading: () => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ],
      error: (error, stackTrace) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(message: error.toString()),
        ),
      ],
    );
  }

}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.tray, size: 48),
            const SizedBox(height: 12),
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 48),
            const SizedBox(height: 12),
            Text(
              '加载失败',
              style: QHTypography.title3,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QHTypography.footnote.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCurrency(double value) {
  final isNegative = value < 0;
  final absValue = value.abs();
  final formatted = absValue.toStringAsFixed(2);
  return isNegative ? '-¥$formatted' : '¥$formatted';
}

String _formatSignedCurrency(double value) {
  final isNegative = value < 0;
  final absValue = value.abs();
  final formatted = absValue.toStringAsFixed(2);
  return isNegative ? '-¥$formatted' : '+¥$formatted';
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.summary, 
    required this.dashboardAsync,
    required this.onTap,
    this.onLongPress,
  });

  final AccountSummary summary;
  final AsyncValue<DashboardData> dashboardAsync;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final tertiary = CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context);

    // 从 dashboard 数据中获取账户的今日盈亏信息
    final snapshot = dashboardAsync.valueOrNull?.accountSnapshots[summary.account.id];
    final todayProfit = snapshot?.todayProfit ?? 0.0;
    final todayProfitText = todayProfit == 0 ? '--' : _formatSignedCurrency(todayProfit);
    final todayProfitColor = todayProfit > 0 
        ? CupertinoColors.systemGreen
        : todayProfit < 0 
            ? CupertinoColors.systemRed 
            : secondary;

    final effectiveBalance = summary.effectiveBalance;
    final balanceLabel = summary.isInvestment
        ? '持仓估值'
        : summary.isLiability
            ? '负债余额'
            : '账户余额';
    final secondaryValue = summary.isInvestment
        ? summary.holdingsValue
        : summary.account.balance;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      summary.account.name,
                      style: QHTypography.title3.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _TypeBadge(
                    text: summary.type.displayName,
                    tone: summary.isLiability
                        ? QHColors.loss
                        : (summary.isInvestment
                            ? QHColors.primary
                            : CupertinoColors.systemGreen),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _formatCurrency(effectiveBalance),
                style: QHTypography.title1.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: summary.isLiability ? QHColors.loss : labelColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$balanceLabel · ${_formatCurrency(secondaryValue)}',
                style: QHTypography.subheadline.copyWith(color: tertiary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _MetricPill(
                    label: '今日盈亏',
                    value: todayProfitText,
                    valueColor: todayProfitColor,
                  ),
                  const SizedBox(width: 12),
                  _MetricPill(
                    label: summary.isInvestment ? '现金余额' : '可用余额',
                    value: _formatCurrency(summary.account.balance),
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.summary, 
    required this.dashboardAsync,
    required this.onTap,
  });

  final PortfolioSummary summary;
  final AsyncValue<DashboardData> dashboardAsync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final tertiary = CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context);

    final description = summary.portfolio.description?.trim().isNotEmpty == true
        ? summary.portfolio.description!
        : '暂无备注';

    // 从 dashboard 数据中获取投资组合的今日盈亏信息
    final snapshot = dashboardAsync.valueOrNull?.portfolioSnapshots[summary.portfolio.id];
    final todayProfit = snapshot?.todayProfit ?? 0.0;
    final todayProfitText = todayProfit == 0 ? '--' : _formatSignedCurrency(todayProfit);
    final todayProfitColor = todayProfit > 0 
        ? CupertinoColors.systemGreen
        : todayProfit < 0 
            ? CupertinoColors.systemRed 
            : secondary;
    final holdingsCount = snapshot?.holdingsCount ?? 0;
    final holdingsCountText = holdingsCount > 0 ? '$holdingsCount 项' : '--';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.portfolio.name,
                style: QHTypography.title3.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: QHTypography.subheadline.copyWith(color: tertiary),
              ),
              const SizedBox(height: 16),
              Text(
                _formatCurrency(summary.holdingsValue),
                style: QHTypography.title1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '组合持仓 · ${_formatCurrency(summary.holdingsValue)}',
                style: QHTypography.subheadline.copyWith(color: tertiary),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _MetricPill(
                    label: '今日盈亏', 
                    value: todayProfitText,
                    valueColor: CupertinoDynamicColor.resolve(todayProfitColor, context),
                  ),
                  const SizedBox(width: 12),
                  _MetricPill(
                    label: '持仓数量', 
                    value: holdingsCountText,
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: secondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final resolvedTone = CupertinoDynamicColor.resolve(tone, context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          style: QHTypography.footnote.copyWith(
            fontWeight: FontWeight.w600,
            color: resolvedTone,
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label, 
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final background =
        CupertinoDynamicColor.resolve(CupertinoColors.systemGrey5, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final resolvedValueColor = valueColor ?? CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: QHTypography.footnote.copyWith(color: labelColor),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: QHTypography.subheadline.copyWith(
                fontWeight: FontWeight.w600,
                color: resolvedValueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
