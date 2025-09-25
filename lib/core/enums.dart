enum AccountType { investment, cash, liability }

enum AccountCurrency { cny }

enum TransactionType { expense, income, transfer, buy, sell }

extension AccountTypeLabel on AccountType {
	String get displayName {
		switch (this) {
			case AccountType.investment:
				return '投资账户';
			case AccountType.cash:
				return '现金账户';
			case AccountType.liability:
				return '负债账户';
		}
	}
}

extension TransactionTypeLabel on TransactionType {
	String get displayName {
		switch (this) {
			case TransactionType.expense:
				return '支出';
			case TransactionType.income:
				return '收入';
			case TransactionType.transfer:
				return '转账';
			case TransactionType.buy:
				return '买入';
			case TransactionType.sell:
				return '卖出';
		}
	}
}
