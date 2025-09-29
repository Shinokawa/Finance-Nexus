import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';
import '../../accounts/providers/account_summary_providers.dart';
import '../providers/transaction_providers.dart';
import 'transaction_form_page.dart';

class LedgerTabView extends ConsumerWidget {
  const LedgerTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('流水'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _navigateToTransactionForm(context, ref),
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyStateView(),
                );
              }

              // 按日期分组
              final groupedTransactions = _groupTransactionsByDate(transactions);

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = groupedTransactions.keys.elementAt(index);
                    final dayTransactions = groupedTransactions[date]!;

                    return _TransactionDateSection(
                      date: date,
                      transactions: dayTransactions,
                    );
                  },
                  childCount: groupedTransactions.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (error, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorView(message: error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTransactionForm(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => const TransactionFormPage(),
      ),
    );
    if (result == true) {
      ref.invalidate(transactionsStreamProvider);
    }
  }

  Map<DateTime, List<Transaction>> _groupTransactionsByDate(List<Transaction> transactions) {
    final Map<DateTime, List<Transaction>> grouped = {};
    
    for (final transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      
      if (grouped[date] == null) {
        grouped[date] = [];
      }
      grouped[date]!.add(transaction);
    }
    
    // 按日期降序排序
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    final sortedGrouped = <DateTime, List<Transaction>>{};
    for (final key in sortedKeys) {
      // 每日内的交易按时间降序排序
      grouped[key]!.sort((a, b) => b.date.compareTo(a.date));
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }
}

class _TransactionDateSection extends ConsumerWidget {
  const _TransactionDateSection({
    required this.date,
    required this.transactions,
  });

  final DateTime date;
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    // 计算当日收支汇总
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final transaction in transactions) {
      switch (transaction.type) {
        case TransactionType.income:
          totalIncome += transaction.amount;
          break;
        case TransactionType.expense:
          totalExpense += transaction.amount;
          break;
        default:
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期标题和汇总
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                _formatDateHeader(date),
                style: QHTypography.subheadline.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (totalIncome > 0 || totalExpense > 0) ...[
                if (totalIncome > 0)
                  Text(
                    '+¥${totalIncome.toStringAsFixed(2)}',
                    style: QHTypography.footnote.copyWith(
                      color: QHColors.profit,
                    ),
                  ),
                if (totalIncome > 0 && totalExpense > 0)
                  Text(
                    '  ',
                    style: QHTypography.footnote.copyWith(
                      color: secondaryColor,
                    ),
                  ),
                if (totalExpense > 0)
                  Text(
                    '-¥${totalExpense.toStringAsFixed(2)}',
                    style: QHTypography.footnote.copyWith(
                      color: QHColors.loss,
                    ),
                  ),
              ],
            ],
          ),
        ),
        
        // 交易列表
        Column(
          children: transactions
              .map((transaction) => _TransactionCard(transaction: transaction))
              .toList(),
        ),
        
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date == today) {
      return '今天';
    } else if (date == yesterday) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return GestureDetector(
      onTap: () => _showTransactionOptions(context, ref),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 交易类型图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getTypeColor().withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(),
                    size: 20,
                    color: _getTypeColor(),
                  ),
                ),
                const SizedBox(width: 12),
                
                // 主要信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.category?.isNotEmpty == true
                            ? transaction.category! 
                            : transaction.type.displayName,
                        style: QHTypography.subheadline.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTransactionDetails(accountsAsync.valueOrNull ?? []),
                        style: QHTypography.footnote.copyWith(
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 金额和时间
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmount(),
                      style: QHTypography.subheadline.copyWith(
                        color: _getAmountColor(),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(),
                      style: QHTypography.footnote.copyWith(
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // 备注（如果有）
            if (transaction.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                transaction.notes!,
                style: QHTypography.footnote.copyWith(
                  color: secondaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTransactionOptions(BuildContext context, WidgetRef ref) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(transaction.category?.isNotEmpty == true
            ? transaction.category! 
            : transaction.type.displayName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteConfirmation(context, ref);
            },
            isDestructiveAction: true,
            child: const Text('删除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除流水'),
        content: const Text('确定要删除这条流水记录吗？\n此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(transactionRepositoryProvider).deleteTransaction(transaction.id);
                ref.invalidate(transactionsStreamProvider);
              } catch (e) {
                if (context.mounted) {
                  showCupertinoDialog<void>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('删除失败'),
                      content: Text(e.toString()),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('好的'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (transaction.type) {
      case TransactionType.income:
        return CupertinoIcons.arrow_down_circle;
      case TransactionType.expense:
        return CupertinoIcons.arrow_up_circle;
      case TransactionType.transfer:
        return CupertinoIcons.arrow_right_arrow_left_circle;
      case TransactionType.buy:
        return CupertinoIcons.cart;
      case TransactionType.sell:
        return CupertinoIcons.money_dollar_circle;
    }
  }

  Color _getTypeColor() {
    switch (transaction.type) {
      case TransactionType.income:
        return QHColors.profit;
      case TransactionType.expense:
        return QHColors.loss;
      case TransactionType.transfer:
        return CupertinoColors.systemBlue;
      case TransactionType.buy:
        return CupertinoColors.systemOrange;
      case TransactionType.sell:
        return CupertinoColors.systemGreen;
    }
  }

  Color _getAmountColor() {
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.sell:
        return QHColors.profit;
      case TransactionType.expense:
      case TransactionType.buy:
        return QHColors.loss;
      case TransactionType.transfer:
        return CupertinoColors.label;
    }
  }

  String _formatAmount() {
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.sell:
        return '+¥${transaction.amount.toStringAsFixed(2)}';
      case TransactionType.expense:
      case TransactionType.buy:
        return '-¥${transaction.amount.toStringAsFixed(2)}';
      case TransactionType.transfer:
        return '¥${transaction.amount.toStringAsFixed(2)}';
    }
  }

  String _formatTime() {
    return '${transaction.date.hour.toString().padLeft(2, '0')}:${transaction.date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTransactionDetails(List<Account> accounts) {
    final fromAccount = transaction.fromAccountId != null
        ? accounts.firstWhere((a) => a.id == transaction.fromAccountId, 
            orElse: () => Account(
              id: '', 
              name: '未知账户', 
              type: AccountType.cash, 
              currency: AccountCurrency.cny, 
              balance: 0,
              commissionRate: 0,
              stampTaxRate: 0,
              createdAt: DateTime.now(),
            ))
        : null;
    
    final toAccount = transaction.toAccountId != null
        ? accounts.firstWhere((a) => a.id == transaction.toAccountId,
            orElse: () => Account(
              id: '', 
              name: '未知账户', 
              type: AccountType.cash, 
              currency: AccountCurrency.cny, 
              balance: 0,
              commissionRate: 0,
              stampTaxRate: 0,
              createdAt: DateTime.now(),
            ))
        : null;

    switch (transaction.type) {
      case TransactionType.expense:
        return fromAccount?.name ?? '支出';
      case TransactionType.income:
        return toAccount?.name ?? '收入';
      case TransactionType.transfer:
        return '${fromAccount?.name ?? '?'} → ${toAccount?.name ?? '?'}';
      case TransactionType.buy:
      case TransactionType.sell:
        return fromAccount?.name ?? toAccount?.name ?? transaction.type.displayName;
    }
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.book,
              size: 64,
              color: secondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无流水记录',
              style: QHTypography.title3.copyWith(
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 号开始记录第一笔流水',
              textAlign: TextAlign.center,
              style: QHTypography.subheadline.copyWith(
                color: secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: QHTypography.title3.copyWith(
                color: CupertinoColors.systemRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QHTypography.subheadline.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
