import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design_system.dart';
import '../providers/category_providers.dart';

class CategorySelectionPage extends ConsumerStatefulWidget {
  const CategorySelectionPage({
    super.key,
    this.initialCategory,
  });

  final String? initialCategory;

  @override
  ConsumerState<CategorySelectionPage> createState() => _CategorySelectionPageState();
}

class _CategorySelectionPageState extends ConsumerState<CategorySelectionPage> {
  final TextEditingController _customCategoryController = TextEditingController();
  String? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.initialCategory != null && 
        !predefinedCategories.contains(widget.initialCategory)) {
      _customCategoryController.text = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _customCategoryController.clear();
    });
  }

  void _selectCustomCategory() {
    final customText = _customCategoryController.text.trim();
    if (customText.isNotEmpty) {
      setState(() {
        _selectedCategory = customText;
      });
    }
  }

  void _handleDone() {
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      // 如果是自定义类别，保存到provider中
      if (!predefinedCategories.contains(_selectedCategory)) {
        ref.read(customCategoriesProvider.notifier).addCategory(_selectedCategory!);
      }
      Navigator.of(context).pop(_selectedCategory);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoriesProvider);
    final background = CupertinoDynamicColor.resolve(QHColors.background, context);
    final cardBackground = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('选择类别'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _handleDone,
          child: Text(
            '完成',
            style: TextStyle(
              color: CupertinoDynamicColor.resolve(QHColors.primary, context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 预设类别
                  _CategorySection(
                    title: '常用类别',
                    subtitle: '选择适合的支出类别',
                    categories: predefinedCategories,
                    selectedCategory: _selectedCategory,
                    onSelect: _selectCategory,
                  ),
                  
                  // 自定义类别（如果有的话）
                  if (customCategories.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _CategorySection(
                      title: '我的类别',
                      subtitle: '之前自定义的类别',
                      categories: customCategories.toList(),
                      selectedCategory: _selectedCategory,
                      onSelect: _selectCategory,
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // 自定义输入
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '自定义类别',
                          style: QHTypography.subheadline.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '输入新的类别名称',
                          style: QHTypography.footnote.copyWith(color: secondaryColor),
                        ),
                        const SizedBox(height: 12),
                        CupertinoTextField(
                          controller: _customCategoryController,
                          placeholder: '例如：宠物用品',
                          style: QHTypography.body.copyWith(color: labelColor),
                          decoration: BoxDecoration(
                            color: CupertinoDynamicColor.resolve(
                              QHColors.groupedBackground,
                              context,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          onChanged: (value) => _selectCustomCategory(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.subtitle,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  final String title;
  final String subtitle;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cardBackground = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: QHTypography.subheadline.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: QHTypography.footnote.copyWith(color: secondaryColor),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((category) => _CategoryChip(
              label: category,
              isSelected: category == selectedCategory,
              onTap: () => onSelect(category),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoDynamicColor.resolve(QHColors.primary, context);
    final backgroundColor = isSelected
        ? primaryColor.withValues(alpha: 0.15)
        : CupertinoDynamicColor.resolve(QHColors.groupedBackground, context);
    final textColor = isSelected
        ? primaryColor
        : CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final borderColor = isSelected
        ? primaryColor.withValues(alpha: 0.3)
        : CupertinoDynamicColor.resolve(CupertinoColors.separator, context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Text(
          label,
          style: QHTypography.footnote.copyWith(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}