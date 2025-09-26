import 'package:flutter_riverpod/flutter_riverpod.dart';

// 预设的支出类别
const List<String> predefinedCategories = [
  // 饮食
  '餐饮',
  '外卖',
  '零食',
  '咖啡茶饮',
  
  // 交通
  '交通出行',
  '打车',
  '公交地铁',
  '加油',
  '停车费',
  
  // 生活
  '日用品',
  '服装鞋包',
  '美容护理',
  '理发',
  '洗衣',
  
  // 居住
  '房租',
  '水电煤',
  '物业费',
  '家具家电',
  '房屋维修',
  
  // 娱乐
  '电影演出',
  '游戏娱乐',
  '旅游',
  '运动健身',
  '书籍',
  
  // 医疗
  '医疗费',
  '药品',
  '体检',
  
  // 教育
  '学费',
  '培训',
  '考试费',
  
  // 社交
  '聚餐',
  '礼品',
  '红包',
  
  // 其他
  '通讯费',
  '保险',
  '税费',
  '捐赠',
  '其他',
];

// 自定义类别管理
class CustomCategoriesNotifier extends StateNotifier<Set<String>> {
  CustomCategoriesNotifier() : super(<String>{});

  void addCategory(String category) {
    if (category.trim().isNotEmpty) {
      state = {...state, category.trim()};
    }
  }

  void removeCategory(String category) {
    state = state.where((cat) => cat != category).toSet();
  }

  void clearCategories() {
    state = <String>{};
  }
}

final customCategoriesProvider = StateNotifierProvider<CustomCategoriesNotifier, Set<String>>((ref) {
  return CustomCategoriesNotifier();
});

// 获取所有可用类别（预设 + 自定义）
final allCategoriesProvider = Provider<List<String>>((ref) {
  final customCategories = ref.watch(customCategoriesProvider);
  final allCategories = <String>[];
  
  // 先添加预设类别
  allCategories.addAll(predefinedCategories);
  
  // 再添加自定义类别（去重）
  for (final custom in customCategories) {
    if (!allCategories.contains(custom)) {
      allCategories.add(custom);
    }
  }
  
  return allCategories;
});