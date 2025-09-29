import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../providers/repository_providers.dart';
import '../../accounts/providers/account_summary_providers.dart';
import '../../ledger/providers/transaction_providers.dart';
import '../models/holding_position.dart';

final holdingPositionsProvider = FutureProvider.autoDispose<List<HoldingPosition>>((ref) async {
  final holdings = await ref.watch(holdingsStreamProvider.future);
  if (holdings.isEmpty) {
    return const [];
  }

  final accounts = await ref.watch(accountsStreamProvider.future);
  final portfolios = await ref.watch(portfoliosStreamProvider.future);
  final quoteRepository = ref.watch(quoteRepositoryProvider);
  final transactions = await ref.watch(transactionsStreamProvider.future);

  final symbols = holdings.map((holding) => holding.symbol).where((symbol) => symbol.trim().isNotEmpty).toSet().toList();
  final quotes = await quoteRepository.fetchQuotes(symbols);
  final quoteMap = {for (final quote in quotes) quote.symbol: quote};

  final accountMap = {for (final account in accounts) account.id: account};
  final portfolioMap = {for (final portfolio in portfolios) portfolio.id: portfolio};
  final tradesByHolding = <String, _TradeAggregation>{};

  for (final transaction in transactions) {
    if (transaction.type != TransactionType.buy && transaction.type != TransactionType.sell) {
      continue;
    }

    final holdingId = transaction.relatedHoldingId;
    if (holdingId == null) {
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

    final trades = tradesByHolding.putIfAbsent(holdingId, _TradeAggregation.new);
    if (transaction.type == TransactionType.buy) {
      trades.addBuy(amount, commission);
    } else {
      trades.addSell(amount, commission, stampTax);
    }
  }

  final positions = <HoldingPosition>[];
  for (final holding in holdings) {
    final account = accountMap[holding.accountId];
    final portfolio = portfolioMap[holding.portfolioId];
    if (account == null || portfolio == null) {
      continue;
    }
    final quote = quoteMap[holding.symbol];
    final trades = tradesByHolding[holding.id];
    final costBasis = holding.averageCost * holding.quantity;
    final realizedProfit = trades == null ? 0.0 : _calculateRealizedProfit(trades, costBasis);
    final tradingCost = trades?.tradingCost ?? 0.0;
    final totalBuyAmount = trades?.buyAmount;
    positions.add(
      HoldingPosition(
        holding: holding,
        account: account,
        portfolio: portfolio,
        quote: quote,
        realizedProfit: realizedProfit,
        tradingCost: tradingCost,
        totalBuyAmount: totalBuyAmount,
      ),
    );
  }

  positions.sort((a, b) => b.marketValue.compareTo(a.marketValue));
  return positions;
});

final filteredHoldingPositionsProvider = FutureProvider.autoDispose.family<List<HoldingPosition>, String?>((ref, portfolioId) async {
  final positions = await ref.watch(holdingPositionsProvider.future);
  if (portfolioId == null || portfolioId.isEmpty) {
    return positions;
  }
  return positions.where((position) => position.portfolio.id == portfolioId).toList();
});

double _calculateRealizedProfit(_TradeAggregation trades, double currentCost) {
  if (trades.sellAmount == 0) {
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
