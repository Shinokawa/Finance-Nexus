### **个人量化金融中枢 - 应用设计与开发规约 (v2.0)**

#### **1. 项目愿景与核心原则**

*   **愿景**: 打造一个以个人为中心的量化金融枢纽，实现全资产聚合、深度个性化分析和财富增长的可视化追踪。
*   **核心原则**:
    *   **数据驱动**: 所有视图和分析都基于精准、干净的底层数据。
    *   **隐私优先**: 所有数据本地存储，手动录入，不窥探用户隐私。
    *   **高度定制**: 允许用户以最符合自己认知的方式来组织和审视资产。
    *   **直观可视**: 复杂的数据通过简洁、清晰的图表呈现。

#### **2. 核心数据模型 (The Foundation)**

这是整个App的基石，建议使用`UUID`作为各项的主键`id`以便于同步和管理。

**2.1 `Account` (账户模型)**
*   **描述**: 代表真实的资金容器。
*   **字段**:
    *   `id`: `UUID` (主键)
    *   `name`: `String` (例如: "招商证券户", "建设银行储蓄卡")
    *   `type`: `Enum` (枚举: `investment`, `cash`, `liability`)
    *   `currency`: `Enum` (初期固定为 `cny`)
    *   `balance`: `Double` (对于`cash`和`liability`账户，这是核心余额)
    *   `createdAt`: `Date` (创建时间)

**2.2 `Portfolio` (投资组合模型)**
*   **描述**: 逻辑上的资产组合，用于分类和策略管理，可以跨越多个真实账户。
*   **字段**:
    *   `id`: `UUID` (主键)
    *   `name`: `String` (例如: "我的主动投资", "妈妈的稳健组合", "长期收息股")
    *   `description`: `String` (可选备注)
    *   `createdAt`: `Date`

**2.3 `Holding` (持仓模型)**
*   **描述**: 代表一项具体的投资持仓（股票/ETF）。
*   **字段**:
    *   `id`: `UUID` (主键)
    *   `symbol`: `String` (标准代码, 如: "sh600519", "sz159819")
    *   `quantity`: `Double` (持有数量)
    *   `averageCost`: `Double` (平均持仓成本)
    *   `accountId`: `UUID` (外键, 指向其所在的真实`Account`)
    *   `portfolioId`: `UUID` (外键, 指向其归属的`Portfolio`)

**2.4 `Transaction` (交易/流水模型)**
*   **描述**: 记录所有资金流动的原子操作。
*   **字段**:
    *   `id`: `UUID` (主键)
    *   `amount`: `Double` (金额, 恒为正数)
    *   `date`: `Date` (发生日期)
    *   `type`: `Enum` (枚举: `expense`, `income`, `transfer`, `buy`, `sell`)
    *   `category`: `String` (例如: "餐饮", "工资", "分红")
    *   `notes`: `String` (可选备注)
    *   `fromAccountId`: `UUID?` (可选, `expense`/`transfer`/`buy`的来源账户)
    *   `toAccountId`: `UUID?` (可选, `income`/`transfer`/`sell`的目标账户)
    *   `relatedHoldingId`: `UUID?` (可选, `buy`/`sell`操作关联的`Holding`)

---

#### **3. 模块功能规约 (Feature Specification)**

**模块一：账户与组合管理 (Account & Portfolio Management)**

*   **功能1.1: 创建/编辑账户**
    *   **UI**: 表单页面，包含`name`, `type`, `balance`等输入框。
    *   **逻辑**: 创建或更新一个`Account`实例并存入本地数据库。
*   **功能1.2: 创建/编辑投资组合**
    *   **UI**: 表单页面，包含`name`, `description`输入框。
    *   **逻辑**: 创建或更新一个`Portfolio`实例。
*   **功能1.3: 账户/组合列表**
    *   **UI**: 一个页面，用两个Tab切换显示“账户列表”和“组合列表”。
    *   **账户列表**: 按`type`分组 (`投资账户`, `现金账户`, `负债账户`)。投资账户的余额实时计算其下所有`Holding`的总市值。
    *   **组合列表**: 显示所有创建的`Portfolio`及其当前总市值。

**模块二：资产看板 (Asset Dashboard)**

*   **功能2.1: 核心指标卡片**
    *   **UI**: 页面顶部最显眼位置。
    *   **总净资产**: 大号字体。
        *   **计算逻辑**: `SUM(现金账户 balance) - SUM(负债账户 balance) + SUM(所有Holding的实时市值)`。
    *   **今日总盈亏**: 小号字体，红绿色区分。
        *   **计算逻辑**: `SUM(所有Holding的今日盈亏)`。
*   **功能2.2: 资产构成**
    *   **UI**: 饼图或环形图。提供一个切换器，可按“**资产大类**”(股票、基金、现金)或按“**投资组合**”来展示分布。
*   **功能2.3: 持仓列表**
    *   **UI**: 列表。顶部提供一个按`Portfolio`筛选的下拉菜单 (默认“全部组合”)。
    *   **列表项显示字段**:
        *   名称/代码
        *   持仓数量 / **持仓市值**
        *   成本价 / **累计盈亏 (及盈亏率%)**
        *   当前价 / **今日盈亏**
        *   **市值占比** (该持仓市值 / 当前筛选组合的总市值)
    *   **API调用**:
        1.  页面加载/刷新时，从本地数据库读取当前筛选器下的所有`Holding`。
        2.  提取所有不重复的`symbol`。
        3.  将`symbol`用逗号拼接，调用你的后端API: `GET /api/quotes?symbols=...`
        4.  收到响应后，将实时价格数据更新到UI状态中用于计算。对于返回`error`的`symbol`，在UI上标记“行情获取失败”。
    *   **交互**:
        *   支持下拉刷新。
        *   设置一个定时器(e.g., 15秒)自动调用API刷新数据。
        *   点击每一行持仓，可以进入“持仓详情页”，展示更详细的信息和历史交易记录。

**模块三：手动记账 (Manual Logging)**

*   **功能3.1: 添加初始持仓**
    *   **入口**: 在某个`Portfolio`详情页或`投资账户`详情页。
    *   **UI**: 表单，输入`股票代码`, `持仓数量`, `平均成本`。并选择此持仓存放在哪个`投资账户` (`accountId`)，归属于哪个`投资组合` (`portfolioId`)。
    *   **逻辑**: 创建一个新的`Holding`对象并保存。此功能主要用于初始化。
*   **功能3.2: 记录投资交易 (买入/卖出)**
    *   **入口**: 在“持仓列表”中，对某个`Holding`左滑或点击后出现“交易”按钮。
    *   **UI**: 弹出窗口，选择“买入”或“卖出”。输入`成交数量`, `成交价格`。
    *   **逻辑**:
        1.  创建一个`Transaction`，类型为`buy`或`sell`，并关联`relatedHoldingId`。
        2.  **更新`Holding`**:
            *   **买入**: 重新计算`averageCost` -> `(原总成本 + 本次买入金额) / (原数量 + 本次买入数量)`。更新`quantity`。
            *   **卖出**: `averageCost`不变。更新`quantity`。
        3.  **更新`Account`**: 根据交易金额，更新关联的现金账户的`balance`。
*   **功能3.3: 记录普通流水 (收/支/转)**
    *   **UI**: 与你设计的“记一笔”悬浮按钮完全一致。
    *   **逻辑**:
        *   **支出**: 创建`expense`类型的`Transaction`，扣减`fromAccountId`的`balance`。
        *   **收入**: 创建`income`类型的`Transaction`，增加`toAccountId`的`balance`。
        *   **转账**: 创建`transfer`类型的`Transaction`，同时扣减`fromAccountId`并增加`toAccountId`的`balance`。

---

#### **4. MVP开发路线图 (Refined)**

1.  **Phase 1: 模型与数据库 (1-2天)**
    *   在代码中定义`Account`, `Portfolio`, `Holding`, `Transaction`四个核心模型。
    *   配置好本地数据库 (如Flutter的Drift/sqflite, Swift的SwiftData/CoreData) 并创建对应的表。

2.  **Phase 2: 基础创建功能 (2-3天)**
    *   实现“账户与组合管理”模块的UI，允许用户创建和查看`Account`和`Portfolio`。
    *   实现“添加初始持仓”的功能，让用户可以录入最基础的资产数据。

3.  **Phase 3: 核心看板与API对接 (3-5天)**
    *   搭建“资产看板”的UI框架。
    *   编写网络请求层，实现与你的后端API的对接和数据解析。
    *   实现持仓列表的实时数据计算和展示逻辑。这是最有挑战性也最有成就感的一步。
    *   完成核心指标卡片和资产构成图的计算与展示。

4.  **Phase 4: 让数据流动起来 (3-4天)**
    *   实现“记录投资交易 (买入/卖出)”的完整流程。
    *   实现“记录普通流水 (收/支/转)”的完整流程。
    *   确保每一次操作都能正确地更新底层的`Holding`和`Account`数据，并在UI上得到响应。

5.  **Phase 5: 分析与图表 (后续迭代)**
    *   当MVP核心功能稳定后，开始开发“分析与图表”模块。
    *   首先实现基于`Transaction`数据的收支分析。
    *   然后实现“净资产曲线图”，这需要一个每日快照的逻辑（可以在每次App启动时检查，如果当天没有快照，就计算一次并存储）。

这是我搭建的后端的API文档：
个人量化金融中枢 - 后端API使用文档 (v1.0)
概述
本API旨在为您的移动端应用提供中国A股市场股票和ETF基金的准实时行情数据。它具备智能路由和混合缓存机制，以确保在不同时间段都能提供高效、稳定的数据服务。
API 端点 (Endpoint)
URL
http://74.226.178.107:57777/api/quotes
请求方法 (Method)
GET
请求参数 (Parameters)
参数名	类型	是否必需	描述
symbols	string	是	一个或多个品种的代码，代码之间用英文逗号 (,) 隔开。代码可以包含sh/sz前缀，也可以不包含，后端会自动处理。
响应格式 (Response Format)
API的返回结果是一个JSON对象。这个对象的键 (Key) 是您请求的原始品种代码，值 (Value) 是该品种的查询结果。
成功的响应结构
对于每一个成功获取数据的品种，其值的结构如下：
code
JSON

{
  "status": "success",
  "data": { ... }
}
* status: 恒为 "success"。
* data: 一个包含详细行情数据的JSON对象。请注意：股票和ETF的data对象字段略有不同。
    * 股票 data 示例字段: {"最新": 4.99, "涨跌": -0.04, "昨收": 5.03, "buy_1": 4.98, ...}
    * ETF data 示例字段: {"最新价": 4.695, "涨跌幅": 0.69, "名称": "沪深300ETF", "IOPV实时估值": 4.6951, ...}
失败的响应结构
对于查询失败的品种（例如代码错误），其值的结构如下：
code
JSON

{
  "status": "error",
  "message": "具体的错误信息描述"
}
* status: 恒为 "error"。
* message: 一段描述错误原因的字符串。

使用示例
1. 查询单个股票（国电电力）
code
Code

curl "http://74.226.178.107:57777/api/quotes?symbols=sh600795"
2. 查询单个ETF（沪深300ETF）
code
Code

curl "http://74.226.178.107:57777/api/quotes?symbols=510300"
3. 查询一个混合列表（最常用）
code
Code

curl "http://74.226.178.107:57777/api/quotes?symbols=sh600795,sh510300,sz159819"
4. 查询包含无效代码的列表
code
Code

curl "http://74.226.178.107:57777/api/quotes?symbols=sh600795,invalid_code"
预期返回: sh600795 会成功，invalid_code 会返回一个error状态。


现在开始编码吧，我们一步一步构建这个应用
测试环境是iOS模拟器