import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/account_repository.dart';
import '../../accounts/providers/account_summary_providers.dart';
import '../../ledger/providers/transaction_providers.dart';
import '../models/holding_position.dart';
import 'holding_positions_provider.dart';

class DashboardData {
  const DashboardData({
    required this.totalNetWorth,
    required this.totalCostBasis,
    required this.totalUnrealizedProfit,
    required this.totalRealizedProfit,
    required this.totalTradingCost,
    required this.todayChange,
    required this.todayChangePercent,
    required this.portfolioRows,
    required this.accountRows,
    required this.portfolioSnapshots,
    required this.accountSnapshots,
    required this.currentMonthExpense,
    required this.currentMonthIncome,
  });

  final double totalNetWorth;
  final double totalCostBasis;
  final double totalUnrealizedProfit;
  final double totalRealizedProfit;
  final double totalTradingCost;
  final double todayChange;
  final double todayChangePercent;
  final List<DashboardAssetRow> portfolioRows;
  final List<DashboardAssetRow> accountRows;
  final Map<String, PortfolioSnapshot> portfolioSnapshots;
  final Map<String, AccountSnapshot> accountSnapshots;
  final double currentMonthExpense;
  final double currentMonthIncome;

  double get totalNetProfit =>
      totalUnrealizedProfit + totalRealizedProfit - totalTradingCost;
}

class DashboardAssetRow {
  const DashboardAssetRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.marketValue,
    required this.costBasis,
    required this.unrealizedProfit,
    required this.unrealizedPercent,
  required this.realizedProfit,
  required this.tradingCost,
    required this.todayProfit,
    required this.todayProfitPercent,
    required this.share,
    this.category,
    this.holdingsCount = 0,
    this.cashBalance,
  });

  final String id;
  final String title;
  final String subtitle;
  final double marketValue;
  final double costBasis;
  final double unrealizedProfit;
  final double? unrealizedPercent;
  final double realizedProfit;
  final double tradingCost;
  final double todayProfit;
  final double? todayProfitPercent;
  final double share;
  final AccountType? category;
  final int holdingsCount;
  final double? cashBalance;

  double get netProfit => unrealizedProfit + realizedProfit - tradingCost;
}

class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.portfolio,
    required this.positions,
    required this.marketValue,
    required this.costBasis,
    required this.unrealizedProfit,
    required this.unrealizedPercent,
    required this.realizedProfit,
    required this.tradingCost,
    required this.todayProfit,
    required this.todayProfitPercent,
  });

  final Portfolio portfolio;
  final List<HoldingPosition> positions;
  final double marketValue;
  final double costBasis;
  final double unrealizedProfit;
  final double? unrealizedPercent;
  final double realizedProfit;
  final double tradingCost;
  final double todayProfit;
  final double? todayProfitPercent;

  int get holdingsCount => positions.length;

  double get netProfit => unrealizedProfit + realizedProfit - tradingCost;
}

class AccountSnapshot {
  const AccountSnapshot({
    required this.account,
    required this.positions,
    required this.totalValue,
    required this.marketValue,
    required this.costBasis,
    required this.unrealizedProfit,
    required this.unrealizedPercent,
    required this.realizedProfit,
    required this.tradingCost,
    required this.todayProfit,
    required this.todayProfitPercent,
    required this.cashBalance,
  });

  final Account account;
  final List<HoldingPosition> positions;
  final double totalValue;
  final double marketValue;
  final double costBasis;
  final double unrealizedProfit;
  final double? unrealizedPercent;
  final double realizedProfit;
  final double tradingCost;
  final double todayProfit;
  final double? todayProfitPercent;
  final double cashBalance;

  int get holdingsCount => positions.length;

  double get netProfit => unrealizedProfit + realizedProfit - tradingCost;
}

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);

  final accounts = await ref.watch(accountsStreamProvider.future);
  final portfolios = await ref.watch(portfoliosStreamProvider.future);
  final positions = await ref.watch(holdingPositionsProvider.future);
  final transactions = await ref.watch(transactionsStreamProvider.future);

  final currentMonthExpense = transactions.where((transaction) {
    if (transaction.type != TransactionType.expense) {
      return false;
    }
    return !transaction.date.isBefore(monthStart);
  }).fold<double>(0, (sum, txn) => sum + txn.amount.abs());

  final currentMonthIncome = transactions.where((transaction) {
    if (transaction.type != TransactionType.income) {
      return false;
    }
    return !transaction.date.isBefore(monthStart);
  }).fold<double>(0, (sum, txn) => sum + txn.amount.abs());

  final accountMap = {for (final account in accounts) account.id: account};
  final positionsByPortfolio = groupBy(positions, (HoldingPosition position) => position.portfolio.id);
  final positionsByAccount = groupBy(positions, (HoldingPosition position) => position.account.id);
  final positionsByHoldingId = {
    for (final position in positions) position.holding.id: position,
  };

  final totalHoldingsCost = positions.fold<double>(0, (sum, position) => sum + position.costBasis);
  final totalHoldingsTodayProfit = positions.fold<double>(0, (sum, position) => sum + (position.todayProfit ?? 0));

  final tradesByAccount = <String, _TradeAggregation>{};
  final tradesByPortfolio = <String, _TradeAggregation>{};
  final totalTrades = _TradeAggregation();

  for (final transaction in transactions) {
    if (transaction.type != TransactionType.buy && transaction.type != TransactionType.sell) {
      continue;
    }

    final accountId = transaction.type == TransactionType.buy
        ? transaction.fromAccountId
        : transaction.toAccountId;
    if (accountId == null) {
      continue;
    }
    final account = accountMap[accountId];
    if (account == null || account.type != AccountType.investment) {
      continue;
    }

  final amount = transaction.amount.abs();
  final commission = _calculateCommission(amount, account.commissionRate);
    final stampTax = transaction.type == TransactionType.sell ? amount * account.stampTaxRate : 0.0;

    final accountTrades = tradesByAccount.putIfAbsent(accountId, _TradeAggregation.new);
    if (transaction.type == TransactionType.buy) {
      accountTrades.addBuy(amount, commission);
      totalTrades.addBuy(amount, commission);
    } else {
      accountTrades.addSell(amount, commission, stampTax);
      totalTrades.addSell(amount, commission, stampTax);
    }

    final holdingId = transaction.relatedHoldingId;
    if (holdingId == null) {
      continue;
    }
    final position = positionsByHoldingId[holdingId];
    if (position == null) {
      continue;
    }
    final portfolioId = position.portfolio.id;
    final portfolioTrades = tradesByPortfolio.putIfAbsent(portfolioId, _TradeAggregation.new);
    if (transaction.type == TransactionType.buy) {
      portfolioTrades.addBuy(amount, commission);
    } else {
      portfolioTrades.addSell(amount, commission, stampTax);
    }
  }

  double totalCashBalances = 0;
  double totalLiabilityPrincipal = 0;
  double totalNetWorth = 0;

  final accountSnapshots = <String, AccountSnapshot>{};

  for (final account in accounts) {
    final relatedPositions = positionsByAccount[account.id] ?? const <HoldingPosition>[];
    final holdingsMarketValue = _sumMarketValue(relatedPositions);
    final holdingsCost = _sumCostBasis(relatedPositions);
    final holdingsTodayProfit = _sumTodayProfit(relatedPositions);
    final holdingsUnrealizedProfit = holdingsMarketValue - holdingsCost;
    final holdingsUnrealizedPercent =
        holdingsCost == 0 ? null : (holdingsUnrealizedProfit / holdingsCost) * 100;
    final holdingsTodayPercent = _weightedChangePercent(relatedPositions);

    double contribution;
    double cashBalance = 0;
    switch (account.type) {
      case AccountType.investment:
        cashBalance = account.balance;
        contribution = account.balance + holdingsMarketValue;
        totalCashBalances += account.balance;
        break;
      case AccountType.cash:
        cashBalance = account.balance;
        contribution = account.balance;
        totalCashBalances += account.balance;
        break;
      case AccountType.liability:
        contribution = -account.balance.abs();
        totalLiabilityPrincipal += account.balance.abs();
        break;
    }

    totalNetWorth += contribution;

    final trades = tradesByAccount[account.id];
    final realizedProfit = account.type == AccountType.investment
        ? _calculateRealizedProfit(trades, holdingsCost)
        : 0.0;
    final tradingCost = account.type == AccountType.investment ? (trades?.tradingCost ?? 0.0) : 0.0;

    accountSnapshots[account.id] = AccountSnapshot(
      account: account,
      positions: relatedPositions,
      totalValue: contribution,
      marketValue: holdingsMarketValue,
      costBasis: switch (account.type) {
        AccountType.investment => holdingsCost,
        AccountType.cash => account.balance,
        AccountType.liability => account.balance.abs(),
      },
      unrealizedProfit: account.type == AccountType.liability ? 0 : holdingsUnrealizedProfit,
      unrealizedPercent: account.type == AccountType.liability ? null : holdingsUnrealizedPercent,
      realizedProfit: realizedProfit,
      tradingCost: tradingCost,
      todayProfit: account.type == AccountType.liability ? 0 : holdingsTodayProfit,
      todayProfitPercent: account.type == AccountType.liability
          ? null
          : (relatedPositions.isEmpty
              ? (account.type == AccountType.cash ? 0 : null)
              : holdingsTodayPercent),
      cashBalance: cashBalance,
    );
  }

  final portfolioSnapshots = <String, PortfolioSnapshot>{};
  final portfolioRows = <DashboardAssetRow>[];

  for (final portfolio in portfolios) {
    final relatedPositions = positionsByPortfolio[portfolio.id] ?? const <HoldingPosition>[];
    final marketValue = _sumMarketValue(relatedPositions);
    final costBasis = _sumCostBasis(relatedPositions);
    final todayProfit = _sumTodayProfit(relatedPositions);
    final unrealizedProfit = marketValue - costBasis;
    final unrealizedPercent = costBasis == 0 ? null : (unrealizedProfit / costBasis) * 100;
    final todayPercent = relatedPositions.isEmpty ? null : _weightedChangePercent(relatedPositions);
    final share = totalNetWorth == 0 ? 0.0 : marketValue / totalNetWorth;
    final holdingsCount = relatedPositions.length;
    final subtitle = portfolio.description?.trim().isNotEmpty == true
        ? portfolio.description!.trim()
        : '持仓 $holdingsCount 项';

    final trades = tradesByPortfolio[portfolio.id];
    final realizedProfit = trades == null ? 0.0 : _calculateRealizedProfit(trades, costBasis);
    final tradingCost = trades?.tradingCost ?? 0.0;

    portfolioRows.add(
      DashboardAssetRow(
        id: portfolio.id,
        title: portfolio.name,
        subtitle: subtitle,
        marketValue: marketValue,
        costBasis: costBasis,
        unrealizedProfit: unrealizedProfit,
        unrealizedPercent: unrealizedPercent,
        realizedProfit: realizedProfit,
        tradingCost: tradingCost,
        todayProfit: todayProfit,
        todayProfitPercent: todayPercent,
        share: share,
        holdingsCount: holdingsCount,
      ),
    );

    portfolioSnapshots[portfolio.id] = PortfolioSnapshot(
      portfolio: portfolio,
      positions: relatedPositions,
      marketValue: marketValue,
      costBasis: costBasis,
      unrealizedProfit: unrealizedProfit,
      unrealizedPercent: unrealizedPercent,
      realizedProfit: realizedProfit,
      tradingCost: tradingCost,
      todayProfit: todayProfit,
      todayProfitPercent: todayPercent,
    );
  }

  final accountRows = <DashboardAssetRow>[];
  for (final snapshot in accountSnapshots.values) {
    final account = snapshot.account;
    final subtitle = switch (account.type) {
      AccountType.investment => '持仓 ${snapshot.holdingsCount} 项',
      AccountType.cash => '现金账户',
      AccountType.liability => '负债账户',
    };
    final share = totalNetWorth == 0 ? 0.0 : snapshot.totalValue / totalNetWorth;

    final costBasis = account.type == AccountType.investment
        ? snapshot.costBasis + snapshot.cashBalance
        : snapshot.costBasis;

    accountRows.add(
      DashboardAssetRow(
        id: account.id,
        title: account.name,
        subtitle: subtitle,
        marketValue: snapshot.totalValue,
        costBasis: costBasis,
        unrealizedProfit: snapshot.unrealizedProfit,
        unrealizedPercent: snapshot.unrealizedPercent,
        realizedProfit: account.type == AccountType.investment ? snapshot.realizedProfit : 0.0,
        tradingCost: account.type == AccountType.investment ? snapshot.tradingCost : 0.0,
        todayProfit: snapshot.todayProfit,
        todayProfitPercent: snapshot.todayProfitPercent,
        share: share,
        category: account.type,
        holdingsCount: snapshot.holdingsCount,
        cashBalance: snapshot.cashBalance,
      ),
    );
  }

  final totalCostBasis = totalCashBalances + totalHoldingsCost - totalLiabilityPrincipal;
  final totalUnrealizedProfit = totalNetWorth - totalCostBasis;
  final totalRealizedProfit = _calculateRealizedProfit(totalTrades, totalHoldingsCost);
  final totalTradingCost = totalTrades.tradingCost;
  final totalTodayChangePercent =
      totalNetWorth == 0 ? 0.0 : (totalHoldingsTodayProfit / totalNetWorth) * 100;

  portfolioRows.sort((a, b) => b.marketValue.compareTo(a.marketValue));
  accountRows.sort((a, b) => b.marketValue.compareTo(a.marketValue));

  return DashboardData(
    totalNetWorth: totalNetWorth,
    totalCostBasis: totalCostBasis,
    totalUnrealizedProfit: totalUnrealizedProfit,
    totalRealizedProfit: totalRealizedProfit,
    totalTradingCost: totalTradingCost,
    todayChange: totalHoldingsTodayProfit,
    todayChangePercent: totalTodayChangePercent,
    portfolioRows: portfolioRows,
    accountRows: accountRows,
    portfolioSnapshots: portfolioSnapshots,
    accountSnapshots: accountSnapshots,
    currentMonthExpense: currentMonthExpense,
    currentMonthIncome: currentMonthIncome,
  );
});

double _calculateRealizedProfit(_TradeAggregation? trades, double currentCost) {
  if (trades == null || trades.sellAmount == 0) {
    return 0.0;
  }
  final soldCost = math.max(0.0, trades.buyAmount - currentCost);
  return trades.sellAmount - soldCost;
}

double _calculateCommission(double amount, double rate) {
  if (amount <= 0) {
    return 0.0;
  }
  final effectiveRate = math.max(rate, AccountRepository.minCommissionRate);
  return math.max(amount * effectiveRate, AccountRepository.minCommissionPerTrade);
}

class _TradeAggregation {
  _TradeAggregation();

  double buyAmount = 0;
  double sellAmount = 0;
  double commission = 0;
  double stampTax = 0;

  double get tradingCost => commission + stampTax;

  void addBuy(double amount, double commission) {
    buyAmount += amount;
    this.commission += commission;
  }

  void addSell(double amount, double commission, double stampTax) {
    sellAmount += amount;
    this.commission += commission;
    this.stampTax += stampTax;
  }
}

double _sumMarketValue(Iterable<HoldingPosition> positions) {
  return positions.fold<double>(0, (sum, position) => sum + position.marketValue);
}

double _sumCostBasis(Iterable<HoldingPosition> positions) {
  return positions.fold<double>(0, (sum, position) => sum + position.costBasis);
}

double _sumTodayProfit(Iterable<HoldingPosition> positions) {
  return positions.fold<double>(
    0,
    (sum, position) => sum + (position.todayProfit ?? 0),
  );
}

double? _weightedChangePercent(Iterable<HoldingPosition> positions) {
  double weightedSum = 0;
  double totalWeight = 0;
  for (final position in positions) {
    final percent = position.changePercent;
    if (percent == null) {
      continue;
    }
    final weight = position.marketValue;
    weightedSum += percent * weight;
    totalWeight += weight;
  }
  if (totalWeight == 0) {
    return null;
  }
  return weightedSum / totalWeight;
}

// 获取特定账户的快照数据
final accountSnapshotProvider = FutureProvider.family<AccountSnapshot?, String>((ref, accountId) async {
  final dashboardData = await ref.watch(dashboardDataProvider.future);
  return dashboardData.accountSnapshots[accountId];
});
