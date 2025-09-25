import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/repository_providers.dart';
import '../../accounts/providers/account_summary_providers.dart';
import '../models/holding_position.dart';

final holdingPositionsProvider = FutureProvider.autoDispose<List<HoldingPosition>>((ref) async {
  final holdings = await ref.watch(holdingsStreamProvider.future);
  if (holdings.isEmpty) {
    return const [];
  }

  final accounts = await ref.watch(accountsStreamProvider.future);
  final portfolios = await ref.watch(portfoliosStreamProvider.future);
  final quoteRepository = ref.watch(quoteRepositoryProvider);

  final symbols = holdings.map((holding) => holding.symbol).where((symbol) => symbol.trim().isNotEmpty).toSet().toList();
  final quotes = await quoteRepository.fetchQuotes(symbols);
  final quoteMap = {for (final quote in quotes) quote.symbol: quote};

  final accountMap = {for (final account in accounts) account.id: account};
  final portfolioMap = {for (final portfolio in portfolios) portfolio.id: portfolio};

  final positions = <HoldingPosition>[];
  for (final holding in holdings) {
    final account = accountMap[holding.accountId];
    final portfolio = portfolioMap[holding.portfolioId];
    if (account == null || portfolio == null) {
      continue;
    }
    final quote = quoteMap[holding.symbol];
    positions.add(
      HoldingPosition(
        holding: holding,
        account: account,
        portfolio: portfolio,
        quote: quote,
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
