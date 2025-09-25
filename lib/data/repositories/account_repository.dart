import 'package:drift/drift.dart' show Value;

import '../../core/enums.dart';
import '../local/app_database.dart';

class AccountRepository {
  AccountRepository(this._accountDao);

  final AccountDao _accountDao;

  Stream<List<Account>> watchAccounts() => _accountDao.watchAllAccounts();

  Future<List<Account>> getAccounts() => _accountDao.getAllAccounts();

  Future<Account?> getAccountById(String id) => _accountDao.getAccountById(id);

  Future<void> createAccount({
    required String name,
    required AccountType type,
    double balance = 0,
  }) async {
    await _accountDao.insertAccount(
      AccountsCompanion.insert(
        name: name,
        type: type,
        balance: Value(balance),
      ),
    );
  }

  Future<void> updateAccount(
    Account account, {
    String? name,
    AccountType? type,
    double? balance,
  }) async {
    final updated = account.copyWith(
      name: name ?? account.name,
      type: type ?? account.type,
      balance: balance ?? account.balance,
    );
    await _accountDao.updateAccount(updated);
  }

  Future<void> deleteAccount(String id) => _accountDao.deleteAccountById(id);
}
