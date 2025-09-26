import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';
import '../data/local/app_database.dart';
import 'dao_providers.dart';

/// Inserts deterministic demo data into the local database.
///
/// This provider will insert demo data only if the database is empty,
/// allowing data persistence for testing purposes.
final debugSeedProvider = FutureProvider<void>((ref) async {
  final accountDao = ref.read(accountDaoProvider);
  final portfolioDao = ref.read(portfolioDaoProvider);
  final holdingDao = ref.read(holdingDaoProvider);
  final transactionDao = ref.read(transactionDaoProvider);

  // Check if data already exists
  final existingAccounts = await accountDao.getAllAccounts();
  if (existingAccounts.isNotEmpty) {
    // Data already exists, skip seeding
    return;
  }

  const investmentAccountId = 'acc-investment-mainland';
  const cashAccountId = 'acc-cash-main';
  const liabilityAccountId = 'acc-liability-card';
  const portfolioCoreId = 'portfolio-core-a';
  const portfolioGrowthId = 'portfolio-growth-a';

  await accountDao.insertAccount(
    AccountsCompanion.insert(
      id: const Value(investmentAccountId),
      name: '华泰证券 · A股账户',
      type: AccountType.investment,
      balance: const Value(15000.0), // 扣除建仓成本后的剩余资金
    ),
  );

  await accountDao.insertAccount(
    AccountsCompanion.insert(
      id: const Value(cashAccountId),
      name: '建设银行储蓄卡',
      type: AccountType.cash,
      balance: const Value(128500.0),
    ),
  );

  await accountDao.insertAccount(
    AccountsCompanion.insert(
      id: const Value('acc-cash-wechat'),
      name: '微信钱包',
      type: AccountType.cash,
      balance: const Value(3420.0),
    ),
  );

  await accountDao.insertAccount(
    AccountsCompanion.insert(
      id: const Value('acc-cash-alipay'),
      name: '支付宝余额',
      type: AccountType.cash,
      balance: const Value(1280.0),
    ),
  );

  await accountDao.insertAccount(
    AccountsCompanion.insert(
      id: const Value(liabilityAccountId),
      name: '花呗 · 当月待还',
      type: AccountType.liability,
      balance: const Value(18500.0),
    ),
  );

  await portfolioDao.insertPortfolio(
    PortfoliosCompanion.insert(
      id: const Value(portfolioCoreId),
      name: '价值蓝筹组合',
      description: const Value('茅台+五粮液等白马蓝筹股精选'),
    ),
  );

  await portfolioDao.insertPortfolio(
    PortfoliosCompanion.insert(
      id: const Value(portfolioGrowthId),
      name: '成长投资组合',
      description: const Value('新能源+金融+科技成长股配置'),
    ),
  );

  // A股核心组合持仓（基于2024年2月真实价格模拟建仓）
  // 国电电力 600795 - 2024.2.1收盘价: 4.13（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-600795'),
      symbol: '600795',
      quantity: const Value(2000.0),
      averageCost: const Value(4.13), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioCoreId,
    ),
  );

  // 贵州茅台 600519 - 2024.2.1收盘价: 1527.67（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-600519'),
      symbol: '600519',
      quantity: const Value(100.0),
      averageCost: const Value(1527.67), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioCoreId,
    ),
  );

  // 五粮液 000858 - 2024.2.1收盘价: 116.09（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-000858'),
      symbol: '000858',
      quantity: const Value(500.0),
      averageCost: const Value(116.09), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioCoreId,
    ),
  );

  // 成长股投资组合持仓（基于2024年2月真实价格模拟建仓）
  // 宁德时代 300750 - 2024.2.1收盘价: 137.23（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-300750'),
      symbol: '300750',
      quantity: const Value(300.0),
      averageCost: const Value(137.23), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 海康威视 002415 - 2024.2.1收盘价: 30.28（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-002415'),
      symbol: '002415',
      quantity: const Value(1000.0),
      averageCost: const Value(30.28), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 平安银行 000001 - 2024.2.1收盘价: 8.08（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-000001'),
      symbol: '000001',
      quantity: const Value(3000.0),
      averageCost: const Value(8.08), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 银行ETF 159819 - 2024.2.1收盘价: 0.608（去年建仓成本）
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-159819'),
      symbol: '159819',
      quantity: const Value(15000.0),
      averageCost: const Value(0.608), // 按2024.2.1价格建仓
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 创建对应的买入交易记录（2024年2月1日建仓）
  final purchaseDate = DateTime(2024, 2, 1, 10, 30);

  // 国电电力买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 8260.0, // 2000股 * 4.13
      fromAccountId: Value(investmentAccountId),
      category: const Value('股票买入'),
      notes: const Value('国电电力 600795 建仓'),
      date: Value(purchaseDate),
      relatedHoldingId: const Value('holding-600795'),
    ),
  );

  // 贵州茅台买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 152767.0, // 100股 * 1527.67
      fromAccountId: Value(investmentAccountId),
      category: const Value('股票买入'),
      notes: const Value('贵州茅台 600519 建仓'),
      date: Value(purchaseDate.add(const Duration(minutes: 15))),
      relatedHoldingId: const Value('holding-600519'),
    ),
  );

  // 五粮液买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 58045.0, // 500股 * 116.09
      fromAccountId: Value(investmentAccountId),
      category: const Value('股票买入'),
      notes: const Value('五粮液 000858 建仓'),
      date: Value(purchaseDate.add(const Duration(minutes: 30))),
      relatedHoldingId: const Value('holding-000858'),
    ),
  );

  // 宁德时代买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 41169.0, // 300股 * 137.23
      fromAccountId: Value(investmentAccountId),
      category: const Value('股票买入'),
      notes: const Value('宁德时代 300750 建仓'),
      date: Value(purchaseDate.add(const Duration(minutes: 45))),
      relatedHoldingId: const Value('holding-300750'),
    ),
  );

  // 海康威视买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 30280.0, // 1000股 * 30.28
      fromAccountId: Value(investmentAccountId),
      category: const Value('股票买入'),
      notes: const Value('海康威视 002415 建仓'),
      date: Value(purchaseDate.add(const Duration(hours: 1))),
      relatedHoldingId: const Value('holding-002415'),
    ),
  );

  // 平安银行买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 24240.0, // 3000股 * 8.08
      fromAccountId: Value(investmentAccountId),
      category: const Value('股票买入'),
      notes: const Value('平安银行 000001 建仓'),
      date: Value(purchaseDate.add(const Duration(hours: 1, minutes: 15))),
      relatedHoldingId: const Value('holding-000001'),
    ),
  );

  // 银行ETF买入交易
  await transactionDao.insertTransaction(
    TransactionsCompanion.insert(
      type: TransactionType.buy,
      amount: 9120.0, // 15000股 * 0.608
      fromAccountId: Value(investmentAccountId),
      category: const Value('ETF买入'),
      notes: const Value('银行ETF 159819 建仓'),
      date: Value(purchaseDate.add(const Duration(hours: 1, minutes: 30))),
      relatedHoldingId: const Value('holding-159819'),
    ),
  );
});
