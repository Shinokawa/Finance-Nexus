import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';

class AccountSummary {
  const AccountSummary({
    required this.account,
    required this.holdingsValue,
  });

  final Account account;
  final double holdingsValue;

  AccountType get type => account.type;

  bool get isInvestment => type == AccountType.investment;

  bool get isLiability => type == AccountType.liability;

  double get effectiveBalance {
    if (isInvestment) {
      return holdingsValue;
    }
    final base = account.balance;
    return isLiability ? -base.abs() : base;
  }

  double get displayBalance => isInvestment ? holdingsValue : account.balance;
}
