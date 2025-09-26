import 'package:flutter_test/flutter_test.dart';
import 'package:finanexus/core/enums.dart';
import 'package:finanexus/data/local/app_database.dart';
import 'package:finanexus/features/accounts/models/account_summary.dart';

void main() {
  group('AccountSummary', () {
    test('should calculate effective balance correctly for investment account', () {
      final account = Account(
        id: 'test-id',
        name: '测试投资账户',
        type: AccountType.investment,
        currency: AccountCurrency.cny,
        balance: 50000.0,
        createdAt: DateTime.now(),
      );
      
      final summary = AccountSummary(
        account: account,
        holdingsValue: 80000.0,
      );
      
      expect(summary.isInvestment, true);
      expect(summary.effectiveBalance, 80000.0); // 应该返回持仓价值
      expect(summary.displayBalance, 80000.0);
    });
    
    test('should calculate effective balance correctly for cash account', () {
      final account = Account(
        id: 'test-id',
        name: '测试现金账户',
        type: AccountType.cash,
        currency: AccountCurrency.cny,
        balance: 30000.0,
        createdAt: DateTime.now(),
      );
      
      final summary = AccountSummary(
        account: account,
        holdingsValue: 0.0,
      );
      
      expect(summary.isInvestment, false);
      expect(summary.isLiability, false);
      expect(summary.effectiveBalance, 30000.0); // 应该返回账户余额
      expect(summary.displayBalance, 30000.0);
    });
    
    test('should calculate effective balance correctly for liability account', () {
      final account = Account(
        id: 'test-id',
        name: '测试负债账户',
        type: AccountType.liability,
        currency: AccountCurrency.cny,
        balance: 15000.0, // 正数表示欠款
        createdAt: DateTime.now(),
      );
      
      final summary = AccountSummary(
        account: account,
        holdingsValue: 0.0,
      );
      
      expect(summary.isLiability, true);
      expect(summary.effectiveBalance, -15000.0); // 负债应该显示为负数
      expect(summary.displayBalance, 15000.0);
    });
  });
}