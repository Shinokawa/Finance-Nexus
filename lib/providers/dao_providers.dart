import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import 'database_provider.dart';

final accountDaoProvider = Provider<AccountDao>(
  (ref) => ref.watch(appDatabaseProvider).accountDao,
);

final portfolioDaoProvider = Provider<PortfolioDao>(
  (ref) => ref.watch(appDatabaseProvider).portfolioDao,
);

final holdingDaoProvider = Provider<HoldingDao>(
  (ref) => ref.watch(appDatabaseProvider).holdingDao,
);

final transactionDaoProvider = Provider<TransactionDao>(
  (ref) => ref.watch(appDatabaseProvider).transactionDao,
);

final budgetDaoProvider = Provider<BudgetDao>(
  (ref) => ref.watch(appDatabaseProvider).budgetDao,
);
