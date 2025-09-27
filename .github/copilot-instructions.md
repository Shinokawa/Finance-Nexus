# Finance-Nexus AI 开发指南

## 🏗️ 架构概览

**Finance-Nexus** 是基于 Flutter + Cupertino 设计的个人资产管理应用，采用 **Riverpod 状态管理** + **Drift ORM** + **Repository 模式**的分层架构。

### 核心技术栈
- **UI框架**: Flutter 3.x with Cupertino Design System  
- **状态管理**: Riverpod (Provider-based)
- **数据库**: SQLite + Drift ORM
- **网络**: http + 自定义API客户端  
- **架构**: Repository Pattern + MVVM

### 目录结构规范
```
lib/
├── core/              # 共享枚举和常量
├── data/              # 数据层 (DAO/网络/Repository)
├── design/            # 设计系统 (QHColors, QHTypography, QHTheme)
├── features/          # 功能模块 (每个模块包含views/models/providers)
├── providers/         # 全局状态提供者
├── services/          # 业务逻辑服务
└── widgets/           # 通用组件
```

## 📊 数据架构

### Drift ORM 模式
- **表定义**: `lib/data/local/app_database.dart` 使用 `@DataClassName` 注解
- **DAO访问器**: `@DriftAccessor` 提供类型安全的数据库操作
- **代码生成**: 运行 `flutter packages pub run build_runner build` 生成访问代码

### Repository Pattern 实现
```dart
// 标准Repository结构：
class AccountRepository {
  AccountRepository(this._accountDao);
  final AccountDao _accountDao;
  
  Stream<List<Account>> watchAccounts() => _accountDao.watchAllAccounts();
  // ... CRUD操作
}
```

### Provider 层级结构
1. **DAO Providers**: 数据库访问对象 (`dao_providers.dart`)
2. **Repository Providers**: 业务逻辑封装 (`repository_providers.dart`)  
3. **Feature Providers**: 功能特定状态 (各feature目录下)

## 🎨 UI/UX 规范

### Cupertino 设计系统
- **主题**: `QHTheme.theme(brightness)` 支持明暗模式
- **颜色**: `QHColors` - 使用 `CupertinoDynamicColor` 适配主题
- **间距**: `QHSpacing` - 统一的布局常量
- **字体**: `QHTypography` - 基于iOS设计规范

### 组件使用约定
```dart
// 标准页面结构
CupertinoPageScaffold(
  backgroundColor: CupertinoDynamicColor.resolve(QHColors.background, context),
  child: CustomScrollView(
    slivers: [
      const CupertinoSliverNavigationBar(largeTitle: Text('页面标题')),
      // 内容...
    ],
  ),
)
```

### 卡片式布局模式
使用 `_SectionCard` 包装内容，提供统一的阴影和圆角效果。

## 🔄 状态管理

### Riverpod 使用模式
```dart
// StateProvider: 简单状态
final selectedTargetProvider = StateProvider<Target>((ref) => defaultTarget);

// FutureProvider: 异步数据
final dataProvider = FutureProvider<Data>((ref) async {
  final repository = ref.watch(repositoryProvider);
  return repository.getData();
});

// StreamProvider: 响应式数据流
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final repository = ref.watch(accountRepositoryProvider);  
  return repository.watchAccounts();
});
```

### 数据依赖管理
- 使用 `ref.watch()` 建立响应式依赖
- 使用 `ref.read()` 执行一次性操作
- 使用 `ref.refresh()` 主动刷新数据

## 🌐 网络与API

### 后端集成架构
- **报价服务**: `QuoteApiClient` 处理实时行情获取
- **历史数据**: `MarketDataService` 管理缓存和增量更新
- **配置化**: 支持自定义后端URL和API密钥

### API客户端模式
```dart
// 标准API响应处理
final response = await http.get(uri);
if (response.statusCode != 200) {
  return ErrorResult('HTTP ${response.statusCode}');
}
final data = jsonDecode(response.body) as Map<String, dynamic>;
```

### 智能缓存策略
- 文件系统缓存历史数据 (`getApplicationDocumentsDirectory()`)
- 增量更新避免重复请求
- 非交易时间使用缓存数据

## 🔧 开发工作流

### 代码生成
```bash
# Drift数据库代码生成
flutter packages pub run build_runner build --delete-conflicting-outputs

# 清理生成代码
flutter packages pub run build_runner clean
```

### 调试与测试
- **调试种子数据**: `debug_seed_provider.dart` 仅在非发布模式下启用
- **设置**: 支持开发/生产环境自动切换

### 构建与发布
- **macOS**: 使用 `scripts/build_and_package.sh` 一键构建DMG
- **代码签名**: 配置 `.env` 文件设置开发者证书
- **公证流程**: 自动化Apple公证处理

## 💡 代码约定

### 命名规范
- **私有组件**: `_ComponentName` (下划线前缀)
- **枚举扩展**: `extension AccountTypeLabel on AccountType`
- **Provider命名**: `xxxProvider` 后缀

### 错误处理
```dart
// AsyncValue模式处理异步状态
asyncValue.when(
  data: (data) => SuccessWidget(data),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
)
```

### 本地化
界面文案使用中文，关键业务术语保持一致（如"组合"、"持仓"、"流水"等）。

## 📱 平台特性

### 跨平台支持
- **主要**: iOS/macOS (Cupertino设计)
- **计划**: Android支持

### 数据隐私
- 完全本地存储，无云端同步
- 可选的外部行情数据源
- 用户自主控制数据流向

---

在实现新功能时，优先考虑与现有架构的一致性，保持 Cupertino 设计语言，并确保数据层的响应式更新机制正常工作。