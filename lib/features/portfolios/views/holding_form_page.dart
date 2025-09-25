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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    _purchaseDate = newDate;
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
        );
      } else {
        // 创建新持仓
        await ref.read(holdingRepositoryProvider).createHolding(
          symbol: symbol,
          quantity: quantity,
          averageCost: averageCost,
          accountId: _selectedAccountId!,
          portfolioId: _selectedPortfolioId!,
        );
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
}