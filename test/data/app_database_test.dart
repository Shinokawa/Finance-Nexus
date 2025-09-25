import 'package:flutter_test/flutter_test.dart';
import 'package:quant_hub/core/enums.dart';
import 'package:quant_hub/data/local/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.inMemory();
    });

    tearDown(() async {
      await db.close();
    });

    test('inserts and reads account', () async {
      final accountDao = db.accountDao;
      final accountId = const Uuid().v4();

      await accountDao.insertAccount(
        AccountsCompanion.insert(
          id: Value(accountId),
          name: '招商证券户',
          type: AccountType.investment,
          balance: const Value(5000),
        ),
      );

      final fetched = await accountDao.getAccountById(accountId);
      expect(fetched, isNotNull);
      expect(fetched!.balance, 5000);
      expect(fetched.type, AccountType.investment);
    });

    test('links holdings to portfolio and account', () async {
      final accountId = const Uuid().v4();
      final portfolioId = const Uuid().v4();
      await db.accountDao.insertAccount(
        AccountsCompanion.insert(
          id: Value(accountId),
          name: '现金账户',
          type: AccountType.cash,
        ),
      );
      await db.portfolioDao.insertPortfolio(
        PortfoliosCompanion.insert(
          id: Value(portfolioId),
          name: '主动投资',
          description: const Value('高波动策略'),
        ),
      );

      final holdingId = const Uuid().v4();
      await db.holdingDao.insertHolding(
        HoldingsCompanion.insert(
          id: Value(holdingId),
          symbol: 'sh600519',
          quantity: const Value(10),
          averageCost: const Value(1500.5),
          accountId: accountId,
          portfolioId: portfolioId,
        ),
      );

      final holdingsByPortfolio =
          await db.holdingDao.getHoldingsByPortfolio(portfolioId);
      expect(holdingsByPortfolio, hasLength(1));
      expect(holdingsByPortfolio.first.id, holdingId);

      final holdingsByAccount =
          await db.holdingDao.getHoldingsByAccount(accountId);
      expect(holdingsByAccount, hasLength(1));
      expect(holdingsByAccount.first.symbol, 'sh600519');
    });

    test('records cash transfer transactions', () async {
      final fromAccountId = const Uuid().v4();
      final toAccountId = const Uuid().v4();

      await db.accountDao.insertAccount(
        AccountsCompanion.insert(
          id: Value(fromAccountId),
          name: '工资卡',
          type: AccountType.cash,
          balance: const Value(10000),
        ),
      );
      await db.accountDao.insertAccount(
        AccountsCompanion.insert(
          id: Value(toAccountId),
          name: '投资账户',
          type: AccountType.investment,
          balance: const Value(2000),
        ),
      );

      await db.transactionDao.insertTransaction(
        TransactionsCompanion.insert(
          id: Value(const Uuid().v4()),
          amount: 3000,
          type: TransactionType.transfer,
          category: const Value('资金划转'),
          fromAccountId: Value(fromAccountId),
          toAccountId: Value(toAccountId),
          notes: const Value('定投准备'),
        ),
      );

      final txByAccount =
          await db.transactionDao.getTransactionsByAccount(fromAccountId);
      expect(txByAccount, hasLength(1));
      final tx = txByAccount.first;
      expect(tx.type, TransactionType.transfer);
      expect(tx.amount, 3000);
      expect(tx.fromAccountId, fromAccountId);
      expect(tx.toAccountId, toAccountId);
    });
  });
}
