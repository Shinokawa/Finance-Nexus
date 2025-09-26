import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../providers/repository_providers.dart';
import '../../accounts/providers/account_summary_providers.dart';
import 'category_selection_page.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    super.key, 
    this.transaction,
    this.initialType,
    this.preSelectedAccountId,
  });

  final Transaction? transaction;
  final TransactionType? initialType;
  final String? preSelectedAccountId;

  @override
  ConsumerState<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _notesController;
  late TransactionType _selectedType;
  late DateTime _selectedDate;
  String? _selectedFromAccountId;
  String? _selectedToAccountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _selectedType = widget.initialType ?? transaction?.type ?? TransactionType.expense;
    _selectedDate = transaction?.date ?? DateTime.now();
    _selectedFromAccountId = widget.preSelectedAccountId ?? transaction?.fromAccountId;
    _selectedToAccountId = transaction?.toAccountId;
    
    _amountController = TextEditingController(
      text: transaction?.amount.toStringAsFixed(2) ?? '',
    );
    _categoryController = TextEditingController(text: transaction?.category ?? '');
    _notesController = TextEditingController(text: transaction?.notes ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _needsFromAccount =>
      _selectedType == TransactionType.expense || 
      _selectedType == TransactionType.transfer ||
      _selectedType == TransactionType.buy;

  bool get _needsToAccount =>
      _selectedType == TransactionType.income || 
      _selectedType == TransactionType.transfer ||
      _selectedType == TransactionType.sell;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final category = _categoryController.text.trim();
    final notes = _notesController.text.trim();

    if (_needsFromAccount && _selectedFromAccountId == null) {
      _showError('请选择来源账户');
      return;
    }

    if (_needsToAccount && _selectedToAccountId == null) {
      _showError('请选择目标账户');
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final repository = ref.read(transactionRepositoryProvider);
      
      if (widget.transaction == null) {
        await repository.createTransaction(
          amount: amount,
          date: _selectedDate,
          type: _selectedType,
          category: category.isEmpty ? null : category,
          notes: notes.isEmpty ? null : notes,
          fromAccountId: _selectedFromAccountId,
          toAccountId: _selectedToAccountId,
        );
      } else {
        // 这里可以添加更新逻辑
        throw UnimplementedError('交易更新功能暂未实现');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stackTrace) {
      print('[ERROR] 表单提交失败: $error');
      print('[ERROR] 堆栈跟踪: $stackTrace');
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('操作失败'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;
    final accountsAsync = ref.watch(accountsStreamProvider);
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? '编辑交易' : '添加交易'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _handleSubmit,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: accountsAsync.when(
            data: (accounts) => _buildForm(accounts),
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, stack) => Center(
              child: Text(
                '加载账户失败: $error',
                style: const TextStyle(color: CupertinoColors.systemRed),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(List<Account> accounts) {
    final isEditing = widget.transaction != null;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        // 交易类型选择
        CupertinoFormSection.insetGrouped(
          header: const Text('交易类型'),
          children: [
            CupertinoFormRow(
              prefix: const Text('类型'),
              child: CupertinoSlidingSegmentedControl<TransactionType>(
                groupValue: _selectedType,
                children: {
                  for (final type in [
                    TransactionType.expense,
                    TransactionType.income,
                    TransactionType.transfer,
                  ])
                    type: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(type.displayName),
                    ),
                },
                onValueChanged: (value) {
                  if (_isSaving || value == null) return;
                  setState(() {
                    _selectedType = value;
                    // 清空账户选择
                    _selectedFromAccountId = null;
                    _selectedToAccountId = null;
                  });
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // 基础信息
        CupertinoFormSection.insetGrouped(
          header: const Text('基础信息'),
          children: [
            CupertinoTextFormFieldRow(
              controller: _amountController,
              prefix: const Text('金额'),
              placeholder: '¥0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入金额';
                }
                final number = double.tryParse(value.trim());
                if (number == null || number <= 0) {
                  return '请输入有效金额';
                }
                return null;
              },
            ),
            // 类别选择
            GestureDetector(
              onTap: _showCategorySelector,
              child: CupertinoFormRow(
                prefix: const Text('类别'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _categoryController.text.trim().isEmpty
                            ? _getCategoryPlaceholder()
                            : _categoryController.text.trim(),
                        style: TextStyle(
                          color: _categoryController.text.trim().isEmpty
                              ? CupertinoColors.placeholderText
                              : CupertinoColors.label,
                        ),
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.right_chevron,
                      color: CupertinoColors.systemGrey,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            // 日期选择
            GestureDetector(
              onTap: _showDatePicker,
              child: CupertinoFormRow(
                prefix: const Text('日期'),
                child: Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(color: CupertinoColors.label),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 账户选择
        if (_needsFromAccount || _needsToAccount)
          CupertinoFormSection.insetGrouped(
            header: const Text('账户选择'),
            children: [
              if (_needsFromAccount)
                _buildAccountSelector(
                  accounts: accounts,
                  label: _getFromAccountLabel(),
                  selectedAccountId: _selectedFromAccountId,
                  onChanged: (accountId) => setState(() => _selectedFromAccountId = accountId),
                ),
              if (_needsToAccount)
                _buildAccountSelector(
                  accounts: accounts,
                  label: _getToAccountLabel(),
                  selectedAccountId: _selectedToAccountId,
                  onChanged: (accountId) => setState(() => _selectedToAccountId = accountId),
                ),
            ],
          ),

        const SizedBox(height: 24),

        // 备注
        CupertinoFormSection.insetGrouped(
          header: const Text('详细信息'),
          children: [
            CupertinoTextFormFieldRow(
              controller: _notesController,
              prefix: const Text('备注'),
              placeholder: '记录这笔交易的详细信息（可选）',
              maxLines: 3,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 提交按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: CupertinoButton.filled(
            onPressed: _isSaving ? null : _handleSubmit,
            child: Text(isEditing ? '保存修改' : '添加交易'),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector({
    required List<Account> accounts,
    required String label,
    required String? selectedAccountId,
    required ValueChanged<String?> onChanged,
  }) {
    final selectedAccount = selectedAccountId != null
        ? accounts.firstWhere((a) => a.id == selectedAccountId, orElse: () => accounts.first)
        : null;

    return GestureDetector(
      onTap: () => _showAccountPicker(accounts, selectedAccountId, onChanged),
      child: CupertinoFormRow(
        prefix: Text(label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedAccount?.name ?? '请选择账户',
                style: TextStyle(
                  color: selectedAccount != null 
                      ? CupertinoColors.label 
                      : CupertinoColors.placeholderText,
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: CupertinoColors.systemGrey,
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker(
    List<Account> accounts, 
    String? currentSelection,
    ValueChanged<String?> onChanged,
  ) {
    showCupertinoModalPopup<String?>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择账户'),
        actions: accounts.map((account) =>
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop(account.id);
            },
            isDefaultAction: currentSelection == account.id,
            child: Row(
              children: [
                Expanded(child: Text(account.name)),
                Text(
                  account.type.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    ).then((accountId) {
      if (accountId != null) {
        onChanged(accountId);
      }
    });
  }

  void _showDatePicker() {
    DateTime tempDate = _selectedDate;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.0,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => _selectedDate = tempDate);
                      Navigator.of(context).pop();
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: tempDate,
                maximumDate: DateTime.now().add(const Duration(days: 1)), // 允许选择今天和明天
                minimumDate: DateTime.now().subtract(const Duration(days: 365 * 10)), // 最多10年前
                onDateTimeChanged: (date) {
                  tempDate = date;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategorySelector() async {
    final selectedCategory = await Navigator.of(context).push<String>(
      CupertinoPageRoute(
        builder: (context) => CategorySelectionPage(
          initialCategory: _categoryController.text.trim().isEmpty 
              ? null 
              : _categoryController.text.trim(),
        ),
      ),
    );
    
    if (selectedCategory != null) {
      setState(() {
        _categoryController.text = selectedCategory;
      });
    }
  }

  String _getCategoryPlaceholder() {
    switch (_selectedType) {
      case TransactionType.expense:
        return '如：餐饮、交通、娱乐';
      case TransactionType.income:
        return '如：工资、分红、利息';
      case TransactionType.transfer:
        return '如：资金调拨';
      default:
        return '分类';
    }
  }

  String _getFromAccountLabel() {
    switch (_selectedType) {
      case TransactionType.expense:
        return '支出账户';
      case TransactionType.transfer:
        return '转出账户';
      case TransactionType.buy:
        return '资金账户';
      default:
        return '来源账户';
    }
  }

  String _getToAccountLabel() {
    switch (_selectedType) {
      case TransactionType.income:
        return '收入账户';
      case TransactionType.transfer:
        return '转入账户';
      case TransactionType.sell:
        return '资金账户';
      default:
        return '目标账户';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return '今天';
    } else if (dateOnly == yesterday) {
      return '昨天';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}