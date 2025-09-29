import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';

class HoldingFormPage extends ConsumerStatefulWidget {
  const HoldingFormPage({
    super.key,
    this.portfolioId,
    this.holding,
    this.preselectedAccountId,
  });

  final String? portfolioId;
  final Holding? holding;
  final String? preselectedAccountId;

  @override
  ConsumerState<HoldingFormPage> createState() => _HoldingFormPageState();
}

class _HoldingFormPageState extends ConsumerState<HoldingFormPage> {
  late final TextEditingController _symbolController;
  late final TextEditingController _quantityController;
  late final TextEditingController _averageCostController;
  late final TextEditingController _notesController;
  
  String? _selectedAccountId;
  String? _selectedPortfolioId;
  List<Account> _investmentAccounts = [];
  List<Portfolio> _portfolios = [];
  DateTime _purchaseDate = DateTime.now();
  Transaction? _primaryBuyTransaction;
  bool _isLoading = false;

  bool get _isEditing => widget.holding != null;

  @override
  void initState() {
    super.initState();
    
    _symbolController = TextEditingController(text: widget.holding?.symbol ?? '');
    _quantityController = TextEditingController(
      text: widget.holding?.quantity.toString() ?? '',
    );
    _averageCostController = TextEditingController(
      text: widget.holding?.averageCost.toString() ?? '',
    );
    _notesController = TextEditingController();
    
    if (widget.holding != null) {
      _selectedAccountId = widget.holding!.accountId;
      _selectedPortfolioId = widget.holding!.portfolioId;
      _loadPurchaseDate(); // 加载实际的购买日期
    } else {
      if (widget.preselectedAccountId != null) {
        _selectedAccountId = widget.preselectedAccountId;
      }
      if (widget.portfolioId != null) {
        _selectedPortfolioId = widget.portfolioId;
      }
    }
    
    _loadInvestmentAccounts();
    _loadPortfolios();
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _quantityController.dispose();
    _averageCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvestmentAccounts() async {
    try {
      final accounts = await ref.read(accountRepositoryProvider).getAccounts();
      setState(() {
        _investmentAccounts = accounts
            .where((account) => account.type == AccountType.investment)
            .toList();
        
        // 如果没有选中账户且有投资账户，选中第一个
        if (_selectedAccountId == null && _investmentAccounts.isNotEmpty) {
          _selectedAccountId = _investmentAccounts.first.id;
        }
      });
    } catch (e) {
      if (mounted) {
        _showErrorDialog('加载账户列表失败: $e');
      }
    }
  }

  Future<void> _loadPortfolios() async {
    try {
      final portfolios = await ref.read(portfolioRepositoryProvider).getPortfolios();
      setState(() {
        _portfolios = portfolios;
        
        // 如果没有选中投资组合且有投资组合，选中第一个
        if (_selectedPortfolioId == null && _portfolios.isNotEmpty) {
          _selectedPortfolioId = _portfolios.first.id;
        }
      });
    } catch (e) {
      if (mounted) {
        _showErrorDialog('加载投资组合列表失败: $e');
      }
    }
  }

  Future<void> _loadPurchaseDate() async {
    if (widget.holding == null) return;
    
    try {
      final transactions = await ref.read(transactionRepositoryProvider).getTransactionsByHolding(widget.holding!.id);
      if (transactions.isNotEmpty) {
        // 找到最早的买入交易日期
        final buyTransactions = transactions
            .where((t) => t.type == TransactionType.buy)
            .toList();
        if (buyTransactions.isNotEmpty) {
          buyTransactions.sort((a, b) => a.date.compareTo(b.date));
          setState(() {
            _primaryBuyTransaction = buyTransactions.first;
            _purchaseDate = _primaryBuyTransaction!.date;
          });
          debugPrint('[HoldingForm] Loaded primary buy transaction ${_primaryBuyTransaction!.id} for holding ${widget.holding!.id}');
        } else {
          debugPrint('[HoldingForm][WARN] Holding ${widget.holding!.id} has no buy transactions; purchase date editing will have no effect.');
        }
      } else {
        debugPrint('[HoldingForm][WARN] No transactions found for holding ${widget.holding!.id}.');
      }
    } catch (e) {
      // Handle error - keep default date
      debugPrint('[HoldingForm][ERROR] Failed to load purchase date for holding ${widget.holding!.id}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing ? '编辑持仓' : '添加持仓'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading 
              ? const CupertinoActivityIndicator()
              : const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFormSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          label: '股票代码',
          controller: _symbolController,
          placeholder: '如: sh600519, sz159819',
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 24),
        
        _buildInputField(
          label: '持仓数量',
          controller: _quantityController,
          placeholder: '股数',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 24),
        
        _buildInputField(
          label: '平均成本',
          controller: _averageCostController,
          placeholder: '每股成本价',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 24),
        
        _buildPortfolioSelector(),
        const SizedBox(height: 24),
        
        _buildAccountSelector(),
        const SizedBox(height: 24),
        
        _buildDateSelector(),
        const SizedBox(height: 24),
        
        _buildInputField(
          label: '备注 (可选)',
          controller: _notesController,
          placeholder: '持仓备注',
          keyboardType: TextInputType.text,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    TextInputType? keyboardType,
  }) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.subheadline.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(CupertinoColors.tertiarySystemBackground, context),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioSelector() {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final selectedPortfolio = _portfolios
        .where((portfolio) => portfolio.id == _selectedPortfolioId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '投资组合',
          style: QHTypography.subheadline.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        GestureDetector(
          onTap: _portfolios.isNotEmpty ? _showPortfolioPicker : _showCreatePortfolioDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(CupertinoColors.tertiarySystemBackground, context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _portfolios.isEmpty 
                        ? '暂无投资组合，点击创建'
                        : selectedPortfolio?.name ?? '请选择投资组合',
                    style: QHTypography.body.copyWith(
                      color: selectedPortfolio != null 
                          ? labelColor 
                          : CupertinoColors.placeholderText,
                    ),
                  ),
                ),
                Icon(
                  _portfolios.isEmpty 
                      ? CupertinoIcons.add_circled
                      : CupertinoIcons.chevron_right,
                  size: 20,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final selectedAccount = _investmentAccounts
        .where((account) => account.id == _selectedAccountId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所属账户',
          style: QHTypography.subheadline.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        GestureDetector(
          onTap: _investmentAccounts.isNotEmpty ? _showAccountPicker : _showCreateAccountDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(CupertinoColors.tertiarySystemBackground, context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _investmentAccounts.isEmpty 
                        ? '暂无投资账户，点击创建'
                        : selectedAccount?.name ?? '请选择账户',
                    style: QHTypography.body.copyWith(
                      color: selectedAccount != null 
                          ? labelColor 
                          : CupertinoColors.placeholderText,
                    ),
                  ),
                ),
                Icon(
                  _investmentAccounts.isEmpty 
                      ? CupertinoIcons.add_circled
                      : CupertinoIcons.chevron_right,
                  size: 20,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '买入日期',
          style: QHTypography.subheadline.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        GestureDetector(
          onTap: _showDatePicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(CupertinoColors.tertiarySystemBackground, context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_purchaseDate.year}-${_purchaseDate.month.toString().padLeft(2, '0')}-${_purchaseDate.day.toString().padLeft(2, '0')}',
                    style: QHTypography.body.copyWith(color: labelColor),
                  ),
                ),
                Icon(
                  CupertinoIcons.calendar,
                  size: 20,
                  color: CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDatePicker() {
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _purchaseDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    final original = _primaryBuyTransaction?.date;
                    if (original != null) {
                      _purchaseDate = DateTime(
                        newDate.year,
                        newDate.month,
                        newDate.day,
                        original.hour,
                        original.minute,
                        original.second,
                        original.millisecond,
                        original.microsecond,
                      );
                    } else {
                      _purchaseDate = newDate;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker() {
    if (_investmentAccounts.isEmpty) {
      _showCreateAccountDialog();
      return;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 顶部操作栏
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              
              // 选择器
              Expanded(
                child: _investmentAccounts.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无投资账户',
                          style: QHTypography.body,
                        ),
                      )
                    : CupertinoPicker(
                        magnification: 1.22,
                        squeeze: 1.2,
                        useMagnifier: true,
                        itemExtent: 44.0,
                        scrollController: FixedExtentScrollController(
                          initialItem: _selectedAccountId != null
                              ? math.max(0, _investmentAccounts.indexWhere((account) => account.id == _selectedAccountId))
                              : 0,
                        ),
                        onSelectedItemChanged: (int selectedItem) {
                          if (selectedItem >= 0 && selectedItem < _investmentAccounts.length) {
                            setState(() {
                              _selectedAccountId = _investmentAccounts[selectedItem].id;
                            });
                          }
                        },
                        children: _investmentAccounts.map((Account account) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                account.name.isNotEmpty ? account.name : '未命名账户',
                                style: QHTypography.body.copyWith(
                                  color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_isLoading) return;

    // 验证输入
    final symbol = _symbolController.text.trim();
    final quantityText = _quantityController.text.trim();
    final averageCostText = _averageCostController.text.trim();

    if (symbol.isEmpty) {
      _showErrorDialog('请输入股票代码');
      return;
    }

    if (quantityText.isEmpty) {
      _showErrorDialog('请输入持仓数量');
      return;
    }

    if (averageCostText.isEmpty) {
      _showErrorDialog('请输入平均成本');
      return;
    }

    if (_selectedAccountId == null) {
      _showErrorDialog('请选择所属账户');
      return;
    }

    if (_selectedPortfolioId == null) {
      _showErrorDialog('请选择投资组合');
      return;
    }

    final quantity = double.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      _showErrorDialog('请输入有效的持仓数量');
      return;
    }

    final averageCost = double.tryParse(averageCostText);
    if (averageCost == null || averageCost <= 0) {
      _showErrorDialog('请输入有效的平均成本');
      return;
    }

    final notes = _notesController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditing) {
        // 更新现有持仓
        await ref.read(holdingRepositoryProvider).updateHolding(
          widget.holding!,
          quantity: quantity,
          averageCost: averageCost,
          accountId: _selectedAccountId!,
          purchaseDate: _purchaseDate,
        );
        await _updatePurchaseDateIfNeeded();
      } else {
        // 创建新持仓
        final holdingRepository = ref.read(holdingRepositoryProvider);
        final createdHolding = await holdingRepository.createHolding(
          symbol: symbol,
          quantity: quantity,
          averageCost: averageCost,
          accountId: _selectedAccountId!,
          portfolioId: _selectedPortfolioId!,
          purchaseDate: _purchaseDate,
        );

        try {
          final createdTransaction = await _createPrimaryBuyTransaction(
            holding: createdHolding,
            quantity: quantity,
            price: averageCost,
            date: _purchaseDate,
            notes: notes.isEmpty ? null : notes,
            category: '股票买入',
          );
          debugPrint('[HoldingForm] Created initial buy transaction ${createdTransaction.id} for holding ${createdHolding.id}.');
          if (mounted) {
            setState(() {
              _primaryBuyTransaction = createdTransaction;
            });
          }
        } catch (e, stackTrace) {
          debugPrint('[HoldingForm][ERROR] Failed to create initial buy transaction for holding ${createdHolding.id}: $e\n$stackTrace');
          rethrow;
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showPortfolioPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // 顶部操作栏
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              
              // 选择器
              Expanded(
                child: CupertinoPicker(
                  magnification: 1.22,
                  squeeze: 1.2,
                  useMagnifier: true,
                  itemExtent: 44.0,
                  scrollController: FixedExtentScrollController(
                    initialItem: _selectedPortfolioId != null
                        ? _portfolios.indexWhere((portfolio) => portfolio.id == _selectedPortfolioId)
                        : 0,
                  ),
                  onSelectedItemChanged: (int selectedItem) {
                    setState(() {
                      _selectedPortfolioId = _portfolios[selectedItem].id;
                    });
                  },
                  children: _portfolios.map((Portfolio portfolio) {
                    return Center(
                      child: Text(
                        portfolio.name,
                        style: QHTypography.body.copyWith(
                          color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreatePortfolioDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('暂无投资组合'),
        content: const Text('需要先创建一个投资组合才能添加持仓'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              // 跳转到账户页面
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('去创建'),
          ),
        ],
      ),
    );
  }

  void _showCreateAccountDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('暂无投资账户'),
        content: const Text('需要先创建一个投资账户才能添加持仓'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              // 跳转到账户页面
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('去创建'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('错误'),
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

  Future<void> _updatePurchaseDateIfNeeded() async {
    final holding = widget.holding;
    if (holding == null) {
      debugPrint('[HoldingForm][WARN] Tried to update purchase date without an active holding.');
      return;
    }

    var buyTransaction = _primaryBuyTransaction;
    if (buyTransaction == null) {
      debugPrint('[HoldingForm][INFO] No existing buy transaction. Creating one for holding ${holding.id}.');
      try {
        final created = await _createPrimaryBuyTransaction(
          holding: holding,
          quantity: holding.quantity,
          price: holding.averageCost,
          date: _purchaseDate,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          category: '初始建仓补记',
        );
        if (mounted) {
          setState(() {
            _primaryBuyTransaction = created;
            _purchaseDate = created.date;
          });
        }
        debugPrint('[HoldingForm] Created primary buy transaction ${created.id} for holding ${holding.id}.');
        return;
      } catch (e, stackTrace) {
        debugPrint('[HoldingForm][ERROR] Failed to create primary buy transaction for holding ${holding.id}: $e\n$stackTrace');
        rethrow;
      }
    }

    if (_isSameCalendarDate(_purchaseDate, buyTransaction.date)) {
      debugPrint('[HoldingForm] Purchase date unchanged for transaction ${buyTransaction.id}.');
      return;
    }

    final updatedTransaction = buyTransaction.copyWith(date: _purchaseDate);

    try {
      final success = await ref.read(transactionRepositoryProvider).updateTransaction(updatedTransaction);
      if (!success) {
        throw Exception('交易记录更新失败');
      }
      debugPrint('[HoldingForm] Updated primary buy transaction ${buyTransaction.id} date to $_purchaseDate.');
      if (mounted) {
        setState(() {
          _primaryBuyTransaction = updatedTransaction;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[HoldingForm][ERROR] Failed to update primary buy transaction ${buyTransaction.id}: $e\n$stackTrace');
      rethrow;
    }
  }

  Future<Transaction> _createPrimaryBuyTransaction({
    required Holding holding,
    required double quantity,
    required double price,
    required DateTime date,
    String? notes,
    required String category,
  }) async {
    final transactionRepository = ref.read(transactionRepositoryProvider);
    final sanitizedNotes = (notes ?? '').trim();
    final amount = quantity * price;

    final transactionId = await transactionRepository.createTransaction(
      amount: amount,
      date: date,
      type: TransactionType.buy,
      category: category,
      notes: sanitizedNotes.isEmpty ? null : sanitizedNotes,
      fromAccountId: holding.accountId,
      relatedHoldingId: holding.id,
    );

    final transactions = await transactionRepository.getTransactionsByHolding(holding.id);
    Transaction? created;
    for (final transaction in transactions) {
      if (transaction.id == transactionId) {
        created = transaction;
        break;
      }
    }

    created ??= _findEarliestBuyTransaction(transactions);

    if (created == null) {
      throw Exception('无法加载创建的买入交易记录');
    }

    return created;
  }

  Transaction? _findEarliestBuyTransaction(List<Transaction> transactions) {
    Transaction? earliest;
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.buy) {
        if (earliest == null || transaction.date.isBefore(earliest.date)) {
          earliest = transaction;
        }
      }
    }
    return earliest;
  }

  bool _isSameCalendarDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}