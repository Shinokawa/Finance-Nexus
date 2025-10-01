import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/account_repository.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/holding_repository.dart';
import '../data/repositories/portfolio_repository.dart';
import '../data/repositories/quote_repository.dart';
import '../data/repositories/transaction_repository.dart';
import 'dao_providers.dart';
import 'network_providers.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(accountDaoProvider)),
);

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => PortfolioRepository(ref.watch(portfolioDaoProvider)),
);

final holdingRepositoryProvider = Provider<HoldingRepository>(
  (ref) => HoldingRepository(ref.watch(holdingDaoProvider)),
);

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(
    ref.watch(transactionDaoProvider),
    ref.watch(accountDaoProvider),
  ),
);

final quoteRepositoryProvider = Provider<QuoteRepository>(
  (ref) => QuoteRepository(ref.watch(quoteApiClientProvider)),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(budgetDaoProvider)),
);
