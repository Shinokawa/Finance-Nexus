import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../providers/repository_providers.dart';
import '../models/account_summary.dart';
import '../models/portfolio_summary.dart';

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

final portfoliosStreamProvider = StreamProvider<List<Portfolio>>((ref) {
  return ref.watch(portfolioRepositoryProvider).watchPortfolios();
});

final holdingsStreamProvider = StreamProvider<List<Holding>>((ref) {
  return ref.watch(holdingRepositoryProvider).watchHoldings();
});

final accountSummariesProvider = Provider<AsyncValue<List<AccountSummary>>>(
  (ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final holdingsAsync = ref.watch(holdingsStreamProvider);

    return accountsAsync.when(
      data: (accounts) {
        return holdingsAsync.when(
          data: (holdings) {
            final holdingsByAccount = <String, double>{};
            for (final holding in holdings) {
              holdingsByAccount.update(
                holding.accountId,
                (value) =>
                    value + (holding.quantity * holding.averageCost),
                ifAbsent: () => holding.quantity * holding.averageCost,
              );
            }
            final summaries = accounts
                .map(
                  (account) => AccountSummary(
                    account: account,
                    holdingsValue: holdingsByAccount[account.id] ?? 0.0,
                  ),
                )
                .toList();
            return AsyncValue.data(summaries);
          },
          loading: () => const AsyncValue.loading(),
          error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
        );
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    );
  },
);

final groupedAccountSummariesProvider =
    Provider<AsyncValue<Map<AccountType, List<AccountSummary>>>>((ref) {
  final summariesAsync = ref.watch(accountSummariesProvider);
  return summariesAsync.whenData((summaries) {
    final grouped = <AccountType, List<AccountSummary>>{};
    for (final summary in summaries) {
      grouped.putIfAbsent(summary.type, () => []).add(summary);
    }
    return grouped;
  });
});

final portfolioSummariesProvider = Provider<AsyncValue<List<PortfolioSummary>>>(
  (ref) {
    final portfoliosAsync = ref.watch(portfoliosStreamProvider);
    final holdingsAsync = ref.watch(holdingsStreamProvider);

    return portfoliosAsync.when(
      data: (portfolios) {
        return holdingsAsync.when(
          data: (holdings) {
            final holdingsByPortfolio = <String, double>{};
            for (final holding in holdings) {
              holdingsByPortfolio.update(
                holding.portfolioId,
                (value) =>
                    value + (holding.quantity * holding.averageCost),
                ifAbsent: () => holding.quantity * holding.averageCost,
              );
            }
            final summaries = portfolios
                .map(
                  (portfolio) => PortfolioSummary(
                    portfolio: portfolio,
                    holdingsValue:
                        holdingsByPortfolio[portfolio.id] ?? 0.0,
                  ),
                )
                .toList();
            return AsyncValue.data(summaries);
          },
          loading: () => const AsyncValue.loading(),
          error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
        );
      },
      loading: () => const AsyncValue.loading(),
      error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
    );
  },
);
