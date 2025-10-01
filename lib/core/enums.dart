enum AccountType { investment, cash, liability }

enum AccountCurrency { cny }

enum TransactionType { expense, income, transfer, buy, sell }

enum BudgetPeriod { monthly, yearly }

enum BudgetType { total, category }

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

extension BudgetPeriodLabel on BudgetPeriod {
	String get displayName {
		switch (this) {
			case BudgetPeriod.monthly:
				return '月度';
			case BudgetPeriod.yearly:
				return '年度';
		}
	}
}

extension BudgetTypeLabel on BudgetType {
	String get displayName {
		switch (this) {
			case BudgetType.total:
				return '总预算';
			case BudgetType.category:
				return '分类预算';
		}
	}
}
