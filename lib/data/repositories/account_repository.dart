import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;

import '../../core/enums.dart';
import '../local/app_database.dart';

class AccountRepository {
  AccountRepository(this._accountDao);

  final AccountDao _accountDao;

  static const double _defaultCommissionRate = 0.0003;
  static const double _defaultStampTaxRate = 0.001;
  static const double _minCommissionRate = 0.0001;
  static const double minCommissionPerTrade = 5.0;

  static double get minCommissionRate => _minCommissionRate;
  static double get defaultCommissionRate => _defaultCommissionRate;
  static double get defaultStampTaxRate => _defaultStampTaxRate;

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
    final normalizedCommissionRate = _normalizeCommissionRate(commissionRate);
    final normalizedStampTaxRate = _normalizeStampTaxRate(stampTaxRate);
    await _accountDao.insertAccount(
      AccountsCompanion.insert(
        name: name,
        type: type,
        balance: Value(balance),
        commissionRate: Value(normalizedCommissionRate),
        stampTaxRate: Value(normalizedStampTaxRate),
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
      commissionRate: commissionRate != null
          ? _normalizeCommissionRate(commissionRate)
          : account.commissionRate,
      stampTaxRate: stampTaxRate != null
          ? _normalizeStampTaxRate(stampTaxRate)
          : account.stampTaxRate,
    );
    await _accountDao.updateAccount(updated);
  }

  Future<void> deleteAccount(String id) => _accountDao.deleteAccountById(id);

  static double _normalizeCommissionRate(double? rate) {
    final value = rate ?? _defaultCommissionRate;
    if (value.isNaN || value.isInfinite) {
      return _defaultCommissionRate;
    }
    return math.max(value, _minCommissionRate);
  }

  static double _normalizeStampTaxRate(double? rate) {
    final value = rate ?? _defaultStampTaxRate;
    if (value.isNaN || value.isInfinite) {
      return _defaultStampTaxRate;
    }
    return math.max(value, 0);
  }
}
