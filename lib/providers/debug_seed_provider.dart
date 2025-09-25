import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/enums.dart';
import '../data/local/app_database.dart';
import 'dao_providers.dart';

/// Inserts deterministic demo data into the local database.
///
/// This provider will clear and re-insert demo data every time the app starts
/// to ensure we always have the latest test data for development.
final debugSeedProvider = FutureProvider<void>((ref) async {
  final accountDao = ref.read(accountDaoProvider);
  final portfolioDao = ref.read(portfolioDaoProvider);
  final holdingDao = ref.read(holdingDaoProvider);

  // Clear all existing data
  await holdingDao.deleteAllHoldings();
  await portfolioDao.deleteAllPortfolios();
  await accountDao.deleteAllAccounts();

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
      balance: const Value(85000.0), // 调整为合理的剩余资金
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

  // A股核心组合持仓（基于2024年9月25日真实价格）
  // 国电电力 600795 - 2024.9.25收盘价: 4.91
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-600795'),
      symbol: '600795',
      quantity: const Value(2000.0),
      averageCost: const Value(4.91), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioCoreId,
    ),
  );

  // 贵州茅台 600519 - 2024.9.25收盘价: 1347.52
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-600519'),
      symbol: '600519',
      quantity: const Value(100.0),
      averageCost: const Value(1347.52), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioCoreId,
    ),
  );

  // 五粮液 000858 - 2024.9.25收盘价: 116.36
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-000858'),
      symbol: '000858',
      quantity: const Value(500.0),
      averageCost: const Value(116.36), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioCoreId,
    ),
  );

  // 成长股投资组合持仓
  // 宁德时代 300750 - 2024.9.25收盘价: 196.34
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-300750'),
      symbol: '300750',
      quantity: const Value(300.0),
      averageCost: const Value(196.34), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 海康威视 002415 - 2024.9.25收盘价: 26.21
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-002415'),
      symbol: '002415',
      quantity: const Value(1000.0),
      averageCost: const Value(26.21), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 平安银行 000001 - 2024.9.25收盘价: 9.89
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-000001'),
      symbol: '000001',
      quantity: const Value(3000.0),
      averageCost: const Value(9.89), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );

  // 银行ETF 159819 - 2024.9.25收盘价: 0.655
  await holdingDao.insertHolding(
    HoldingsCompanion.insert(
      id: const Value('holding-159819'),
      symbol: '159819',
      quantity: const Value(15000.0),
      averageCost: const Value(0.655), // 按2024.9.25收盘价买入
      accountId: investmentAccountId,
      portfolioId: portfolioGrowthId,
    ),
  );
});
