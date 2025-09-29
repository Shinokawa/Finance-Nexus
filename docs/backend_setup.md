# Finance Nexus 后端配置指南

## 📊 关于后端服务

Finance Nexus 支持连接后端 API 服务来获取实时股票/ETF行情数据。我们基于 Flask 和 Akshare 构建了一个轻量级的行情 API 服务器。

## 🌐 公共 API 服务

### 免费公共实例

我提供了一个托管在 Render 上的免费公共实例，适用于个人测试和轻度使用：

**API 地址**: `https://quetos-api.onrender.com`

### ⚠️ 重要提示

- **免费服务**: 基于 Render 免费套餐部署
- **冷启动延迟**: 15分钟无请求后会休眠，首次访问需等待15-30秒
- **请勿滥用**: 避免高频自动化请求，推荐高频使用者部署私有实例

### API 接口说明

#### 1. 获取历史日K线数据

```http
GET /api/history
```

**参数**:
- `symbol` (必需): 股票/ETF代码，如 `sh600519`、`sz159915`
- `start_date` (可选): 开始日期 `YYYYMMDD`，默认 `20200101`
- `end_date` (可选): 结束日期 `YYYYMMDD`，默认今天

**示例**:
```bash
# 贵州茅台历史数据
curl "https://quetos-api.onrender.com/api/history?symbol=sh600519"

# 沪深300ETF历史数据
curl "https://quetos-api.onrender.com/api/history?symbol=sh510300"
```

#### 2. 获取实时行情报价

```http
GET /api/quotes
```

**参数**:
- `symbols` (必需): 股票/ETF代码，多个用逗号分隔

**示例**:
```bash
# 单只股票
curl "https://quetos-api.onrender.com/api/quotes?symbols=sh600519"

# 多只证券
curl "https://quetos-api.onrender.com/api/quotes?symbols=sh600519,sh510300,sz000001"
```

## 🚀 部署私有实例

为获得最佳性能和稳定性，推荐部署自己的私有实例。

### 方案一：Render 一键部署 (推荐)

#### 准备工作
1. 拥有 GitHub 账号
2. Fork [后端仓库](https://github.com/Shinokawa/quetos-api)

#### 部署步骤

**第一步：准备代码仓库**

确保你的仓库包含以下文件：

1. `app.py` - 主程序代码
2. `requirements.txt` - 依赖列表:

```text
# 核心 Web 框架
flask

# Akshare 金融数据接口库
akshare

# 数据处理库 (akshare 依赖)
pandas

# 定时任务库
schedule

# 时区处理库
pytz

# 生产环境 Web 服务器 (Render 运行时需要)
gunicorn
```

**第二步：在 Render 部署**

1. 访问 [render.com](https://render.com) 并用 GitHub 登录
2. 点击 **New + → Web Service**
3. 选择你的仓库并点击 **Connect**
4. 配置服务：
   - **Name**: `my-quotes-api`（自定义名称）
   - **Runtime**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`
   - **Instance Type**: `Free`
5. 点击 **Create Web Service**

**第三步：获取服务URL**

几分钟后，你将获得专属的服务地址，如：
`https://my-quotes-api.onrender.com`

### 方案二：本地部署

#### 环境要求
- Python 3.8+
- pip 包管理器

#### 部署步骤

1. **创建项目**
```bash
mkdir finance-quotes-api
cd finance-quotes-api
```

2. **创建虚拟环境**
```bash
python -m venv venv
source venv/bin/activate  # Linux/macOS
# Windows: venv\\Scripts\\activate
```

3. **安装依赖**
```bash
pip install flask akshare pandas schedule pytz gunicorn
```

4. **创建应用文件**

创建 `app.py` 并复制[完整后端代码](https://github.com/Shinokawa/quetos-api/blob/main/app.py)

5. **运行服务**
```bash
python app.py
```

服务将在 `http://localhost:5000` 启动

### 方案三：Docker 部署

```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

```bash
docker build -t finance-quotes-api .
docker run -p 5000:5000 finance-quotes-api
```

## ⚙️ 应用配置

### 在 Finance Nexus 中配置后端

1. 打开 Finance Nexus 应用
2. 前往 **设置** → **后端服务** → **服务器配置**
3. 输入后端地址:
   - 公共实例: `https://quetos-api.onrender.com`
   - 私有实例: `https://your-service.onrender.com`
   - 本地部署: `http://localhost:5000`
4. 保存配置

### 测试连接

配置完成后，在投资组合页面尝试刷新行情数据，验证后端连接是否正常。

## 🔒 安全说明

- 后端服务不存储任何用户数据
- 所有数据来源于公开的金融数据接口
- 建议私有部署以确保服务稳定性
- 如需要，可以添加 API 密钥认证

## 🆘 常见问题

### Q: 为什么首次访问很慢？
A: Render 免费套餐会在无请求时休眠，首次访问需要15-30秒唤醒时间。

### Q: 可以获取哪些市场的数据？
A: 目前支持A股和在中国大陆交易的ETF，包括沪深两市的股票和基金。支持的ETF代码前缀：51/56/58/15开头。

### Q: 数据更新频率如何？
A: 实时行情在交易时间内实时获取，非交易时间使用缓存数据。ETF数据在交易时间内每10分钟自动更新。

### Q: 如何提高服务稳定性？
A: 推荐部署私有实例，或升级到 Render 付费套餐避免冷启动。

### Q: 支持港股/美股吗？
A: 当前版本基于akshare主要支持A股市场，后续版本将考虑扩展其他市场。

### Q: API有调用频率限制吗？
A: 公共实例请避免高频请求，私有实例无限制。服务内置智能缓存减少重复调用。

---

如有问题，欢迎在 [Issues](https://github.com/Shinokawa/Finance-Nexus/issues) 中反馈！