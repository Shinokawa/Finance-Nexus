import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';

class BudgetManagementView extends ConsumerWidget {
  const BudgetManagementView({super.key});

  Future<void> _showAddBudgetDialog(BuildContext context, WidgetRef ref) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => const _AddBudgetDialog(),
    );
  }

  Future<void> _showEditBudgetDialog(BuildContext context, WidgetRef ref, Budget budget) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => _EditBudgetDialog(budget: budget),
    );
  }

  Future<void> _deleteBudget(BuildContext context, WidgetRef ref, Budget budget) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除预算'),
        content: Text('确定要删除「${budget.type == BudgetType.total ? '总预算' : budget.category ?? ''}」吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repository = ref.read(budgetRepositoryProvider);
      await repository.deleteBudget(budget.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);

    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: background,
        border: null,
        middle: const Text('预算管理'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddBudgetDialog(context, ref),
          child: const Icon(CupertinoIcons.add, size: 28),
        ),
      ),
      child: SafeArea(
        child: budgetsAsync.when(
          data: (budgets) {
            final totalBudget = budgets.where((b) => b.type == BudgetType.total).firstOrNull;
            final categoryBudgets = budgets.where((b) => b.type == BudgetType.category).toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                if (totalBudget != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _BudgetCard(
                        budget: totalBudget,
                        onTap: () => _showEditBudgetDialog(context, ref, totalBudget),
                        onDelete: () => _deleteBudget(context, ref, totalBudget),
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _EmptyBudgetCard(
                        title: '未设置总预算',
                        onTap: () => _showAddBudgetDialog(context, ref),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '分类预算',
                      style: QHTypography.title3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.label,
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
                if (categoryBudgets.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _EmptyBudgetCard(
                        title: '未设置分类预算',
                        subtitle: '为不同支出类别设置预算上限',
                        onTap: () => _showAddBudgetDialog(context, ref),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final budget = categoryBudgets[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BudgetCard(
                              budget: budget,
                              onTap: () => _showEditBudgetDialog(context, ref, budget),
                              onDelete: () => _deleteBudget(context, ref, budget),
                            ),
                          );
                        },
                        childCount: categoryBudgets.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
          loading: () => const Center(
            child: CupertinoActivityIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text(
              '加载失败：$error',
              style: QHTypography.body.copyWith(
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.onTap,
    required this.onDelete,
  });

  final Budget budget;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.type == BudgetType.total ? '总预算' : budget.category ?? '未分类',
                        style: QHTypography.title3.copyWith(
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        budget.period.displayName,
                        style: QHTypography.footnote.copyWith(color: secondaryColor),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 32,
                  onPressed: onDelete,
                  child: Icon(
                    CupertinoIcons.delete,
                    size: 20,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatCurrency(budget.amount),
              style: QHTypography.largeTitle.copyWith(
                fontWeight: FontWeight.bold,
                color: CupertinoDynamicColor.resolve(QHColors.primary, context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000) {
      return '¥${(value / 10000).toStringAsFixed(2)}万';
    }
    return '¥${value.toStringAsFixed(2)}';
  }
}

class _EmptyBudgetCard extends StatelessWidget {
  const _EmptyBudgetCard({
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
          border: Border.all(
            color: secondaryColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.add_circled,
              size: 48,
              color: secondaryColor,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: QHTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: secondaryColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: QHTypography.footnote.copyWith(color: secondaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddBudgetDialog extends ConsumerStatefulWidget {
  const _AddBudgetDialog();

  @override
  ConsumerState<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends ConsumerState<_AddBudgetDialog> {
  BudgetType _selectedType = BudgetType.total;
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('输入错误'),
          content: const Text('请输入有效的预算金额'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      return;
    }

    if (_selectedType == BudgetType.category) {
      final category = _categoryController.text.trim();
      if (category.isEmpty) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('输入错误'),
            content: const Text('请输入预算类别'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('好的'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final repository = ref.read(budgetRepositoryProvider);
    await repository.createBudget(
      type: _selectedType,
      category: _selectedType == BudgetType.category ? _categoryController.text.trim() : null,
      amount: amount,
      period: _selectedPeriod,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              child: Text(
                '添加预算',
                style: QHTypography.title3.copyWith(
                  fontWeight: FontWeight.w600,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
                ),
              ),
            ),
            Container(
              height: 0.5,
              color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoSlidingSegmentedControl<BudgetType>(
                    groupValue: _selectedType,
                    children: const {
                      BudgetType.total: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('总预算'),
                      ),
                      BudgetType.category: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('分类预算'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_selectedType == BudgetType.category) ...[
                    CupertinoTextField(
                      controller: _categoryController,
                      placeholder: '类别名称（如：餐饮、交通）',
                      padding: const EdgeInsets.all(12),
                    ),
                    const SizedBox(height: 16),
                  ],
                  CupertinoTextField(
                    controller: _amountController,
                    placeholder: '预算金额',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 20),
                  CupertinoSlidingSegmentedControl<BudgetPeriod>(
                    groupValue: _selectedPeriod,
                    children: const {
                      BudgetPeriod.monthly: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('月度'),
                      ),
                      BudgetPeriod.yearly: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('年度'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPeriod = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            Container(
              height: 0.5,
              color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '取消',
                      style: QHTypography.body.copyWith(
                        color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 44,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
                ),
                Expanded(
                  child: CupertinoButton(
                    onPressed: _saveBudget,
                    child: Text(
                      '保存',
                      style: QHTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: CupertinoDynamicColor.resolve(QHColors.primary, context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditBudgetDialog extends ConsumerStatefulWidget {
  const _EditBudgetDialog({required this.budget});

  final Budget budget;

  @override
  ConsumerState<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends ConsumerState<_EditBudgetDialog> {
  late TextEditingController _amountController;
  late BudgetPeriod _selectedPeriod;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.budget.amount.toString());
    _selectedPeriod = widget.budget.period;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('输入错误'),
          content: const Text('请输入有效的预算金额'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
      );
      return;
    }

    final repository = ref.read(budgetRepositoryProvider);
    final updated = widget.budget.copyWith(
      amount: amount,
      period: _selectedPeriod,
    );
    await repository.updateBudget(updated);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              child: Text(
                '编辑预算',
                style: QHTypography.title3.copyWith(
                  fontWeight: FontWeight.w600,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
                ),
              ),
            ),
            Container(
              height: 0.5,
              color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoTextField(
                    controller: _amountController,
                    placeholder: '预算金额',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(height: 20),
                  CupertinoSlidingSegmentedControl<BudgetPeriod>(
                    groupValue: _selectedPeriod,
                    children: const {
                      BudgetPeriod.monthly: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('月度'),
                      ),
                      BudgetPeriod.yearly: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('年度'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPeriod = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            Container(
              height: 0.5,
              color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
            ),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      '取消',
                      style: QHTypography.body.copyWith(
                        color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 0.5,
                  height: 44,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
                ),
                Expanded(
                  child: CupertinoButton(
                    onPressed: _saveBudget,
                    child: Text(
                      '保存',
                      style: QHTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: CupertinoDynamicColor.resolve(QHColors.primary, context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Provider
final budgetsProvider = StreamProvider<List<Budget>>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  return repository.watchBudgets();
});
