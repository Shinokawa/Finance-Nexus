# 后端配置功能

## 概述

应用现在支持自定义后端服务器配置，用户可以在设置中配置自己的后端服务器地址和API密钥（可选）。

## 功能特点

1. **可配置后端URL**: 用户可以设置自己的后端服务器地址
2. **可选API密钥**: 支持配置API密钥进行身份验证（留空则无需认证）
3. **动态配置**: 配置更改会立即生效，无需重启应用
4. **错误处理**: 当后端未配置时，会显示友好的错误信息提示用户配置

## 配置步骤

1. 打开应用，切换到"设置"页面
2. 在"后端服务"部分，点击"服务器配置"
3. 在弹出的对话框中：
   - 输入后端服务器地址，例如: `http://192.168.1.100:8080`
   - 如果后端需要API密钥，输入密钥；否则留空
4. 点击"保存"

## URL格式示例

- 本地服务器: `http://localhost:8080`
- 局域网服务器: `http://192.168.1.100:8080`
- 外网服务器: `https://api.example.com`

## API认证

当配置了API密钥时，应用会在请求头中添加:

```http
Authorization: Bearer <your-api-key>
```

如果您的后端使用其他认证方式，请修改：

- `lib/data/network/quote_api_client.dart` 中的认证头格式
- `lib/services/market_data_service.dart` 中的认证头格式

## 技术实现

### 主要修改的文件

1. **设置存储**: `lib/providers/app_settings_provider.dart`
   - 添加了 `backendUrl` 和 `backendApiKey` 字段
   - 实现设置的持久化存储

2. **UI组件**: `lib/features/settings/widgets/backend_config_section.dart`
   - 新增后端配置界面组件

3. **网络客户端**: `lib/data/network/quote_api_client.dart`
   - 支持动态URL和API密钥
   - 改进错误处理

4. **市场数据服务**: `lib/services/market_data_service.dart`
   - 从静态方法改为实例方法
   - 支持配置化的URL和API密钥

5. **服务提供器**:
   - `lib/providers/network_providers.dart`
   - `lib/providers/market_data_service_provider.dart`
   - 更新相关服务提供器以支持动态配置

### 配置流程

1. 用户在设置界面配置后端信息
2. 配置保存到本地存储 (SharedPreferences)
3. 所有网络服务通过Riverpod自动监听配置变化
4. 网络请求使用最新的配置进行API调用

## 初始状态

- 应用不再硬编码开发服务器地址
- 首次启动时，后端URL为空，用户需要自行配置
- 在用户配置后端之前，相关功能会显示"未配置后端服务器"的提示

这种设计让用户可以完全控制数据来源，提高了应用的灵活性和安全性。