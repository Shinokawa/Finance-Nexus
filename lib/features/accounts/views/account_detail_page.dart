import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../dashboard/models/holding_position.dart';
import '../../ledger/views/transaction_form_page.dart';
import '../../portfolios/providers/portfolio_detail_providers.dart';
import '../../portfolios/views/holding_form_page.dart';
import '../../portfolios/views/holding_selection_page.dart';
import '../../portfolios/views/trade_form_page.dart';
import '../models/account_summary.dart';
import '../providers/account_summary_providers.dart';

// Provider for account transactions
final accountTransactionsProvider = FutureProvider.family<List<Transaction>, String>((ref, accountId) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getTransactionsByAccount(accountId);
});

class AccountDetailPage extends ConsumerStatefulWidget {
  const AccountDetailPage({
    super.key,
    required this.accountSummary,
  });

  final AccountSummary accountSummary;

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  int _selectedTab = 0; // 0: 概览, 1: 持仓(投资账户), 2: 交易记录

  @override
  Widget build(BuildContext context) {
    final account = widget.accountSummary.account;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(account.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showActionSheet(context),
          child: const Icon(CupertinoIcons.ellipsis_circle),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Tab 切换器（仅投资账户显示）
            if (account.type == AccountType.investment) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedTab,
                  children: const {
                    0: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('概览'),
                    ),
                    1: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('持仓'),
                    ),
                    2: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('交易'),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTab = value);
                    }
                  },
                ),
              ),
            ],
            
            // 内容区域
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final account = widget.accountSummary.account;
    
    if (account.type == AccountType.investment) {
      // 投资账户的不同选项卡内容
      switch (_selectedTab) {
        case 0:
          return _buildInvestmentOverview();
        case 1:
          return _buildHoldingsList();
        case 2:
          return _buildTransactionHistory();
        default:
          return _buildInvestmentOverview();
      }
    } else {
      // 现金账户和负债账户只显示概览和交易记录
      return _buildAccountOverview();
    }
  }

  Widget _buildInvestmentOverview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAccountSummaryCard(),
        const SizedBox(height: 16),
        _buildQuickActionsCard(),
        const SizedBox(height: 16),
        _buildRecentTransactionsCard(),
      ],
    );
  }

  Widget _buildAccountOverview() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAccountSummaryCard(),
        const SizedBox(height: 16),
        _buildQuickActionsCard(),
        const SizedBox(height: 16),
        _buildRecentTransactionsCard(),
      ],
    );
  }

  Widget _buildHoldingsList() {
    final holdingsAsync = ref.watch(accountHoldingsProvider(widget.accountSummary.account.id));
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return holdingsAsync.when(
      data: (holdings) {
        if (holdings.isEmpty) {
          return const _EmptyHoldingsView();
        }

        final accountId = widget.accountSummary.account.id;
        final snapshot = dashboardAsync.valueOrNull?.accountSnapshots[accountId];
        final positionsByHoldingId = {
          for (final position in snapshot?.positions ?? const <HoldingPosition>[])
            position.holding.id: position,
        };
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: holdings.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAddHoldingCard(),
              );
            }
            
            final holding = holdings[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HoldingCard(
                holding: holding,
                position: positionsByHoldingId[holding.id],
                onTrade: () => _showTradeForm(holding),
                onEdit: () => _showEditHolding(holding),
                onDelete: () => _showDeleteHolding(holding),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => _ErrorView(message: error.toString()),
    );
  }

  Widget _buildTransactionHistory() {
    final accountId = widget.accountSummary.account.id;
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));

    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.list_bullet,
                    size: 48,
                    color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无交易记录',
                    style: QHTypography.subheadline.copyWith(
                      color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _TransactionItem(
            transaction: transactions[index],
            currentAccountId: accountId,
          ),
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '加载交易记录失败\n${error.toString()}',
            textAlign: TextAlign.center,
            style: QHTypography.subheadline.copyWith(
              color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSummaryCard() {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    final account = widget.accountSummary.account;
    final summary = widget.accountSummary;

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: Text(
                  '账户概览',
                  style: QHTypography.title3.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getAccountTypeColor(account.type).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  account.type.displayName,
                  style: QHTypography.footnote.copyWith(
                    color: _getAccountTypeColor(account.type),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 主要金额显示
          Text(
            _formatCurrency(summary.effectiveBalance),
            style: QHTypography.title1.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: account.type == AccountType.liability ? QHColors.loss : labelColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getBalanceLabel(account.type),
            style: QHTypography.subheadline.copyWith(color: secondaryColor),
          ),
          
          const SizedBox(height: 20),
          
          // 详细信息
          if (account.type == AccountType.investment) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem('持仓市值', _formatCurrency(summary.holdingsValue), labelColor),
                ),
                Expanded(
                  child: _buildMetricItem('现金余额', _formatCurrency(account.balance), labelColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final snapshot = ref.watch(accountSnapshotProvider(account.id));
                      final todayProfit = snapshot.when(
                        data: (data) => data?.todayProfit ?? 0.0,
                        loading: () => 0.0,
                        error: (_, __) => 0.0,
                      );
                      final todayProfitText = _formatSignedCurrency(todayProfit);
                      final todayColor = _resolveChangeColor(todayProfit);
                      return _buildMetricItem('今日盈亏', todayProfitText, todayColor);
                    },
                  ),
                ),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final snapshot = ref.watch(accountSnapshotProvider(account.id));
                      final unrealizedProfit = snapshot.when(
                        data: (data) => data?.unrealizedProfit ?? 0.0,
                        loading: () => 0.0,
                        error: (_, __) => 0.0,
                      );
                      final unrealizedProfitText = _formatSignedCurrency(unrealizedProfit);
                      final unrealizedColor = _resolveChangeColor(unrealizedProfit);
                      return _buildMetricItem('累计盈亏', unrealizedProfitText, unrealizedColor);
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem('账户余额', _formatCurrency(account.balance), labelColor),
                ),
                Expanded(
                  child: _buildMetricItem('可用余额', _formatCurrency(account.balance), labelColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final account = widget.accountSummary.account;

    List<_QuickAction> actions = [];
    
    switch (account.type) {
      case AccountType.investment:
        actions = [
          _QuickAction('资金转入', CupertinoIcons.arrow_down_circle, () => _showFundTransfer(true)),
          _QuickAction('资金转出', CupertinoIcons.arrow_up_circle, () => _showFundTransfer(false)),
          _QuickAction('添加持仓', CupertinoIcons.plus_circle, () => _showAddHolding()),
          _QuickAction('交易记录', CupertinoIcons.list_bullet, () => _showTransactionHistory()),
        ];
        break;
      case AccountType.cash:
        actions = [
          _QuickAction('存入资金', CupertinoIcons.arrow_down_circle, () => _showDeposit()),
          _QuickAction('取出资金', CupertinoIcons.arrow_up_circle, () => _showWithdraw()),
          _QuickAction('转账汇款', CupertinoIcons.arrow_right_circle, () => _showTransfer()),
          _QuickAction('收支记录', CupertinoIcons.list_bullet, () => _showTransactionHistory()),
        ];
        break;
      case AccountType.liability:
        actions = [
          _QuickAction('还款', CupertinoIcons.arrow_down_circle, () => _showRepayment()),
          _QuickAction('借款', CupertinoIcons.arrow_up_circle, () => _showBorrow()),
          _QuickAction('还款记录', CupertinoIcons.list_bullet, () => _showTransactionHistory()),
          _QuickAction('账单详情', CupertinoIcons.doc_text, () => _showBillDetails()),
        ];
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            '快速操作',
            style: QHTypography.title3.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.5,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _QuickActionButton(action: action);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsCard() {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final transactionsAsync = ref.watch(accountTransactionsProvider(widget.accountSummary.account.id));

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: Text(
                  '最近交易',
                  style: QHTypography.title3.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showTransactionHistory,
                child: Text(
                  '查看全部',
                  style: QHTypography.subheadline.copyWith(
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Center(
                  child: Text(
                    '暂无交易记录',
                    style: QHTypography.subheadline.copyWith(color: secondaryColor),
                  ),
                );
              }
              
              // 显示最近3条交易记录
              final recentTransactions = transactions.take(3).toList();
              return Column(
                children: recentTransactions
                    .map((transaction) => _TransactionItem(
                          transaction: transaction,
                          currentAccountId: widget.accountSummary.account.id,
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, stack) => Center(
              child: Text(
                '加载交易记录失败',
                style: QHTypography.subheadline.copyWith(color: secondaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddHoldingCard() {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return GestureDetector(
      onTap: _showAddHolding,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.activeBlue.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.add_circled,
              size: 24,
              color: CupertinoColors.activeBlue,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '添加持仓股票/ETF',
                style: QHTypography.subheadline.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color valueColor) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: QHTypography.subheadline.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getAccountTypeColor(AccountType type) {
    switch (type) {
      case AccountType.investment:
        return CupertinoColors.activeBlue;
      case AccountType.cash:
        return CupertinoColors.systemGreen;
      case AccountType.liability:
        return QHColors.loss;
    }
  }

  String _getBalanceLabel(AccountType type) {
    switch (type) {
      case AccountType.investment:
        return '总资产价值';
      case AccountType.cash:
        return '账户余额';
      case AccountType.liability:
        return '负债余额';
    }
  }

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(widget.accountSummary.account.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showEditAccount();
            },
            child: const Text('编辑账户'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteAccount();
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

  // 各种操作方法
  void _showEditAccount() {
    // TODO: 导航到账户编辑页面
  }

  void _showDeleteAccount() {
    // TODO: 显示删除确认对话框
  }

  void _showFundTransfer(bool isDeposit) {
    if (isDeposit) {
      // 显示转入表单 - 使用收入类型的交易表单
      _showTransactionForm(TransactionType.income);
    } else {
      // 显示转出表单 - 使用支出类型的交易表单
      _showTransactionForm(TransactionType.expense);
    }
  }

  void _showAddHolding() {
    Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => const HoldingSelectionPage(),
      ),
    ).then((result) {
      if (result == true) {
        ref.invalidate(accountHoldingsProvider(widget.accountSummary.account.id));
        ref.invalidate(dashboardDataProvider);
      }
    });
  }

  void _showTransactionHistory() {
    final account = widget.accountSummary.account;
    if (account.type == AccountType.investment) {
      setState(() {
        _selectedTab = 2;
      });
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => AccountTransactionsPage(
            accountId: account.id,
            accountName: account.name,
          ),
        ),
      );
    }
  }

  void _showDeposit() {
    _showTransactionForm(TransactionType.income);
  }

  void _showWithdraw() {
    _showTransactionForm(TransactionType.expense);
  }

  void _showTransfer() {
    _showTransactionForm(TransactionType.transfer);
  }

  void _showRepayment() {
    _showTransactionForm(TransactionType.expense);
  }

  void _showBorrow() {
    _showTransactionForm(TransactionType.income);
  }

  void _showBillDetails() {
    // TODO: 显示账单详情
  }

  void _showTransactionForm(TransactionType type) {
    Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => TransactionFormPage(
          initialType: type,
          preSelectedAccountId: widget.accountSummary.account.id,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // 刷新当前账户相关的所有数据
        ref.invalidate(accountsStreamProvider);
        ref.invalidate(dashboardDataProvider);
        ref.invalidate(accountTransactionsProvider(widget.accountSummary.account.id));
      }
    });
  }

  void _showTradeForm(Holding holding) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => TradeFormPage(holding: holding),
      ),
    );
    
    if (result == true) {
      ref.invalidate(accountHoldingsProvider(widget.accountSummary.account.id));
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showEditHolding(Holding holding) async {
    // 找到持仓所属的投资组合
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => HoldingFormPage(
          portfolioId: holding.portfolioId,
          holding: holding,
        ),
      ),
    );
    
    if (result == true) {
      ref.invalidate(accountHoldingsProvider(widget.accountSummary.account.id));
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showDeleteHolding(Holding holding) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定要删除「${holding.symbol}」吗？\n此操作不可撤销。'),
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
                await ref.read(holdingRepositoryProvider).deleteHolding(holding.id);
                ref.invalidate(accountHoldingsProvider(widget.accountSummary.account.id));
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

class AccountTransactionsPage extends ConsumerWidget {
  const AccountTransactionsPage({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  final String accountId;
  final String accountName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('$accountName 的交易记录'),
      ),
      child: SafeArea(
        child: transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.list_bullet,
                        size: 56,
                        color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '还没有交易记录',
                        style: QHTypography.subheadline.copyWith(
                          color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _TransactionItem(
                transaction: transactions[index],
                currentAccountId: accountId,
              ),
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '加载交易记录失败\n${error.toString()}',
                textAlign: TextAlign.center,
                style: QHTypography.subheadline.copyWith(
                  color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _QuickAction(this.title, this.icon, this.onTap);
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoDynamicColor.resolve(CupertinoColors.systemGrey6, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
            const SizedBox(width: 8),
            Text(
              action.title,
              style: QHTypography.subheadline.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.holding,
    required this.onTrade,
    required this.onEdit,
    required this.onDelete,
    this.position,
  });

  final Holding holding;
  final HoldingPosition? position;
  final VoidCallback onTrade;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    final latestPrice = position?.latestPrice;
    final currentPrice = latestPrice ?? holding.averageCost;
    final costBasis = position?.costBasis ?? holding.quantity * holding.averageCost;
    final marketValue = position?.marketValue ?? holding.quantity * currentPrice;
    final unrealizedProfit = position?.unrealizedProfit ?? (marketValue - costBasis);
    final profitRate = costBasis > 0 ? (unrealizedProfit / costBasis) * 100 : null;
    final profitRateText = profitRate != null ? '${profitRate.toStringAsFixed(2)}%' : '--';
    final priceText = currentPrice > 0 ? '¥${currentPrice.toStringAsFixed(2)}' : '--';
    final titleText = position?.displayName ?? holding.symbol;

    return GestureDetector(
      onTap: () => _showHoldingOptions(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：股票代码和市值
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: QHTypography.subheadline.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (titleText.toUpperCase() != holding.symbol.toUpperCase())
                        Text(
                          holding.symbol.toUpperCase(),
                          style: QHTypography.footnote.copyWith(
                            color: secondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                    Text(
                      _formatSignedCurrency(unrealizedProfit),
                      style: QHTypography.footnote.copyWith(
                        color: _resolveChangeColor(unrealizedProfit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 第二行：持仓信息
            Row(
              children: [
                Expanded(
                  child: _buildHoldingMetric(
                    '持仓',
                    '${holding.quantity.toStringAsFixed(0)} 股',
                    secondaryColor,
                  ),
                ),
                Expanded(
                  child: _buildHoldingMetric(
                    '成本价',
                    '¥${holding.averageCost.toStringAsFixed(2)}',
                    secondaryColor,
                  ),
                ),
                Expanded(
                  child: _buildHoldingMetric(
                    '现价',
                    priceText,
                    secondaryColor,
                  ),
                ),
                Expanded(
                  child: _buildHoldingMetric(
                    '盈亏率',
                    profitRateText,
                    _resolveChangeColor(unrealizedProfit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.footnote.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showHoldingOptions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(holding.symbol),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onTrade();
            },
            child: const Text('买入/卖出'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            child: const Text('编辑持仓'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            isDestructiveAction: true,
            child: const Text('删除持仓'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _EmptyHoldingsView extends StatelessWidget {
  const _EmptyHoldingsView();

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
              CupertinoIcons.chart_bar_square,
              size: 64,
              color: secondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无持仓',
              style: QHTypography.title3.copyWith(
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击上方按钮添加股票/ETF',
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
  if (value == null || value == 0) {
    return CupertinoColors.secondaryLabel;
  }
  return value > 0 ? QHColors.profit : QHColors.loss;
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

class _TransactionItem extends StatelessWidget {
  const _TransactionItem({
    required this.transaction,
    required this.currentAccountId,
  });
  
  final Transaction transaction;
  final String currentAccountId;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    // 根据交易类型和当前账户计算显示的金额和颜色
    Color amountColor;
    String amountText;
    
    switch (transaction.type) {
      case TransactionType.income:
        amountColor = CupertinoColors.systemGreen;
        amountText = '+¥${transaction.amount.toStringAsFixed(2)}';
        break;
      case TransactionType.expense:
        amountColor = CupertinoColors.systemRed;
        amountText = '-¥${transaction.amount.toStringAsFixed(2)}';
        break;
      case TransactionType.transfer:
        // 转账：如果当前账户是来源账户则显示负数，如果是目标账户则显示正数
        if (transaction.fromAccountId == currentAccountId) {
          amountColor = CupertinoColors.systemRed;
          amountText = '-¥${transaction.amount.toStringAsFixed(2)}';
        } else if (transaction.toAccountId == currentAccountId) {
          amountColor = CupertinoColors.systemGreen;
          amountText = '+¥${transaction.amount.toStringAsFixed(2)}';
        } else {
          amountColor = labelColor;
          amountText = '¥${transaction.amount.toStringAsFixed(2)}';
        }
        break;
      case TransactionType.buy:
        amountColor = CupertinoColors.systemRed;
        amountText = '-¥${transaction.amount.toStringAsFixed(2)}';
        break;
      case TransactionType.sell:
        amountColor = CupertinoColors.systemGreen;
        amountText = '+¥${transaction.amount.toStringAsFixed(2)}';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 交易类型图标
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getTransactionTypeColor().withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTransactionTypeIcon(),
              size: 16,
              color: _getTransactionTypeColor(),
            ),
          ),
          const SizedBox(width: 12),
          // 交易信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category?.isNotEmpty == true 
                      ? transaction.category!
                      : transaction.type.displayName,
                  style: QHTypography.subheadline.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(transaction.date),
                  style: QHTypography.footnote.copyWith(color: secondaryColor),
                ),
              ],
            ),
          ),
          // 交易金额
          Text(
            amountText,
            style: QHTypography.subheadline.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTransactionTypeColor() {
    switch (transaction.type) {
      case TransactionType.income:
        return CupertinoColors.systemGreen;
      case TransactionType.expense:
        return CupertinoColors.systemRed;
      case TransactionType.transfer:
        return CupertinoColors.systemBlue;
      case TransactionType.buy:
        return CupertinoColors.systemOrange;
      case TransactionType.sell:
        return CupertinoColors.systemPurple;
    }
  }

  IconData _getTransactionTypeIcon() {
    switch (transaction.type) {
      case TransactionType.income:
        return CupertinoIcons.arrow_down_circle_fill;
      case TransactionType.expense:
        return CupertinoIcons.arrow_up_circle_fill;
      case TransactionType.transfer:
        return CupertinoIcons.arrow_right_arrow_left_circle_fill;
      case TransactionType.buy:
        return CupertinoIcons.plus_circle_fill;
      case TransactionType.sell:
        return CupertinoIcons.minus_circle_fill;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(date.year, date.month, date.day);
    
    if (transactionDate == today) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}