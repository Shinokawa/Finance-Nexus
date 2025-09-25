import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';

class TradeFormPage extends ConsumerStatefulWidget {
  const TradeFormPage({
    super.key,
    required this.holding,
  });

  final Holding holding;

  @override
  ConsumerState<TradeFormPage> createState() => _TradeFormPageState();
}

class _TradeFormPageState extends ConsumerState<TradeFormPage> {
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  
  TransactionType _transactionType = TransactionType.buy;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _priceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('${widget.holding.symbol} - 交易'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _handleTrade,
          child: _isLoading 
              ? const CupertinoActivityIndicator()
              : const Text('确认'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHoldingInfo(),
            const SizedBox(height: 24),
            _buildTradeForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingInfo() {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前持仓',
            style: QHTypography.subheadline.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  '股票代码',
                  widget.holding.symbol,
                  labelColor,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  '持仓数量',
                  '${widget.holding.quantity.toStringAsFixed(0)} 股',
                  labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  '平均成本',
                  '¥${widget.holding.averageCost.toStringAsFixed(2)}',
                  labelColor,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  '持仓市值',
                  '¥${(widget.holding.quantity * widget.holding.averageCost).toStringAsFixed(2)}',
                  labelColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color valueColor) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.footnote.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTradeForm() {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '交易信息',
            style: QHTypography.subheadline.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          
          // 交易类型选择
          _buildTransactionTypeSelector(),
          const SizedBox(height: 24),
          
          // 交易数量
          _buildInputField(
            label: '交易数量',
            controller: _quantityController,
            placeholder: '股数',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          
          // 交易价格
          _buildInputField(
            label: '成交价格',
            controller: _priceController,
            placeholder: '每股价格',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),
          
          // 交易日期
          _buildDateSelector(),
          const SizedBox(height: 24),
          
          // 备注
          _buildInputField(
            label: '备注 (可选)',
            controller: _notesController,
            placeholder: '交易备注',
            keyboardType: TextInputType.text,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeSelector() {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '交易类型',
          style: QHTypography.subheadline.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<TransactionType>(
            groupValue: _transactionType,
            children: const {
              TransactionType.buy: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('买入'),
              ),
              TransactionType.sell: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('卖出'),
              ),
            },
            onValueChanged: (value) {
              if (value != null) {
                setState(() => _transactionType = value);
              }
            },
          ),
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

  Widget _buildDateSelector() {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '交易日期',
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
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
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
                initialDateTime: _selectedDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDate = newDate;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTrade() async {
    if (_isLoading) return;

    // 验证输入
    final quantityText = _quantityController.text.trim();
    final priceText = _priceController.text.trim();

    if (quantityText.isEmpty) {
      _showErrorDialog('请输入交易数量');
      return;
    }

    if (priceText.isEmpty) {
      _showErrorDialog('请输入成交价格');
      return;
    }

    final quantity = double.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      _showErrorDialog('请输入有效的交易数量');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      _showErrorDialog('请输入有效的成交价格');
      return;
    }

    // 检查卖出数量不能超过持仓
    if (_transactionType == TransactionType.sell && quantity > widget.holding.quantity) {
      _showErrorDialog('卖出数量不能超过持仓数量');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final transactionRepository = ref.read(transactionRepositoryProvider);
      final holdingRepository = ref.read(holdingRepositoryProvider);
      
      final amount = quantity * price;
      final notes = _notesController.text.trim();
      
      // 创建交易记录
      await transactionRepository.createTransaction(
        amount: amount,
        date: _selectedDate,
        type: _transactionType,
        category: _transactionType == TransactionType.buy ? '股票买入' : '股票卖出',
        notes: notes.isEmpty ? null : notes,
        fromAccountId: _transactionType == TransactionType.buy ? widget.holding.accountId : null,
        toAccountId: _transactionType == TransactionType.sell ? widget.holding.accountId : null,
        relatedHoldingId: widget.holding.id,
      );

      // 更新持仓
      if (_transactionType == TransactionType.buy) {
        // 买入：更新数量和平均成本
        final newQuantity = widget.holding.quantity + quantity;
        final totalCost = (widget.holding.quantity * widget.holding.averageCost) + amount;
        final newAverageCost = totalCost / newQuantity;
        
        await holdingRepository.updateHolding(
          widget.holding,
          quantity: newQuantity,
          averageCost: newAverageCost,
        );
      } else {
        // 卖出：只更新数量
        final newQuantity = widget.holding.quantity - quantity;
        
        if (newQuantity > 0) {
          await holdingRepository.updateHolding(
            widget.holding,
            quantity: newQuantity,
          );
        } else {
          // 如果全部卖出，删除持仓
          await holdingRepository.deleteHolding(widget.holding.id);
        }
      }

      // 更新账户余额
      final accountRepository = ref.read(accountRepositoryProvider);
      final account = await accountRepository.getAccountById(widget.holding.accountId);
      if (account != null) {
        final newBalance = _transactionType == TransactionType.buy
            ? account.balance - amount  // 买入减少现金
            : account.balance + amount; // 卖出增加现金
            
        await accountRepository.updateAccount(
          account,
          balance: newBalance,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('交易失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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