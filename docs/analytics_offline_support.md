# 分析页面离线支持改进

## 更新日期
2025年10月1日

## 问题描述

之前的分析页面在没有配置后端服务器地址时，会完全显示加载失败，即使支出洞察功能只依赖本地交易数据，不需要外部行情服务。

## 解决方案

### 架构调整

将分析页面拆分为两个独立部分：

1. **支出洞察部分**（不依赖后端）
   - 只使用本地交易数据
   - 即使没有后端服务器也能正常显示
   - 包括：支出摘要、每日轨迹、类别分布、月度收支对比等

2. **组合分析部分**（依赖后端行情数据）
   - 需要外部行情数据支持
   - 无后端时显示错误状态
   - 包括：资产概览、收益分析、风险矩阵、预测等

### 修改内容

#### 1. `analytics_tab_view.dart` - UI层面分离

**修改前：**
```dart
child: snapshotAsync.when(
  data: (snapshot) => Column([
    // 所有内容包括支出洞察
  ]),
  error: (error, stack) => _ErrorState(error: error),  // 整页错误
)
```

**修改后：**
```dart
child: Column([
  // 支出洞察部分 - 独立显示
  homeAsync.when(
    data: (home) => _AnalyticsHomeSection(...),
    error: (error, stack) => _SectionCard(child: _HomeErrorState(error: error)),
  ),
  
  // 组合分析部分 - 独立错误处理
  snapshotAsync.when(
    data: (snapshot) => _AnalyticsBody(...),
    error: (error, stack) => _ErrorState(error: error),
  ),
])
```

#### 2. `analytics_service.dart` - 数据层容错

**修改 `buildHomeSnapshot` 方法：**

```dart
Future<AnalyticsHomeSnapshot> buildHomeSnapshot({
  required NetWorthRange range,
}) async {
  // 支出洞察优先加载，不依赖行情数据
  final spending = await _buildSpendingOverview();
  
  // 组合预览依赖行情数据，失败时返回空列表
  List<PortfolioAnalyticsPreview> previews;
  try {
    previews = await _buildPortfolioPreviews(range: range);
  } catch (e) {
    // 行情数据加载失败时，仍可显示支出洞察
    previews = [];
  }
  
  return AnalyticsHomeSnapshot(
    generatedAt: DateTime.now(),
    previews: previews,
    spendingOverview: spending,
  );
}
```

## 用户体验改进

### 有后端服务器时
- ✅ 完整显示所有分析功能
- ✅ 支出洞察 + 组合分析都正常工作

### 无后端服务器时
- ✅ 支出洞察正常显示（完整功能）
- ✅ 组合分析显示友好错误提示
- ✅ 用户仍可查看消费分析和记账相关功能

## 技术优势

1. **模块化设计**：支出洞察和组合分析完全解耦
2. **优雅降级**：部分功能不可用时不影响其他功能
3. **用户友好**：清晰区分哪些功能可用，哪些需要配置
4. **开发便利**：本地开发时无需启动后端服务即可测试记账功能

## 测试场景

### 场景 1：完全离线（无后端）
- ✅ 支出洞察部分正常显示
- ✅ 可以查看消费统计、类别分布、月度对比
- ✅ 组合分析显示"需要配置后端服务器"提示

### 场景 2：后端连接失败
- ✅ 支出洞察部分正常显示
- ✅ 组合分析显示具体错误信息

### 场景 3：正常使用（有后端）
- ✅ 所有功能正常显示
- ✅ 与之前完全一致的体验

## 未来优化方向

1. **渐进式加载**：先显示支出洞察，后台加载组合分析
2. **缓存机制**：缓存上次成功的组合分析数据
3. **离线提示**：在组合分析区域添加"配置后端以启用更多功能"的引导
