import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums.dart';
import '../local/app_database.dart';

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
        await _updateAccountBalances(type, amount, fromAccountId, toAccountId);
        
        return transactionId;
      });
    } catch (e, stackTrace) {
      print('[ERROR] 创建交易失败: $e');
      print('[ERROR] 堆栈跟踪: $stackTrace');
      rethrow;
    }
  }

  Future<void> _updateAccountBalances(
    TransactionType type,
    double amount,
    String? fromAccountId,
    String? toAccountId,
  ) async {
    switch (type) {
      case TransactionType.income:
        if (toAccountId != null) {
          await _updateAccountBalance(toAccountId, amount);
        }
        break;
        
      case TransactionType.expense:
        if (fromAccountId != null) {
          await _updateAccountBalance(fromAccountId, -amount);
        }
        break;
        
      case TransactionType.transfer:
        if (fromAccountId != null) {
          await _updateAccountBalance(fromAccountId, -amount);
        }
        if (toAccountId != null) {
          await _updateAccountBalance(toAccountId, amount);
        }
        break;
        
      case TransactionType.buy:
      case TransactionType.sell:
        // 买卖交易不在这里处理账户余额，由专门的交易方法处理
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

  Future<bool> updateTransaction(Transaction transaction) =>
      _dao.updateTransaction(transaction);

  Future<int> deleteTransaction(String id) => _dao.deleteTransaction(id);
}