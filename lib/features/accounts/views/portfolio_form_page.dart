import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../providers/repository_providers.dart';

class PortfolioFormPage extends ConsumerStatefulWidget {
  const PortfolioFormPage({super.key, this.portfolio});

  final Portfolio? portfolio;

  @override
  ConsumerState<PortfolioFormPage> createState() => _PortfolioFormPageState();
}

class _PortfolioFormPageState extends ConsumerState<PortfolioFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final portfolio = widget.portfolio;
    _nameController = TextEditingController(text: portfolio?.name ?? '');
    _descriptionController =
        TextEditingController(text: portfolio?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final repository = ref.read(portfolioRepositoryProvider);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (widget.portfolio == null) {
        await repository.createPortfolio(
          name: name,
          description: description.isEmpty ? null : description,
        );
      } else {
        await repository.updatePortfolio(
          widget.portfolio!,
          name: name,
          description: description.isEmpty ? null : description,
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.portfolio != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? '编辑组合' : '新建组合'),
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
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              CupertinoFormSection.insetGrouped(
                header: const Text('基本信息'),
                children: [
                  CupertinoTextFormFieldRow(
                    controller: _nameController,
                    prefix: const Text('名称'),
                    placeholder: '例如 沪深核心 1 号',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '组合名称不能为空';
                      }
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    controller: _descriptionController,
                    prefix: const Text('备注'),
                    placeholder: '策略、再平衡周期等',
                    maxLines: 3,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: CupertinoButton.filled(
                  onPressed: _isSaving ? null : _handleSubmit,
                  child: Text(isEditing ? '保存修改' : '创建组合'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
