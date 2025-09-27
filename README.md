# Finance Nexus

<!-- markdownlint-disable MD033 -->

一个面向个人使用的"资产与投资记录"管理与可视化工具

## 截图

<div style="display: flex; flex-wrap: nowrap; justify-content: center; gap: 12px;">
        <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.08.46.png" alt="仪表盘" style="width: 160px; border-radius: 12px;" />
        <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.13.23.png" alt="持仓情况" style="width: 160px; border-radius: 12px;" />
        <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.08.57.png" alt="账户" style="width: 160px; border-radius: 12px;" />
        <img src="pic/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-09-27%20at%2023.09.09.png" alt="分析" style="width: 160px; border-radius: 12px;" />
</div>

<p align="center">仪表盘 · 持仓情况 · 账户 · 分析</p>

## 这是做什么的

把分散在不同地方的：

- 账户（现金 / 投资 / 负债）
- 投资组合（一个自定义的分类视角）
- 持仓（股票 / ETF）
- 资金与交易记录

集中到一个本地应用里，方便自己看：现在有多少、结构怎样、最近盈亏如何。

## 为什么做

市面上的记账偏日常消费；券商 App 又只看到单账户。自己想要一个更贴近"资产全貌 + 自己的分类方式"的视图，同时数据留在本地，不上传。

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

### ⚙️ 后端配置

- 支持自定义后端服务器
- 可选API密钥认证
- 实时行情数据获取

## 快速开始

### 下载安装

#### iOS 用户

- **侧载**: 从 [Releases](https://github.com/Shinokawa/Finance-Nexus/releases) 页面下载最新的 .ipa 文件
- **TestFlight**: 即将上线（敬请期待）
- **App Store**: 计划上架

#### macOS 用户

- 从 [Releases](https://github.com/Shinokawa/Finance-Nexus/releases) 页面下载 .dmg 文件

#### 开发者

如果你想从源码构建：

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
   - 输入您的后端服务器地址，如：`http://localhost:8080`
   - 如需要，配置API密钥

2. **创建账户**
   - 在"账户"页面添加您的银行卡、券商账户等
   - 设置初始余额

3. **添加持仓**
   - 记录您的股票、ETF等投资产品
   - 输入持仓数量和成本价

4. **开始记录**
   - 添加交易记录
   - 查看资产分析

## 后端配置指南

应用支持连接自定义后端服务来获取实时行情数据。你可以部署自己的后端服务，完全控制数据源。

### 后端部署教程

我们提供了一个基于 Flask + akshare 的后端实现，支持A股和ETF的实时行情及历史数据。

#### 环境要求

- Python 3.8+
- pip 包管理器

#### 部署步骤

1. **创建项目目录**

   ```bash
   mkdir finance-nexus-backend
   cd finance-nexus-backend
   ```

2. **创建虚拟环境**

   ```bash
   python -m venv venv
   source venv/bin/activate  # Linux/macOS
   # 或者 Windows: venv\Scripts\activate
   ```

3. **安装依赖**

   ```bash
   pip install flask akshare pandas schedule pytz gunicorn
   ```

4. **创建应用文件**

   创建 `app.py` 文件并复制以下代码：

    <details>
    <summary>点击展开完整后端代码</summary>

   ```python
   # coding: utf-8

   from flask import Flask, jsonify, request
   import akshare as ak
   import logging
   import pandas as pd
   import schedule
   import time
   import threading
   from datetime import datetime
   import pytz

   # 初始化
   logging.basicConfig(level=logging.INFO)
   app = Flask(__name__)

   # 优化: 让 jsonify 返回的 json 字符串能直接显示中文
   app.json.ensure_ascii = False

   # 全局变量与锁
   etf_cache_df = None
   stock_cache = {}  # 用于缓存股票收盘价数据
   cache_lock = threading.Lock()

   def is_trade_time():
       """判断当前是否为A股交易时间。"""
       tz = pytz.timezone('Asia/Shanghai')
       now = datetime.now(tz)
       # 判断是否为周一至周五
       if 1 <= now.isoweekday() <= 5:
           # 判断是否在交易时间段内
           now_time = now.time()
           if (datetime.strptime("09:25", "%H:%M").time() <= now_time <= datetime.strptime("11:31", "%H:%M").time()) or \
              (datetime.strptime("12:55", "%H:%M").time() <= now_time <= datetime.strptime("15:01", "%H:%M").time()):
               return True
       return False

   def update_etf_cache():
       """获取并更新全局的ETF行情缓存。"""
       global etf_cache_df
       app.logger.info("计划任务触发：准备更新ETF缓存...")
       try:
           temp_df = ak.fund_etf_spot_em()
           if temp_df is not None and not temp_df.empty:
               temp_df.set_index('代码', inplace=True)
               with cache_lock:
                   etf_cache_df = temp_df
               app.logger.info(f"ETF行情缓存更新成功！共获取 {len(temp_df)} 条数据。")
           else:
               app.logger.warning("fund_etf_spot_em() 返回了空数据。")
       except Exception as e:
           app.logger.error(f"更新ETF缓存时发生严重错误: {e}")

   def clear_stock_cache():
       """清空股票缓存，为新交易日做准备。"""
       global stock_cache
       with cache_lock:
           if stock_cache:
               app.logger.info(f"清空旧的股票缓存，共 {len(stock_cache)} 条数据。")
           stock_cache = {}

   def run_schedule():
       """后台调度任务的循环。"""
       app.logger.info("后台调度线程已启动。")
       schedule.every().day.at("09:25", "Asia/Shanghai").do(clear_stock_cache)
       schedule.every().day.at("15:05", "Asia/Shanghai").do(update_etf_cache)
       schedule.every(10).minutes.do(lambda: is_trade_time() and update_etf_cache())
       
       while True:
           schedule.run_pending()
           time.sleep(1)

   @app.route('/api/quotes', methods=['GET'])
   def get_quotes():
       """获取实时行情数据（支持股票和ETF）"""
       symbols_str = request.args.get('symbols')
       if not symbols_str:
           return jsonify({"error": "请提供'symbols'查询参数"}), 400

       symbol_list = [symbol.strip() for symbol in symbols_str.split(',')]
       results = {}
       trade_time_now = is_trade_time()

       with cache_lock:
           current_etf_cache = etf_cache_df.copy() if etf_cache_df is not None else None

       for symbol in symbol_list:
           try:
               code_only = symbol.replace('sh', '').replace('sz', '')
               
               if code_only.startswith(('51', '56', '58', '15')):
                   # 处理ETF
                   if current_etf_cache is not None and code_only in current_etf_cache.index:
                       results[symbol] = {"status": "success", "data": current_etf_cache.loc[code_only].to_dict()}
                   else:
                       raise ValueError("在ETF缓存中未找到该代码")
               else:
                   # 处理股票
                   if not trade_time_now and symbol in stock_cache:
                       app.logger.info(f"[{symbol}] 命中股票收盘价缓存。")
                       results[symbol] = {"status": "success", "data": stock_cache[symbol]}
                   else:
                       app.logger.info(f"[{symbol}] {'交易时间' if trade_time_now else '非交易时间缓存未命中'}，实时请求...")
                       stock_df = ak.stock_bid_ask_em(symbol=symbol)
                       if stock_df is None or stock_df.empty:
                           raise ValueError("stock_bid_ask_em 返回空数据")
                       
                       quote_data = stock_df.set_index('item')['value'].to_dict()
                       results[symbol] = {"status": "success", "data": quote_data}
                       
                       if not trade_time_now:
                           with cache_lock:
                               stock_cache[symbol] = quote_data
           except Exception as e:
               app.logger.error(f"处理代码 {symbol} 时发生错误: {e}")
               results[symbol] = {"status": "error", "message": str(e)}

       return jsonify(results)

   @app.route('/api/history', methods=['GET'])
   def get_history():
       """获取单只股票或ETF的历史日K线数据。"""
       symbol = request.args.get('symbol')
       start_date = request.args.get('start_date', '20200101')
       end_date = request.args.get('end_date', datetime.now().strftime('%Y%m%d'))

       if not symbol:
           return jsonify({"status": "error", "message": "必须提供 'symbol' 参数。"}), 400

       try:
           code_only = symbol[-6:]
           app.logger.info(f"请求历史行情: symbol={symbol} (代码: {code_only}), start={start_date}, end={end_date}")

           history_df = None
           
           if code_only.startswith(('51', '56', '58', '15')):
               # ETF
               app.logger.info(f"代码 {code_only} 被识别为ETF，调用 fund_etf_hist_em。")
               history_df = ak.fund_etf_hist_em(symbol=code_only,
                                              period="daily",
                                              start_date=start_date,
                                              end_date=end_date,
                                              adjust="qfq")
           else:
               # 股票
               app.logger.info(f"代码 {code_only} 被识别为股票，调用 stock_zh_a_hist。")
               history_df = ak.stock_zh_a_hist(symbol=code_only,
                                             period="daily",
                                             start_date=start_date,
                                             end_date=end_date,
                                             adjust="qfq")

           if history_df is None or history_df.empty:
               raise ValueError(f"Akshare 未返回有效数据。请检查代码 '{symbol}' 和日期范围是否正确。")

           history_df['日期'] = history_df['日期'].astype(str)
           history_data = history_df.to_dict(orient='records')

           return jsonify({
               "status": "success",
               "symbol": symbol,
               "data": history_data
           })

       except Exception as e:
           app.logger.error(f"获取历史行情 {symbol} 时发生错误: {e}")
           return jsonify({"status": "error", "message": str(e)}), 500

   if __name__ == '__main__':
       app.logger.info("服务器以开发模式启动，开始初始化...")
       update_etf_cache()
       scheduler_thread = threading.Thread(target=run_schedule)
       scheduler_thread.daemon = True
       scheduler_thread.start()
       app.run(host='0.0.0.0', port=5000, debug=False)
   ```

   </details>

5. **运行后端服务**

   ```bash
   # 开发环境
   python app.py
   
   # 生产环境 (推荐使用 Gunicorn)
   gunicorn -w 4 -b 0.0.0.0:5000 app:app
   ```

6. **验证服务**

   ```bash
   # 测试实时行情接口
   curl "http://localhost:5000/api/quotes?symbols=sh000001"
   
   # 测试历史数据接口  
   curl "http://localhost:5000/api/history?symbol=sh000001&start_date=20240101&end_date=20240131"
   ```

#### 生产部署建议

- **使用 Nginx 反向代理**
- **配置 SSL 证书**
- **使用 systemd 管理服务**
- **配置日志轮转**
- **监控服务状态**

#### 后端特性

- ✅ **智能缓存**: 非交易时间使用缓存，减少API调用
- ✅ **自动更新**: 交易时间内自动更新ETF数据
- ✅ **支持A股和ETF**: 自动识别代码类型
- ✅ **错误处理**: 完善的错误信息返回
- 🔄 **API密钥认证**: 后续版本将支持

### 在应用中配置后端

部署好后端服务后，在应用中进行配置：

1. 打开 Finance Nexus 应用
2. 进入「设置」页面
3. 点击「后端服务」→「服务器配置」
4. 输入您的后端地址，例如：`http://your-server.com:5000`
5. API密钥暂时留空（后续版本支持）
6. 点击「保存」

### API接口说明

1. **实时行情接口**

   ```http
   GET /api/quotes?symbols=sh000001,sz399001
   ```

2. **历史数据接口**

   ```http
   GET /api/history?symbol=sh000001&start_date=20240101&end_date=20241231
   ```

详细的API规范请参考 [后端配置文档](docs/backend_config.md)

### 推荐后端

- 可以使用作者提供的示例后端实现
- 支持akshare等数据源
- 支持自定义数据提供商

## 支持平台

- ✅ iOS (主要平台)
- ✅ macOS
- 🔄 Android (计划中)

## 技术架构

- **框架**: Flutter 3.x
- **状态管理**: Riverpod
- **数据库**: SQLite (Drift ORM)
- **图表**: 自定义图表组件
- **设计**: Cupertino Design System

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
- 感谢所有为这个项目做出贡献的开发者！

