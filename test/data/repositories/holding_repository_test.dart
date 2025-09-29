import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:finanexus/core/enums.dart';
import 'package:finanexus/data/local/app_database.dart';
import 'package:finanexus/data/repositories/holding_repository.dart';

void main() {
  late AppDatabase database;
  late HoldingRepository repository;
  const accountId = 'acc-test';
  const portfolioA = 'pf-a';
  const portfolioB = 'pf-b';

  setUp(() async {
    database = AppDatabase.inMemory();
    repository = HoldingRepository(database.holdingDao);

    await database.into(database.accounts).insert(
      AccountsCompanion.insert(
        id: Value(accountId),
        name: '测试证券账户',
        type: AccountType.investment,
      ),
    );

    await database.into(database.portfolios).insert(
      PortfoliosCompanion.insert(
        id: Value(portfolioA),
        name: '组合A',
      ),
    );

    await database.into(database.portfolios).insert(
      PortfoliosCompanion.insert(
        id: Value(portfolioB),
        name: '组合B',
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createHolding merges identical symbols within the same portfolio', () async {
    await repository.createHolding(
      symbol: 'AAPL',
      quantity: 10,
      averageCost: 100,
      accountId: accountId,
      portfolioId: portfolioA,
    );

    await repository.createHolding(
      symbol: 'aapl',
      quantity: 5,
      averageCost: 120,
      accountId: accountId,
      portfolioId: portfolioA,
    );

    final holdings = await repository.getHoldingsByPortfolio(portfolioA);
    expect(holdings.length, 1);

    final holding = holdings.first;
    expect(holding.symbol, 'AAPL');
    expect(holding.quantity, closeTo(15, 1e-6));
    expect(
      holding.averageCost,
      closeTo(((10 * 100) + (5 * 120)) / 15, 1e-6),
    );
  });

  test('createHolding keeps positions separate across portfolios', () async {
    await repository.createHolding(
      symbol: 'TSLA',
      quantity: 3,
      averageCost: 200,
      accountId: accountId,
      portfolioId: portfolioA,
    );

    await repository.createHolding(
      symbol: 'TSLA',
      quantity: 2,
      averageCost: 220,
      accountId: accountId,
      portfolioId: portfolioB,
    );

    final holdingsA = await repository.getHoldingsByPortfolio(portfolioA);
    final holdingsB = await repository.getHoldingsByPortfolio(portfolioB);

    expect(holdingsA.length, 1);
    expect(holdingsA.first.quantity, closeTo(3, 1e-6));

    expect(holdingsB.length, 1);
    expect(holdingsB.first.quantity, closeTo(2, 1e-6));
  });
}
