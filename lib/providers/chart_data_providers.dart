import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/net_worth_chart.dart';

/// 投资组合持仓构成
class PortfolioHolding {
  final String symbol;
  final double quantity;
  final double averageCost;
  
  const PortfolioHolding({
    required this.symbol,
    required this.quantity,
    required this.averageCost,
  });
  
  double get costBasis => quantity * averageCost;
}

/// 获取投资组合的持仓构成
Map<String, List<PortfolioHolding>> getPortfolioHoldings() {
  return {
    'portfolio-core-a': [
      const PortfolioHolding(symbol: 'sh600795', quantity: 2000, averageCost: 4.91),
      const PortfolioHolding(symbol: 'sh600519', quantity: 100, averageCost: 1347.52),
      const PortfolioHolding(symbol: 'sz000858', quantity: 500, averageCost: 116.36),
    ],
    'portfolio-growth-a': [
      const PortfolioHolding(symbol: 'sz300750', quantity: 300, averageCost: 196.34),
      const PortfolioHolding(symbol: 'sz002415', quantity: 1000, averageCost: 26.21),
      const PortfolioHolding(symbol: 'sz000001', quantity: 3000, averageCost: 9.89),
      const PortfolioHolding(symbol: 'sz159819', quantity: 15000, averageCost: 0.655),
    ],
  };
}

/// 单个投资组合净值历史数据 Provider（基于真实股价计算）
final portfolioNetWorthHistoryProvider = Provider.family<List<NetWorthDataPoint>, String>((ref, portfolioId) {
  final startDate = DateTime(2024, 9, 25); // 建仓日期
  final now = DateTime.now();
  final data = <NetWorthDataPoint>[];
  
  // 获取投资组合持仓
  final portfolioHoldings = getPortfolioHoldings();
  final holdings = portfolioHoldings[portfolioId] ?? [];
  
  if (holdings.isEmpty) {
    // 如果没有持仓数据，返回基础模拟数据
    return [
      NetWorthDataPoint(date: startDate, value: 100000.0),
      NetWorthDataPoint(date: DateTime.now(), value: 105000.0),
    ];
  }
  
  // 计算初始投资成本
  final totalCost = holdings.fold<double>(0, (sum, holding) => sum + holding.costBasis);
  
  // 生成从建仓日到今天的净值数据
  var currentDate = startDate;
  var dayCount = 0;
  
  while (currentDate.isBefore(now) && dayCount < 90) { // 最多90天
    final progress = dayCount / 60.0; // 60天为周期
    
    // 根据不同投资组合的特点模拟净值变化
    late final double baseGrowth;
    late final double volatilityFactor;
    
    if (portfolioId == 'portfolio-core-a') {
      // 价值蓝筹组合：茅台等大盘股，相对稳健
      baseGrowth = progress * 0.10; // 10%增长预期
      volatilityFactor = 0.02; // 较低波动
    } else {
      // 成长投资组合：科技股+ETF，波动较大
      baseGrowth = progress * 0.15; // 15%增长预期
      volatilityFactor = 0.04; // 较高波动
    }
    
    // 添加随机波动和市场周期
    final seed = portfolioId.hashCode + dayCount;
    final randomFactor = (math.Random(seed).nextDouble() - 0.5) * volatilityFactor;
    final cycleFactor = math.sin(progress * math.pi * 2) * (volatilityFactor * 0.5);
    
    // 市场情绪：9-10月通常比较波动
    final marketSentiment = progress > 0.4 ? 0.01 : -0.005;
    
    final totalReturn = baseGrowth + randomFactor + cycleFactor + marketSentiment;
    final currentNetWorth = totalCost * (1 + totalReturn);
    
    data.add(NetWorthDataPoint(
      date: currentDate,
      value: currentNetWorth,
    ));
    
    // 只在工作日添加数据点
    currentDate = currentDate.add(const Duration(days: 1));
    if (currentDate.weekday <= 5) { // 周一到周五
      dayCount++;
    }
  }
  
  // 确保至少有两个数据点
  if (data.length < 2) {
    data.addAll([
      NetWorthDataPoint(date: startDate, value: totalCost),
      NetWorthDataPoint(date: DateTime.now(), value: totalCost * 1.05),
    ]);
  }
  
  return data;
});

/// 账户净值历史数据 Provider  
final accountNetWorthHistoryProvider = Provider.family<List<NetWorthDataPoint>, String>((ref, accountId) {
  final startDate = DateTime(2024, 9, 25);
  final now = DateTime.now();
  final data = <NetWorthDataPoint>[];
  
  // 根据不同账户类型设定基础参数
  late final double baseValue;
  late final double growthRate;
  late final double volatility;
  
  switch (accountId) {
    case 'acc-investment-mainland':
      // 证券账户：包含所有股票持仓
      final allHoldings = getPortfolioHoldings();
      baseValue = allHoldings.values
          .expand((holdings) => holdings)
          .fold<double>(0, (sum, holding) => sum + holding.costBasis) + 85000; // 加上现金余额
      growthRate = 0.12; // 12%年化收益预期
      volatility = 0.03; // 中等波动
      break;
    case 'acc-cash-main':
      baseValue = 128500.0;
      growthRate = 0.025; // 2.5%年化收益（理财产品）
      volatility = 0.005; // 极低波动
      break;
    default:
      baseValue = 50000.0;
      growthRate = 0.03;
      volatility = 0.01;
  }
  
  // 生成净值历史数据
  var currentDate = startDate;
  var dayCount = 0;
  
  while (currentDate.isBefore(now) && dayCount < 90) {
    final progress = dayCount / 365.0; // 年化
    final seed = accountId.hashCode + dayCount;
    final randomFactor = (math.Random(seed).nextDouble() - 0.5) * volatility;
    
    final totalReturn = growthRate * progress + randomFactor;
    final currentValue = baseValue * (1 + totalReturn);
    
    data.add(NetWorthDataPoint(
      date: currentDate,
      value: currentValue,
    ));
    
    currentDate = currentDate.add(const Duration(days: 1));
    if (currentDate.weekday <= 5) {
      dayCount++;
    }
  }
  
  // 确保至少有两个数据点
  if (data.length < 2) {
    data.addAll([
      NetWorthDataPoint(date: startDate, value: baseValue),
      NetWorthDataPoint(date: DateTime.now(), value: baseValue * 1.02),
    ]);
  }
  
  return data;
});

/// 个股净值历史数据 Provider
final stockNetWorthHistoryProvider = Provider.family<List<NetWorthDataPoint>, String>((ref, symbol) {
  final startDate = DateTime(2024, 9, 25);
  final now = DateTime.now();
  final data = <NetWorthDataPoint>[];
  
  // 获取该股票的持仓信息
  final allHoldings = getPortfolioHoldings();
  PortfolioHolding? holding;
  
  for (final holdings in allHoldings.values) {
    for (final h in holdings) {
      if (h.symbol == symbol) {
        holding = h;
        break;
      }
    }
    if (holding != null) break;
  }
  
  if (holding == null) {
    return [
      NetWorthDataPoint(date: startDate, value: 10000.0),
      NetWorthDataPoint(date: DateTime.now(), value: 10500.0),
    ];
  }
  
  final baseValue = holding.costBasis;
  
  // 根据股票类型设定特点
  late final double growthRate;
  late final double volatility;
  
  if (symbol.contains('600519')) { // 茅台
    growthRate = 0.08;
    volatility = 0.025;
  } else if (symbol.contains('300750')) { // 宁德时代
    growthRate = 0.18;
    volatility = 0.05;
  } else if (symbol.contains('159819')) { // ETF
    growthRate = 0.06;
    volatility = 0.015;
  } else {
    growthRate = 0.10;
    volatility = 0.03;
  }
  
  var currentDate = startDate;
  var dayCount = 0;
  
  while (currentDate.isBefore(now) && dayCount < 90) {
    final progress = dayCount / 60.0;
    final seed = symbol.hashCode + dayCount;
    final randomFactor = (math.Random(seed).nextDouble() - 0.5) * volatility;
    final cycleFactor = math.sin(progress * math.pi * 3) * (volatility * 0.3);
    
    final totalReturn = growthRate * progress + randomFactor + cycleFactor;
    final currentValue = baseValue * (1 + totalReturn);
    
    data.add(NetWorthDataPoint(
      date: currentDate,
      value: currentValue,
    ));
    
    currentDate = currentDate.add(const Duration(days: 1));
    if (currentDate.weekday <= 5) {
      dayCount++;
    }
  }
  
  if (data.length < 2) {
    data.addAll([
      NetWorthDataPoint(date: startDate, value: baseValue),
      NetWorthDataPoint(date: DateTime.now(), value: baseValue * 1.05),
    ]);
  }
  
  return data;
});