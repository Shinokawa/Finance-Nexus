# Finance Nexus

<!-- markdownlint-disable MD033 -->

一个面向个人使用的"资产与投资记录"管理与可视化工具

## 这是做什么的

把分散在不同地方的：

- 账户（现金 / 投资 / 负债）
- 投资组合（一个自定义的分类视角）
- 持仓（股票 / ETF）
- 资金与交易记录

集中到一个本地应用里，方便自己看：现在有多少、结构怎样、最近盈亏如何。

## 为什么做

市面上的记账偏日常消费；券商 App 又只看到单账户。自己想要一个更贴近"资产全貌 + 自己的分类方式"的视图，同时数据留在本地，不上传。

## 下载安装

### iOS 用户

- **App Store**: [点击下载](https://apps.apple.com/cn/app/finanexus/id6753062154?l=en-GB)

### macOS 用户

- 从 [Releases](https://github.com/Shinokawa/Finance-Nexus/releases) 页面下载 .dmg 文件

### 开发者

如果你想从源码构建，请参见下方的"从源码构建"部分。

## 主要功能

### 仪表板

- 总资产概览与净值变化
- 账户余额和持仓汇总
- 收益率统计和趋势图表

### 账户管理

- 多账户支持（银行卡、券商账户、现金等）
- 账户分类和余额跟踪
- 账户间资金转移记录

### 投资组合

- 自定义投资组合分类
- 持仓管理和成本跟踪
- 实时行情数据（需配置后端）

### 交易记录

- 完整的交易历史记录
- 买入卖出、分红、转账等操作
- 交易成本和收益计算

### 分析工具

- 资产配置分析
- 收益率分析和风险评估
- 历史净值曲线图
- 投资组合相关性分析

### 后端配置

- 可配置的后端服务器地址
- API 密钥管理
- 实时行情数据获取
- 数据同步设置

## 截图

<div style="display: flex; flex-wrap: nowrap; justify-content: center; gap: 12px; margin: 0 auto; max-width: 900px;">
    <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.08.46.png" alt="仪表盘" style="width: 150px; border-radius: 12px;" />
    <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.13.23.png" alt="持仓情况" style="width: 150px; border-radius: 12px;" />
    <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.08.57.png" alt="账户" style="width: 150px; border-radius: 12px;" />
    <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.09.09.png" alt="分析" style="width: 150px; border-radius: 12px;" />
    <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.22.43.png" alt="分析矩阵" style="width: 150px; border-radius: 12px;" />
</div>

<p style="text-align: center; margin-top: 8px;">仪表盘 · 持仓情况 · 账户 · 分析 · 协方差矩阵</p>

## 快速开始

### 从源码构建

1. **克隆仓库**

   ```bash
   git clone https://github.com/Shinokawa/Finance-Nexus.git
   cd Finance-Nexus
   ```

2. **安装依赖**

   ```bash
   flutter pub get
   ```

3. **运行应用**

   ```bash
   # iOS
   flutter run -d ios
   
   # macOS  
   flutter run -d macos
   ```

### 系统要求

- **iOS**: iOS 12.0+
- **macOS**: macOS 10.15+
- **开发环境**: Flutter 3.x

### 首次使用

1. **配置后端服务**（可选）
   - 打开应用 → 设置 → 后端服务 → 服务器配置
   - 推荐使用：`https://quetos-api.onrender.com`（公共测试实例）
   - 或部署私有实例，详见：[后端配置指南](docs/backend_setup.md)

2. **创建账户**
   - 在"账户"页面添加您的银行卡、券商账户等
   - 设置初始余额

3. **添加持仓**
   - 记录您的股票、ETF等投资产品
   - 输入持仓数量和成本价

4. **开始记录**
   - 添加交易记录
   - 查看资产分析

## 🌐 后端配置

Finance Nexus 支持连接后端 API 服务获取实时股票/ETF行情数据。

### 📊 公共 API 服务

我们提供免费的公共 API 实例供测试使用：

**API 地址**: `https://quetos-api.onrender.com`

> ⚠️ **注意**: 免费服务可能有冷启动延迟，推荐高频使用者部署私有实例

### 🚀 快速配置

1. **使用公共服务**（推荐新手）
   - 打开应用 → 设置 → 后端服务 → 服务器配置
   - 输入：`https://quetos-api.onrender.com`
   - 保存即可使用

2. **部署私有实例**（推荐长期使用）
   - 一键部署到 Render/Vercel 等平台
   - 完全免费，性能更稳定
   - 详见：📋 [**后端部署指南**](docs/backend_setup.md)

### 🔧 API 功能

- ✅ A股/ETF实时行情（沪深两市）
- ✅ 历史K线数据（日线级别）
- ✅ 智能缓存机制（非交易时间使用缓存）
- ✅ 支持批量查询（多只股票同时获取）
- ✅ 自动识别证券类型（股票/ETF）
- ✅ 数据来源：akshare

## 支持平台

- ✅ iOS (主要平台)
- ✅ macOS
- 🔄 Android (计划中)

## 技术架构

- **框架**: Flutter 3.x with Cupertino Design System
- **状态管理**: Riverpod (Provider-based)
- **数据库**: SQLite + Drift ORM
- **网络**: http + 自定义API客户端
- **架构模式**: Repository Pattern + MVVM
- **图表**: 自定义图表组件

## 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/amazing-feature`
3. 提交更改：`git commit -m 'Add some amazing feature'`
4. 推送分支：`git push origin feature/amazing-feature`
5. 创建 Pull Request

## 许可证

本项目采用 MIT License - 详见 [LICENSE](LICENSE) 文件

## 隐私声明

- ✅ 所有数据存储在本地设备
- ✅ 不会上传个人财务信息到云端
- ✅ 行情数据来源可自定义配置
- ✅ 完全离线使用（除行情数据外）

## 致谢

- 感谢 [akshare](https://github.com/akfamily/akshare) 提供免费的金融数据接口
- 感谢 Flutter 团队提供优秀的跨平台框架
