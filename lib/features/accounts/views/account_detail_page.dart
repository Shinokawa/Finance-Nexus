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
import '../models/operation_statistics.dart';
import '../providers/account_summary_providers.dart';
import 'account_form_page.dart';

// Provider for account transactions
final accountTransactionsProvider = StreamProvider.family<List<Transaction>, String>((ref, accountId) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchTransactionsByAccount(accountId).map((transactions) {
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  });
});

final accountOperationStatsProvider = Provider.family<AsyncValue<OperationStatistics>, String>((ref, accountId) {
  final transactionsAsync = ref.watch(accountTransactionsProvider(accountId));
  return transactionsAsync.when(
    data: (transactions) => AsyncValue.data(_calculateOperationStatistics(transactions)),
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});

OperationStatistics _calculateOperationStatistics(List<Transaction> transactions) {
  if (transactions.isEmpty) {
    return OperationStatistics.empty;
  }

  final tradeTransactions = transactions
      .where((transaction) => transaction.type == TransactionType.buy || transaction.type == TransactionType.sell)
      .toList();
  if (tradeTransactions.isEmpty) {
    return OperationStatistics.empty;
  }

  tradeTransactions.sort((a, b) => a.date.compareTo(b.date));

  final groupedByHolding = <String, List<Transaction>>{};
  for (final transaction in tradeTransactions) {
    final holdingId = transaction.relatedHoldingId;
    if (holdingId == null) {
      continue;
    }
    groupedByHolding.putIfAbsent(holdingId, () => []).add(transaction);
  }

  if (groupedByHolding.isEmpty) {
    return OperationStatistics(
      tradedSymbols: 0,
      tradeCount: tradeTransactions.length,
      completedCycles: 0,
      totalTradeAmount: tradeTransactions.fold<double>(0, (sum, txn) => sum + txn.amount.abs()),
    );
  }

  var completedCycles = 0;
  var winningCycles = 0;
  var losingCycles = 0;
  double totalHoldingDays = 0;

  for (final entry in groupedByHolding.entries) {
    final transactionsForHolding = entry.value;
    final buys = transactionsForHolding.where((txn) => txn.type == TransactionType.buy).toList();
    final sells = transactionsForHolding.where((txn) => txn.type == TransactionType.sell).toList();

    if (buys.isEmpty || sells.isEmpty) {
      continue;
    }

    buys.sort((a, b) => a.date.compareTo(b.date));
    sells.sort((a, b) => a.date.compareTo(b.date));

    completedCycles += 1;

    final firstBuyDate = buys.first.date;
    final lastSellDate = sells.last.date;
    final holdingDuration = lastSellDate.difference(firstBuyDate).inDays;
    totalHoldingDays += holdingDuration <= 0 ? 1 : holdingDuration.toDouble();

    final totalBuyAmount = buys.fold<double>(0, (sum, txn) => sum + txn.amount);
    final totalSellAmount = sells.fold<double>(0, (sum, txn) => sum + txn.amount);
    final pnl = totalSellAmount - totalBuyAmount;
    if (pnl > 1e-2) {
      winningCycles += 1;
    } else if (pnl < -1e-2) {
      losingCycles += 1;
    }
  }

  final winBase = winningCycles + losingCycles;
  final averageHoldingDays = completedCycles > 0 ? totalHoldingDays / completedCycles : null;
  final winRate = winBase > 0 ? winningCycles / winBase : null;
  final totalTradeAmount = tradeTransactions.fold<double>(0, (sum, txn) => sum + txn.amount.abs());

  return OperationStatistics(
    tradedSymbols: groupedByHolding.length,
    tradeCount: tradeTransactions.length,
    completedCycles: completedCycles,
    totalTradeAmount: totalTradeAmount,
    averageHoldingDays: averageHoldingDays,
    winRate: winRate,
  );
}

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
  int _operationSegment = 0; // 0: 操作统计, 1: 账户表现（预留）

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
        _buildOperationAnalysisCard(),
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

        final aggregatedGroups = _aggregateAccountHoldings(
          holdings,
          positionsByHoldingId,
        );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: aggregatedGroups.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAddHoldingCard(),
              );
            }

            final group = aggregatedGroups[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AggregatedHoldingCard(
                group: group,
                onTrade: (holding) => _showTradeForm(holding),
                onEdit: (holding) => _showEditHolding(holding),
                onDelete: (holding) => _showDeleteHolding(holding),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) => _ErrorView(message: error.toString()),
    );
  }

  List<_AggregatedHoldingGroup> _aggregateAccountHoldings(
    List<Holding> holdings,
    Map<String, HoldingPosition> positionsByHoldingId,
  ) {
    if (holdings.isEmpty) {
      return const [];
    }

    final builders = <String, _AggregatedHoldingGroupBuilder>{};

    for (final holding in holdings) {
      final key = holding.symbol.trim().toUpperCase();
      final position = positionsByHoldingId[holding.id];
      final builder = builders.putIfAbsent(
        key,
        () => _AggregatedHoldingGroupBuilder(
          symbol: key,
          initialDisplayName: position?.displayName ?? key,
        ),
      );
      builder.add(holding, position);
    }

    final groups = builders.values.map((builder) => builder.build()).toList();
    groups.sort((a, b) => b.marketValue.compareTo(a.marketValue));
    return groups;
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
            Consumer(
              builder: (context, ref, child) {
                final snapshotAsync = ref.watch(accountSnapshotProvider(account.id));
                return snapshotAsync.when(
                  data: (snapshot) => _buildInvestmentMetrics(
                    account: account,
                    summary: summary,
                    snapshot: snapshot,
                    labelColor: labelColor,
                  ),
                  loading: () => _buildInvestmentMetrics(
                    account: account,
                    summary: summary,
                    snapshot: null,
                    labelColor: labelColor,
                  ),
                  error: (_, __) => _buildInvestmentMetrics(
                    account: account,
                    summary: summary,
                    snapshot: null,
                    labelColor: labelColor,
                  ),
                );
              },
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

  Widget _buildInvestmentMetrics({
    required Account account,
    required AccountSummary summary,
    required AccountSnapshot? snapshot,
    required Color labelColor,
  }) {
    final holdingsValue = summary.holdingsValue;
    final cashBalance = account.balance;
    final totalAssets = holdingsValue + cashBalance;
    final costBasis = snapshot?.costBasis;
    final netProfit = snapshot?.netProfit;
    final realizedProfit = snapshot?.realizedProfit;
    final unrealizedProfit = snapshot?.unrealizedProfit;
    final tradingCost = snapshot?.tradingCost;
    final todayProfit = snapshot?.todayProfit;
    final todayPercent = snapshot?.todayProfitPercent;
    final netPercent =
        (snapshot != null && snapshot.costBasis > 0) ? (snapshot.netProfit / snapshot.costBasis) * 100 : null;
    final realizedPercent = (snapshot != null && snapshot.costBasis > 0)
        ? (snapshot.realizedProfit / snapshot.costBasis) * 100
        : null;

    String formatChange(double? amount, double? percent) {
      if (amount == null) return '--';
      return _formatChangeWithPercent(amount, percent);
    }

    String formatPercent(double? value) {
      if (value == null) return '--';
      final sign = value >= 0 ? '+' : '';
      return '$sign${value.toStringAsFixed(2)}%';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricItem('持仓市值', _formatCurrency(holdingsValue), labelColor),
            ),
            Expanded(
              child: _buildMetricItem('现金余额', _formatCurrency(cashBalance), labelColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem('总资产', _formatCurrency(totalAssets), labelColor),
            ),
            Expanded(
              child: _buildMetricItem(
                '组合成本',
                costBasis != null ? _formatCurrency(costBasis) : '--',
                labelColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                '总盈亏',
                formatChange(netProfit, netPercent),
                _resolveChangeColor(netProfit),
              ),
            ),
            Expanded(
              child: _buildMetricItem(
                '已实现盈亏',
                formatChange(realizedProfit, realizedPercent),
                _resolveChangeColor(realizedProfit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                '未实现盈亏',
                formatChange(unrealizedProfit, snapshot?.unrealizedPercent),
                _resolveChangeColor(unrealizedProfit),
              ),
            ),
            Expanded(
              child: _buildMetricItem(
                '交易成本',
                tradingCost != null ? _formatSignedCurrency(-tradingCost) : '--',
                _resolveChangeColor(tradingCost != null ? -tradingCost : null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                '今日盈亏',
                _formatSignedCurrency(todayProfit),
                _resolveChangeColor(todayProfit),
              ),
            ),
            Expanded(
              child: _buildMetricItem(
                '今日涨跌幅',
                formatPercent(todayPercent),
                _resolveChangeColor(todayProfit),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricItem(
                '总收益率',
                formatPercent(netPercent),
                _resolveChangeColor(netProfit),
              ),
            ),
            Expanded(
              child: _buildMetricItem(
                '未实现收益率',
                formatPercent(snapshot?.unrealizedPercent),
                _resolveChangeColor(unrealizedProfit),
              ),
            ),
          ],
        ),
      ],
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

  Widget _buildOperationAnalysisCard() {
    final account = widget.accountSummary.account;
    if (account.type != AccountType.investment) {
      return const SizedBox.shrink();
    }

    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    final statsAsync = ref.watch(accountOperationStatsProvider(account.id));
    final summary = widget.accountSummary;
    final totalAssets = summary.holdingsValue + account.balance;
    final hasAssets = totalAssets.abs() >= 1e-6;
    final averagePosition = hasAssets
        ? (summary.holdingsValue / totalAssets).clamp(0.0, 1.0)
        : 0.0;

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
                  '操作分析',
                  style: QHTypography.title3.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _operationSegment,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('操作统计'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('账户表现'),
                  ),
                },
                onValueChanged: (value) {
                  if (value != null && value != _operationSegment) {
                    setState(() => _operationSegment = value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          statsAsync.when(
            data: (stats) {
              final turnoverRate = hasAssets
                  ? (stats.totalTradeAmount / totalAssets).clamp(0.0, 5.0)
                  : 0.0;
              final averageHoldingDays = stats.averageHoldingDays;
              final winRate = stats.winRate;

              if (_operationSegment == 1) {
                return _OperationPlaceholder(secondaryColor: secondaryColor);
              }

              final metrics = [
                _OperationMetric(
                  label: '交易股票数',
                  value: stats.tradedSymbols.toString(),
                ),
                _OperationMetric(
                  label: '平均持仓天数',
                  value: averageHoldingDays == null
                      ? '--'
                      : averageHoldingDays.toStringAsFixed(1),
                ),
                _OperationMetric(
                  label: '建清仓次数',
                  value: stats.completedCycles.toString(),
                ),
                _OperationMetric(
                  label: '交易成功率',
                  value: winRate == null
                      ? '--'
                      : '${(winRate * 100).clamp(0, 100).toStringAsFixed(2)}%',
                ),
                _OperationMetric(
                  label: '平均仓位',
                  value: '${(averagePosition * 100).toStringAsFixed(2)}%',
                ),
                _OperationMetric(
                  label: '资金周转率',
                  value: '${(turnoverRate * 100).toStringAsFixed(2)}%',
                ),
              ];

              return Column(
                children: [
                  for (var i = 0; i < metrics.length; i += 2) ...[
                    Row(
                      children: [
                        Expanded(child: _OperationMetricTile(metric: metrics[i])),
                        const SizedBox(width: 16),
                        Expanded(
                          child: i + 1 < metrics.length
                              ? _OperationMetricTile(metric: metrics[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    if (i + 2 < metrics.length) const SizedBox(height: 12),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, stack) => Center(
              child: Text(
                '操作数据暂不可用',
                style: QHTypography.subheadline.copyWith(color: secondaryColor),
              ),
            ),
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
    final account = widget.accountSummary.account;
    Navigator.of(context)
        .push<bool>(
          CupertinoPageRoute(
            builder: (context) => AccountFormPage(account: account),
          ),
        )
        .then((changed) {
          if (changed == true) {
            ref.invalidate(accountsStreamProvider);
            ref.invalidate(accountSummariesProvider);
            ref.invalidate(dashboardDataProvider);
          }
        });
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

class _OperationMetric {
  const _OperationMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _OperationMetricTile extends StatelessWidget {
  const _OperationMetricTile({
    required this.metric,
  });

  final _OperationMetric metric;

  @override
  Widget build(BuildContext context) {
    final tileColor = CupertinoDynamicColor.resolve(QHColors.surface, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final valueColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: QHTypography.footnote.copyWith(color: labelColor),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: QHTypography.title3.copyWith(
              fontSize: 18,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationPlaceholder extends StatelessWidget {
  const _OperationPlaceholder({
    required this.secondaryColor,
  });

  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(QHColors.surface, context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chart_bar_fill,
            color: CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '账户表现分析即将上线，敬请期待。',
              style: QHTypography.subheadline.copyWith(color: secondaryColor),
            ),
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

class _AggregatedHoldingCard extends StatelessWidget {
  const _AggregatedHoldingCard({
    required this.group,
    required this.onTrade,
    required this.onEdit,
    required this.onDelete,
  });

  final _AggregatedHoldingGroup group;
  final void Function(Holding holding) onTrade;
  final void Function(Holding holding) onEdit;
  final void Function(Holding holding) onDelete;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final dividerColor = CupertinoDynamicColor.resolve(CupertinoColors.separator, context);
    final accentColor = CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context);

    final quantityText = group.totalQuantity == group.totalQuantity.roundToDouble()
        ? group.totalQuantity.toStringAsFixed(0)
        : group.totalQuantity.toStringAsFixed(2);
    final averageCostText = group.averageCost > 0
        ? '¥${group.averageCost.toStringAsFixed(2)}'
        : '--';
    final latestPriceText = group.latestPrice != null
        ? '¥${group.latestPrice!.toStringAsFixed(2)}'
        : '--';
    final profitRateText = group.profitRate != null
        ? '${group.profitRate!.toStringAsFixed(2)}%'
        : '--';
    final todayProfitText = _formatSignedCurrency(group.todayProfit);
    final profitColor = _resolveChangeColor(group.unrealizedProfit);
    final todayProfitColor = _resolveChangeColor(group.todayProfit);

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.displayName,
                      style: QHTypography.subheadline.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (group.displayName.toUpperCase() != group.symbol.toUpperCase())
                      Text(
                        group.symbol,
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
                    _formatCurrency(group.marketValue),
                    style: QHTypography.subheadline.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formatSignedCurrency(group.unrealizedProfit),
                    style: QHTypography.footnote.copyWith(
                      color: profitColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  label: '持仓总量',
                  value: '$quantityText 股',
                  captionColor: secondaryColor,
                  valueColor: labelColor,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: '平均成本',
                  value: averageCostText,
                  captionColor: secondaryColor,
                  valueColor: labelColor,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: '现价',
                  value: latestPriceText,
                  captionColor: secondaryColor,
                  valueColor: labelColor,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: '盈亏率',
                  value: profitRateText,
                  captionColor: secondaryColor,
                  valueColor: profitColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  label: '今日盈亏',
                  value: todayProfitText,
                  captionColor: secondaryColor,
                  valueColor: todayProfitColor,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  label: '持仓数',
                  value: '${group.entries.length} 项',
                  captionColor: secondaryColor,
                  valueColor: labelColor,
                ),
              ),
              const Spacer(),
            ],
          ),
          if (group.portfolioNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: group.portfolioNames
                  .map(
                    (name) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          name,
                          style: QHTypography.footnote.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey6, context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (var i = 0; i < group.entries.length; i++) ...[
                  if (i != 0)
                    Container(
                      height: 1,
                      color: dividerColor.withOpacity(0.18),
                    ),
                  _UnderlyingHoldingRow(
                    entry: group.entries[i],
                    onTrade: onTrade,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required Color captionColor,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: captionColor),
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
}

class _UnderlyingHoldingRow extends StatelessWidget {
  const _UnderlyingHoldingRow({
    required this.entry,
    required this.onTrade,
    required this.onEdit,
    required this.onDelete,
  });

  final _UnderlyingHoldingInfo entry;
  final void Function(Holding holding) onTrade;
  final void Function(Holding holding) onEdit;
  final void Function(Holding holding) onDelete;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    final holding = entry.holding;
    final position = entry.position;
    final portfolioName = position?.portfolio.name ?? '未知组合';
    final quantityText = '${holding.quantity.toStringAsFixed(0)} 股';
    final costText = '成本 ¥${holding.averageCost.toStringAsFixed(2)}';
    final marketValue = position?.marketValue ?? holding.quantity * holding.averageCost;
    final marketText = '市值 ${_formatCurrency(marketValue)}';
    final profit = position?.unrealizedProfit ?? (marketValue - holding.quantity * holding.averageCost);
    final profitText = _formatSignedCurrency(profit);
    final profitColor = _resolveChangeColor(profit);

    final tradeColor = CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context);
    final editColor = CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context);
    final deleteColor = CupertinoDynamicColor.resolve(CupertinoColors.systemRed, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  portfolioName,
                  style: QHTypography.subheadline.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(quantityText, style: QHTypography.footnote.copyWith(color: secondaryColor)),
                    Text(costText, style: QHTypography.footnote.copyWith(color: secondaryColor)),
                    Text(marketText, style: QHTypography.footnote.copyWith(color: secondaryColor)),
                    Text(
                      profitText,
                      style: QHTypography.footnote.copyWith(
                        color: profitColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => onTrade(holding),
                child: Icon(
                  CupertinoIcons.arrow_2_squarepath,
                  size: 20,
                  color: tradeColor,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => onEdit(holding),
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 20,
                  color: editColor,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => onDelete(holding),
                child: Icon(
                  CupertinoIcons.delete,
                  size: 20,
                  color: deleteColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AggregatedHoldingGroup {
  const _AggregatedHoldingGroup({
    required this.symbol,
    required this.displayName,
    required this.entries,
    required this.totalQuantity,
    required this.totalCost,
    required this.marketValue,
    required this.unrealizedProfit,
    required this.todayProfit,
    this.latestPrice,
  });

  final String symbol;
  final String displayName;
  final List<_UnderlyingHoldingInfo> entries;
  final double totalQuantity;
  final double totalCost;
  final double marketValue;
  final double unrealizedProfit;
  final double todayProfit;
  final double? latestPrice;

  double get averageCost => totalQuantity <= 0 ? 0 : totalCost / totalQuantity;
  double? get profitRate => totalCost <= 0 ? null : (unrealizedProfit / totalCost) * 100;
  double? get todayProfitPercent {
    final previousValue = marketValue - todayProfit;
    if (previousValue <= 0) {
      return null;
    }
    return (todayProfit / previousValue) * 100;
  }

  List<String> get portfolioNames {
    final names = <String>{};
    for (final entry in entries) {
      final name = entry.position?.portfolio.name;
      if (name != null && name.trim().isNotEmpty) {
        names.add(name.trim());
      }
    }
    final list = names.toList()..sort();
    return list;
  }
}

class _UnderlyingHoldingInfo {
  const _UnderlyingHoldingInfo({
    required this.holding,
    required this.position,
  });

  final Holding holding;
  final HoldingPosition? position;
}

class _AggregatedHoldingGroupBuilder {
  _AggregatedHoldingGroupBuilder({
    required this.symbol,
    required String initialDisplayName,
  })  : displayName = initialDisplayName,
        _hasCustomDisplayName = initialDisplayName.trim().isNotEmpty &&
            initialDisplayName.toUpperCase() != symbol.toUpperCase();

  final String symbol;
  String displayName;
  final List<_UnderlyingHoldingInfo> entries = [];
  double totalQuantity = 0;
  double totalCost = 0;
  double marketValue = 0;
  double unrealizedProfit = 0;
  double todayProfit = 0;
  double? latestPrice;
  bool _hasCustomDisplayName;

  void add(Holding holding, HoldingPosition? position) {
    final quantity = holding.quantity;
    final cost = holding.averageCost * quantity;
    totalQuantity += quantity;
    totalCost += cost;

    final computedMarketValue =
        position?.marketValue ?? quantity * (position?.latestPrice ?? holding.averageCost);
    marketValue += computedMarketValue;

    final profit = position?.unrealizedProfit ?? (computedMarketValue - cost);
    unrealizedProfit += profit;

    todayProfit += position?.todayProfit ?? 0;

    final candidatePrice = position?.latestPrice;
    if (candidatePrice != null) {
      latestPrice ??= candidatePrice;
    }

    final candidateName = position?.displayName;
    if (!_hasCustomDisplayName &&
        candidateName != null &&
        candidateName.trim().isNotEmpty &&
        candidateName.toUpperCase() != symbol.toUpperCase()) {
      displayName = candidateName.trim();
      _hasCustomDisplayName = true;
    }

    entries.add(_UnderlyingHoldingInfo(holding: holding, position: position));
  }

  _AggregatedHoldingGroup build() {
    return _AggregatedHoldingGroup(
      symbol: symbol,
      displayName: displayName,
      entries: List.unmodifiable(entries),
      totalQuantity: totalQuantity,
      totalCost: totalCost,
      marketValue: marketValue,
      unrealizedProfit: unrealizedProfit,
      todayProfit: todayProfit,
      latestPrice: latestPrice,
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

String _formatChangeWithPercent(double amount, double? percent) {
  final amountText = _formatSignedCurrency(amount);
  if (percent == null) {
    return amountText;
  }
  final sign = percent >= 0 ? '+' : '';
  return '$amountText ($sign${percent.toStringAsFixed(2)}%)';
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