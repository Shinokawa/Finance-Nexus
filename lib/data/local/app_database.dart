import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums.dart';
import 'type_converters.dart';

part 'app_database.g.dart';

@DataClassName('Account')
class Accounts extends Table {
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  TextColumn get name => text()();

  TextColumn get type =>
      text().map(const EnumNameTypeConverter(AccountType.values))();

  TextColumn get currency => text()
      .withDefault(const Constant('cny'))
      .map(const EnumNameTypeConverter(AccountCurrency.values))();

  RealColumn get balance => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

@DataClassName('Portfolio')
class Portfolios extends Table {
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}

@DataClassName('Holding')
class Holdings extends Table {
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  TextColumn get symbol => text()();

  RealColumn get quantity => real().withDefault(const Constant(0.0))();

  RealColumn get averageCost => real().withDefault(const Constant(0.0))();

  TextColumn get accountId => text().references(Accounts, #id)();

  TextColumn get portfolioId => text().references(Portfolios, #id)();
}

@DataClassName('Transaction')
class Transactions extends Table {
  @override
  Set<Column> get primaryKey => {id};

  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  RealColumn get amount => real()();

  DateTimeColumn get date =>
      dateTime().clientDefault(() => DateTime.now())();

  TextColumn get type =>
      text().map(const EnumNameTypeConverter(TransactionType.values))();

  TextColumn get category => text().nullable()();

  TextColumn get notes => text().nullable()();

  @ReferenceName('outgoingTransactions')
  TextColumn get fromAccountId =>
    text().nullable().references(Accounts, #id)();

  @ReferenceName('incomingTransactions')
  TextColumn get toAccountId =>
    text().nullable().references(Accounts, #id)();

  TextColumn get relatedHoldingId =>
      text().nullable().references(Holdings, #id)();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbDirectory = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbDirectory.path, 'quant_hub.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [Accounts, Portfolios, Holdings, Transactions],
  daos: [AccountDao, PortfolioDao, HoldingDao, TransactionDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : this._internal(_openConnection());

  AppDatabase._internal(super.executor);

  factory AppDatabase.inMemory() {
    return AppDatabase._internal(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;
}

@DriftAccessor(tables: [Accounts])
class AccountDao extends DatabaseAccessor<AppDatabase>
    with _$AccountDaoMixin {
  AccountDao(super.db);

  Future<List<Account>> getAllAccounts() => select(accounts).get();

  Stream<List<Account>> watchAllAccounts() => select(accounts).watch();

  Future<Account?> getAccountById(String id) {
    return (select(accounts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertAccount(AccountsCompanion account) =>
      into(accounts).insert(account, mode: InsertMode.insertOrReplace);

  Future<bool> updateAccount(Account account) => update(accounts).replace(account);

  Future<int> deleteAccountById(String id) {
    return (delete(accounts)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> deleteAllAccounts() => delete(accounts).go();
}

@DriftAccessor(tables: [Portfolios])
class PortfolioDao extends DatabaseAccessor<AppDatabase>
    with _$PortfolioDaoMixin {
  PortfolioDao(super.db);

  Future<List<Portfolio>> getAllPortfolios() => select(portfolios).get();

  Stream<List<Portfolio>> watchAllPortfolios() => select(portfolios).watch();

  Future<Portfolio?> getPortfolioById(String id) {
    return (select(portfolios)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertPortfolio(PortfoliosCompanion portfolio) =>
      into(portfolios).insert(portfolio, mode: InsertMode.insertOrReplace);

  Future<bool> updatePortfolio(Portfolio portfolio) =>
      update(portfolios).replace(portfolio);

  Future<int> deletePortfolioById(String id) {
    return (delete(portfolios)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> deleteAllPortfolios() => delete(portfolios).go();
}

@DriftAccessor(tables: [Holdings])
class HoldingDao extends DatabaseAccessor<AppDatabase>
    with _$HoldingDaoMixin {
  HoldingDao(super.db);

  Future<List<Holding>> getAllHoldings() => select(holdings).get();

  Stream<List<Holding>> watchAllHoldings() => select(holdings).watch();

  Future<List<Holding>> getHoldingsByPortfolio(String portfolioId) {
    return (select(holdings)..where((tbl) => tbl.portfolioId.equals(portfolioId)))
        .get();
  }

  Future<List<Holding>> getHoldingsByAccount(String accountId) {
    return (select(holdings)..where((tbl) => tbl.accountId.equals(accountId)))
        .get();
  }

  Stream<List<Holding>> watchHoldingsByPortfolio(String portfolioId) {
    return (select(holdings)..where((tbl) => tbl.portfolioId.equals(portfolioId)))
        .watch();
  }

  Stream<List<Holding>> watchHoldingsByAccount(String accountId) {
    return (select(holdings)..where((tbl) => tbl.accountId.equals(accountId)))
        .watch();
  }

  Future<int> insertHolding(HoldingsCompanion holding) =>
      into(holdings).insert(holding, mode: InsertMode.insertOrReplace);

  Future<bool> updateHolding(Holding holding) =>
      update(holdings).replace(holding);

  Future<int> deleteHolding(String id) {
    return (delete(holdings)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future<int> deleteAllHoldings() => delete(holdings).go();
}

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<List<Transaction>> getAllTransactions() => select(transactions).get();

  Stream<List<Transaction>> watchTransactions() => select(transactions).watch();

  Future<List<Transaction>> getTransactionsByAccount(String accountId) {
    return (select(transactions)
          ..where((tbl) => tbl.fromAccountId.equals(accountId) | tbl.toAccountId.equals(accountId)))
        .get();
  }

  Future<List<Transaction>> getTransactionsByHolding(String holdingId) {
    return (select(transactions)
          ..where((tbl) => tbl.relatedHoldingId.equals(holdingId)))
        .get();
  }

  Future<int> insertTransaction(TransactionsCompanion transaction) =>
      into(transactions).insert(transaction, mode: InsertMode.insertOrReplace);

  Future<bool> updateTransaction(Transaction transaction) =>
      update(transactions).replace(transaction);

  Future<int> deleteTransaction(String id) {
    return (delete(transactions)..where((tbl) => tbl.id.equals(id))).go();
  }
}
