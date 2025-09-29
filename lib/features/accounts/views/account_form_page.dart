import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../providers/repository_providers.dart';

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.account});

  final Account? account;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _commissionController;
  late final TextEditingController _stampTaxController;
  late AccountType _selectedType;
  bool _isSaving = false;

  bool get _requiresBalance =>
      _selectedType == AccountType.cash || _selectedType == AccountType.liability;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _selectedType = account?.type ?? AccountType.investment;
    _nameController = TextEditingController(text: account?.name ?? '');
    final initialBalance = account?.balance ?? 0;
    _balanceController = TextEditingController(
      text: initialBalance == 0 ? '' : initialBalance.toStringAsFixed(2),
    );
    _commissionController = TextEditingController(
      text: (account?.commissionRate ?? AccountRepository.defaultCommissionRate)
          .toStringAsFixed(4),
    );
    _stampTaxController = TextEditingController(
      text: (account?.stampTaxRate ?? AccountRepository.defaultStampTaxRate)
          .toStringAsFixed(4),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _commissionController.dispose();
    _stampTaxController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final rawBalance = _balanceController.text.trim();
    final balance = _requiresBalance ? double.tryParse(rawBalance) ?? 0.0 : 0.0;
  final commissionRateRaw = double.tryParse(_commissionController.text.trim());
  final stampTaxRateRaw = double.tryParse(_stampTaxController.text.trim());
  final commissionRate = commissionRateRaw ?? AccountRepository.defaultCommissionRate;
  final stampTaxRate = stampTaxRateRaw ?? AccountRepository.defaultStampTaxRate;

  final normalizedCommissionRate = commissionRate < AccountRepository.minCommissionRate
    ? AccountRepository.minCommissionRate
    : commissionRate;
  final normalizedStampTaxRate = stampTaxRate < 0 ? 0.0 : stampTaxRate;
    final repository = ref.read(accountRepositoryProvider);

    setState(() => _isSaving = true);
    try {
      if (widget.account == null) {
        await repository.createAccount(
          name: name,
          type: _selectedType,
          balance: balance,
          commissionRate: normalizedCommissionRate,
          stampTaxRate: normalizedStampTaxRate,
        );
      } else {
        await repository.updateAccount(
          widget.account!,
          name: name,
          type: _selectedType,
          balance: _requiresBalance ? balance : widget.account!.balance,
          commissionRate: normalizedCommissionRate,
          stampTaxRate: normalizedStampTaxRate,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('保存失败'),
          content: Text(error.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onTypeChanged(AccountType? newType) {
    if (newType == null) return;
    setState(() {
      _selectedType = newType;
      if (!_requiresBalance) {
        _balanceController.text = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? '编辑账户' : '新建账户'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isSaving ? null : _handleSubmit,
          child: _isSaving
              ? const CupertinoActivityIndicator()
              : const Text('保存'),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('基础信息'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _nameController,
                    placeholder: '账户名称',
                    prefix: const Text('名称'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '账户名称不能为空';
                      }
                      return null;
                    },
                  ),
                  CupertinoFormRow(
                    prefix: const Text('类型'),
                    child: CupertinoSlidingSegmentedControl<AccountType>(
                      groupValue: _selectedType,
                      children: {
                        for (final type in AccountType.values)
                          type: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(type.displayName),
                          ),
                      },
                      onValueChanged: (value) {
                        if (_isSaving) return;
                        _onTypeChanged(value);
                      },
                    ),
                  ),
                  if (_requiresBalance)
                    CupertinoTextFormFieldRow(
                      controller: _balanceController,
                      prefix: const Text('余额'),
                      placeholder: '¥0.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (!_requiresBalance) {
                          return null;
                        }
                        if (value == null || value.trim().isEmpty) {
                          return '请输入余额';
                        }
                        final number = double.tryParse(value.trim());
                        if (number == null) {
                          return '请输入合法数字';
                        }
                        if (number < 0) {
                          return '余额不能为负数';
                        }
                        return null;
                      },
                    ),
                  if (_selectedType == AccountType.investment) ...[
                    CupertinoTextFormFieldRow(
                      controller: _commissionController,
                      prefix: const Text('佣金率'),
                      placeholder: '0.0003',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final number = double.tryParse((value ?? '').trim());
                        if (number == null) {
                          return '请输入合法佣金率';
                        }
                        if (number < AccountRepository.minCommissionRate) {
                          return '佣金率不能低于万0.1';
                        }
                        return null;
                      },
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _stampTaxController,
                      prefix: const Text('印花税率'),
                      placeholder: '0.0010',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final number = double.tryParse((value ?? '').trim());
                        if (number == null) {
                          return '请输入合法税率';
                        }
                        if (number < 0) {
                          return '税率不能为负';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: CupertinoButton.filled(
                  onPressed: _isSaving ? null : _handleSubmit,
                  child: Text(isEditing ? '保存修改' : '创建账户'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
