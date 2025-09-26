import 'package:flutter_test/flutter_test.dart';
import 'package:finanexus/core/enums.dart';

void main() {
  group('TransactionRepository Integration Tests', () {
    test('should handle transaction types correctly', () {
      // 测试交易类型枚举
      expect(TransactionType.income.name, 'income');
      expect(TransactionType.expense.name, 'expense');
      expect(TransactionType.transfer.name, 'transfer');
      expect(TransactionType.buy.name, 'buy');
      expect(TransactionType.sell.name, 'sell');
    });

    test('should handle account types correctly', () {
      // 测试账户类型枚举
      expect(AccountType.investment.displayName, '投资账户');
      expect(AccountType.cash.displayName, '现金账户');
      expect(AccountType.liability.displayName, '负债账户');
    });

    test('should handle account currency correctly', () {
      // 测试账户货币枚举
      expect(AccountCurrency.cny.name, 'cny');
    });
  });
}