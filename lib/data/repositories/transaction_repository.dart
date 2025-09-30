import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums.dart';
import '../local/app_database.dart';
import 'account_repository.dart';

class TransactionRepository {
  TransactionRepository(this._dao, this._accountDao);

  final TransactionDao _dao;
  final AccountDao _accountDao;

  Future<List<Transaction>> getAllTransactions() => _dao.getAllTransactions();

  Stream<List<Transaction>> watchTransactions() => _dao.watchTransactions();

  Future<List<Transaction>> getTransactionsByAccount(String accountId) =>
      _dao.getTransactionsByAccount(accountId);

  Future<List<Transaction>> getTransactionsByHolding(String holdingId) =>
      _dao.getTransactionsByHolding(holdingId);

  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) =>
    _dao.watchTransactionsByAccount(accountId);

  Future<String> createTransaction({
    required double amount,
    required DateTime date,
    required TransactionType type,
    String? category,
    String? notes,
    String? fromAccountId,
    String? toAccountId,
    String? relatedHoldingId,
  }) async {
    try {
      final transactionId = const Uuid().v4();
      final transaction = TransactionsCompanion.insert(
        id: Value(transactionId),
        amount: amount,
        date: Value(date),
        type: type,
        category: category != null ? Value(category) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        fromAccountId: fromAccountId != null ? Value(fromAccountId) : const Value.absent(),
        toAccountId: toAccountId != null ? Value(toAccountId) : const Value.absent(),
        relatedHoldingId: relatedHoldingId != null ? Value(relatedHoldingId) : const Value.absent(),
      );

      // 使用事务来确保数据一致性
      return _dao.transaction(() async {
        // 创建交易记录
        await _dao.insertTransaction(transaction);
        
        // 更新账户余额
        await _updateAccountBalances(
          type: type,
          amount: amount,
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
        );
        
        return transactionId;
      });
    } catch (e, stackTrace) {
      print('[ERROR] 创建交易失败: $e');
      print('[ERROR] 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  Future<void> _updateAccountBalances({
    required TransactionType type,
    required double amount,
    required String? fromAccountId,
    required String? toAccountId,
    bool reverse = false,
  }) async {
    final multiplier = reverse ? -1.0 : 1.0;
    final incomingDelta = amount * multiplier;

    switch (type) {
      case TransactionType.income:
        if (toAccountId != null) {
          await _updateAccountBalance(toAccountId, incomingDelta);
        }
        break;
        
      case TransactionType.expense:
        if (fromAccountId != null) {
          await _updateAccountBalance(fromAccountId, -amount * multiplier);
        }
        break;
        
      case TransactionType.transfer:
        if (fromAccountId != null) {
          await _updateAccountBalance(fromAccountId, -amount * multiplier);
        }
        if (toAccountId != null) {
          await _updateAccountBalance(toAccountId, incomingDelta);
        }
        break;
        
      case TransactionType.buy:
        if (fromAccountId != null) {
          await _applyTradingOutflow(fromAccountId, amount, multiplier);
        }
        break;
      case TransactionType.sell:
        if (toAccountId != null) {
          await _applyTradingInflow(toAccountId, amount, multiplier);
        }
        break;
    }
  }

  Future<void> _updateAccountBalance(String accountId, double deltaAmount) async {
    final account = await _accountDao.getAccountById(accountId);
    if (account != null) {
      final updatedAccount = account.copyWith(
        balance: account.balance + deltaAmount,
      );
      await _accountDao.updateAccount(updatedAccount);
    }
  }

  Future<bool> updateTransaction(Transaction transaction) async {
    return _dao.transaction(() async {
      final existing = await _dao.getTransactionById(transaction.id);
      if (existing == null) {
        throw Exception('未找到对应的交易记录');
      }

      await _updateAccountBalances(
        type: existing.type,
        amount: existing.amount,
        fromAccountId: existing.fromAccountId,
        toAccountId: existing.toAccountId,
        reverse: true,
      );

      final success = await _dao.updateTransaction(transaction);
      if (!success) {
        throw Exception('交易更新失败');
      }

      await _updateAccountBalances(
        type: transaction.type,
        amount: transaction.amount,
        fromAccountId: transaction.fromAccountId,
        toAccountId: transaction.toAccountId,
      );

      return true;
    });
  }

  Future<int> deleteTransaction(String id) async {
    return _dao.transaction(() async {
      final existing = await _dao.getTransactionById(id);
      if (existing == null) {
        return 0;
      }

      await _updateAccountBalances(
        type: existing.type,
        amount: existing.amount,
        fromAccountId: existing.fromAccountId,
        toAccountId: existing.toAccountId,
        reverse: true,
      );

      return _dao.deleteTransaction(id);
    });
  }

  Future<void> _applyTradingOutflow(String accountId, double amount, double multiplier) async {
    final account = await _accountDao.getAccountById(accountId);
    if (account == null) {
      return;
    }
    final commission = _calculateCommission(amount, account);
    final delta = -(amount + commission) * multiplier;
    await _updateAccountBalanceDirect(account, delta);
  }

  Future<void> _applyTradingInflow(String accountId, double amount, double multiplier) async {
    final account = await _accountDao.getAccountById(accountId);
    if (account == null) {
      return;
    }
    final commission = _calculateCommission(amount, account);
    final stampTax = _calculateStampTax(amount, account);
    final netInflow = amount - commission - stampTax;
    await _updateAccountBalanceDirect(account, netInflow * multiplier);
  }

  Future<void> _updateAccountBalanceDirect(Account account, double delta) async {
    final updated = account.copyWith(balance: account.balance + delta);
    await _accountDao.updateAccount(updated);
  }

  double _calculateCommission(double amount, Account account) {
    if (amount <= 0 || account.type != AccountType.investment) {
      return 0;
    }
    final effectiveRate = math.max(account.commissionRate, AccountRepository.minCommissionRate);
    final fee = amount * effectiveRate;
    return math.max(fee, AccountRepository.minCommissionPerTrade);
  }

  double _calculateStampTax(double amount, Account account) {
    if (amount <= 0 || account.type != AccountType.investment) {
      return 0;
    }
    return amount * account.stampTaxRate;
  }
}