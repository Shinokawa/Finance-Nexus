import 'package:drift/drift.dart' show Value;

import '../../core/enums.dart';
import '../local/app_database.dart';

class AccountRepository {
  AccountRepository(this._accountDao);

  final AccountDao _accountDao;

  static const double _defaultCommissionRate = 0.0003;
  static const double _defaultStampTaxRate = 0.001;

  Stream<List<Account>> watchAccounts() => _accountDao.watchAllAccounts();

  Future<List<Account>> getAccounts() => _accountDao.getAllAccounts();

  Future<Account?> getAccountById(String id) => _accountDao.getAccountById(id);

  Future<void> createAccount({
    required String name,
    required AccountType type,
    double balance = 0,
    double? commissionRate,
    double? stampTaxRate,
  }) async {
    await _accountDao.insertAccount(
      AccountsCompanion.insert(
        name: name,
        type: type,
        balance: Value(balance),
        commissionRate: Value(commissionRate ?? _defaultCommissionRate),
        stampTaxRate: Value(stampTaxRate ?? _defaultStampTaxRate),
      ),
    );
  }

  Future<void> updateAccount(
    Account account, {
    String? name,
    AccountType? type,
    double? balance,
    double? commissionRate,
    double? stampTaxRate,
  }) async {
    final updated = account.copyWith(
      name: name ?? account.name,
      type: type ?? account.type,
      balance: balance ?? account.balance,
      commissionRate: commissionRate ?? account.commissionRate,
      stampTaxRate: stampTaxRate ?? account.stampTaxRate,
    );
    await _accountDao.updateAccount(updated);
  }

  Future<void> deleteAccount(String id) => _accountDao.deleteAccountById(id);
}
