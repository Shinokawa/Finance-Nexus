# macOS 打包和分发指南

## 概述

这套脚本帮助你将 Finance Nexus Flutter 应用打包为 macOS DMG 安装包，并支持 Apple 代码签名和公证流程。

## 文件结构

```
scripts/
├── .env.example          # 环境变量配置模板
├── build_and_package.sh  # 一键构建和打包脚本
├── create_dmg.sh         # DMG 创建脚本
├── sign_app.sh           # 代码签名脚本
└── notarize.sh           # 公证脚本
```

## 快速开始

### 1. 基础打包（无签名）

如果你只是想创建一个基础的 DMG 安装包进行测试：

```bash
# 一键构建和打包
./scripts/build_and_package.sh
```

这将会：
- 清理项目并获取依赖
- 构建 release 版本的 macOS 应用
- 创建 DMG 安装包

### 2. 专业分发（包含签名和公证）

如果你需要分发给其他用户，需要进行代码签名和公证：

#### 步骤 1: 配置开发者信息

```bash
# 复制配置模板
cp scripts/.env.example scripts/.env

# 编辑配置文件
open scripts/.env
```

填写你的开发者信息：
- `DEVELOPER_ID`: 开发者证书名称
- `APPLE_ID`: Apple ID 邮箱
- `APPLE_ID_PASSWORD`: App专用密码
- `TEAM_ID`: 开发者团队ID

#### 步骤 2: 一键完整打包

```bash
# 包含签名和公证的完整流程
./scripts/build_and_package.sh
```

或者分步执行：

```bash
# 构建应用
flutter build macos --release

# 代码签名
./scripts/sign_app.sh

# 创建 DMG（会自动签名和公证）
./scripts/create_dmg.sh
```

## 详细配置

### Apple 开发者证书设置

1. **获取开发者证书**
   - 访问 [Apple Developer](https://developer.apple.com/account/resources/certificates/)
   - 创建 "Developer ID Application" 证书
   - 下载并双击安装到钥匙串

2. **查找证书名称**
   ```bash
   # 查看可用证书
   security find-identity -v -p codesigning
   ```

3. **配置证书**
   在 `.env` 文件中设置：
   ```bash
   DEVELOPER_ID="Developer ID Application: Your Name (XXXXXXXXXX)"
   ```

### Apple ID 公证设置

1. **生成App专用密码**
   - 访问 [Apple ID](https://appleid.apple.com/account/manage)
   - 登录后在"安全"部分生成密码
   - 为"DMG公证"创建专用密码

2. **查找团队ID**
   - 登录 Apple Developer 账户
   - 在 "Membership" 页面查看 Team ID

3. **配置公证信息**
   ```bash
   APPLE_ID="your-apple-id@example.com"
   APPLE_ID_PASSWORD="your-app-specific-password"  
   TEAM_ID="XXXXXXXXXX"
   ```

## 脚本说明

### build_and_package.sh
完整的构建和打包流程，包括：
- Flutter 清理和依赖获取
- macOS 应用构建
- 自动调用 DMG 创建脚本

### create_dmg.sh
DMG 创建的核心脚本：
- 创建安装包布局
- 设置 Finder 窗口样式
- 添加 Applications 快捷方式
- 自动代码签名和公证

### sign_app.sh
单独的代码签名工具：
- 签名应用及其依赖框架
- 验证签名完整性
- 检查系统信任状态

### notarize.sh
公证处理工具：
- 提交公证申请
- 等待公证完成
- 装订公证票据
- 验证最终结果

## 故障排除

### 证书问题
```bash
# 检查证书是否正确安装
security find-identity -v -p codesigning

# 验证证书可以使用
codesign --sign "Developer ID Application: Your Name" --test-sign /Applications/Calculator.app
```

### 公证问题
```bash
# 验证 Apple ID 和密码
xcrun notarytool history --apple-id "your-id" --password "your-password" --team-id "TEAM_ID"

# 检查公证日志
xcrun notarytool log SUBMISSION_ID --apple-id "your-id" --password "your-password" --team-id "TEAM_ID"
```

### 常见错误

1. **"找不到开发者证书"**
   - 确保证书已正确安装到钥匙串
   - 检查 `.env` 文件中的证书名称是否准确

2. **"公证失败"**
   - 确认 App专用密码正确（不是 Apple ID 密码）
   - 检查团队ID是否正确
   - 确保应用已正确签名

3. **"DMG 挂载失败"**
   - 检查磁盘空间是否充足
   - 确保没有其他 DMG 正在挂载

## 输出文件

成功执行后，你将得到：

```
build/
├── Finance-Nexus-1.0.0.dmg  # 最终的安装包
└── macos/
    └── Build/
        └── Products/
            └── Release/
                └── quant_hub.app  # 构建的应用
```

## 分发说明

- **已签名和公证的 DMG**: 可以直接分发给用户
- **未签名的 DMG**: 用户需要在"安全性与隐私"中允许运行
- **首次运行**: 用户可能需要右键点击应用选择"打开"

## 安全注意事项

- `.env` 文件包含敏感信息，不要提交到版本控制
- App专用密码应妥善保管
- 定期更新开发者证书