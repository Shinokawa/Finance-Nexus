import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/market_data_service.dart';
import '../widgets/net_worth_chart.dart';

/// 历史净值计算服务
class HistoricalNetWorthCalculator {
  const HistoricalNetWorthCalculator();

  /// 计算投资组合的历史净值
  Future<List<NetWorthDataPoint>> calculatePortfolioNetWorth(
    String portfolioId,
    String timeRange,
  ) async {
    final endDate = DateTime.now();
    final startDate = _getStartDate(timeRange);
    
    final dataPoints = <NetWorthDataPoint>[];
    final days = endDate.difference(startDate).inDays;
    
    // 生成每日净值数据点
    for (int i = 0; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      if (date.weekday > 5) continue; // 跳过周末
      
      // 计算该日期的净值
      final netWorth = await _calculateNetWorthForDate(portfolioId, date);
      dataPoints.add(NetWorthDataPoint(
        date: date,
        value: netWorth,
      ));
    }
    
    return dataPoints;
  }

  /// 计算账户的历史净值
  Future<List<NetWorthDataPoint>> calculateAccountNetWorth(
    String accountId,
    String timeRange,
  ) async {
    final endDate = DateTime.now();
    final startDate = _getStartDate(timeRange);
    
    final dataPoints = <NetWorthDataPoint>[];
    final days = endDate.difference(startDate).inDays;
    
    for (int i = 0; i <= days; i++) {
      final date = startDate.add(Duration(days: i));
      if (date.weekday > 5) continue; // 跳过周末
      
      final netWorth = await _calculateAccountNetWorthForDate(accountId, date);
      dataPoints.add(NetWorthDataPoint(
        date: date,
        value: netWorth,
      ));
    }
    
    return dataPoints;
  }

  /// 计算个股的历史净值（标准化到起始值）
  Future<List<NetWorthDataPoint>> calculateStockNetWorth(
    String symbol,
    String timeRange,
  ) async {
    final endDate = DateTime.now();
    final startDate = _getStartDate(timeRange);
    
    final startDateStr = _formatDateForAPI(startDate);
    final endDateStr = _formatDateForAPI(endDate);
    
    final historicalData = await MarketDataService.getHistoricalData(
      symbol: symbol,
      startDate: startDateStr,
      endDate: endDateStr,
    );
    
    if (historicalData.isEmpty) {
      return [];
    }
    
    final basePrice = historicalData.first.close;
    return historicalData.map((data) {
      final date = DateTime.parse(data.date);
      final normalizedValue = (data.close / basePrice) * 10000; // 标准化到10000起始值
      return NetWorthDataPoint(
        date: date,
        value: normalizedValue,
      );
    }).toList();
  }

  /// 根据时间范围获取起始日期
  DateTime _getStartDate(String timeRange) {
    final now = DateTime.now();
    switch (timeRange) {
      case '3M':
        return now.subtract(const Duration(days: 90));
      case '6M':
        return now.subtract(const Duration(days: 180));
      case '1Y':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 90));
    }
  }

  /// 格式化日期为API格式
  String _formatDateForAPI(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// 计算特定日期的投资组合净值
  Future<double> _calculateNetWorthForDate(String portfolioId, DateTime date) async {
    // 这里应该根据实际的历史持仓数据来计算
    // 暂时返回模拟数据
    final baseValue = 50000.0; // 基础净值
    final daysSinceStart = date.difference(DateTime(2024, 1, 1)).inDays;
    final volatility = 0.02; // 波动率
    final trend = 0.0003; // 趋势
    
    // 使用sin函数模拟市场波动，加上趋势
    final randomFactor = math.sin(daysSinceStart * 0.1) * volatility;
    final trendFactor = daysSinceStart * trend;
    
    return baseValue * (1 + trendFactor + randomFactor);
  }

  /// 计算特定日期的账户净值
  Future<double> _calculateAccountNetWorthForDate(String accountId, DateTime date) async {
    // 类似投资组合，但使用不同的参数
    final baseValue = 80000.0;
    final daysSinceStart = date.difference(DateTime(2024, 1, 1)).inDays;
    final volatility = 0.015;
    final trend = 0.0002;
    
    final randomFactor = math.sin(daysSinceStart * 0.15) * volatility;
    final trendFactor = daysSinceStart * trend;
    
    return baseValue * (1 + trendFactor + randomFactor);
  }
}

// Provider for the calculator
final historicalNetWorthCalculatorProvider = Provider<HistoricalNetWorthCalculator>((ref) {
  return const HistoricalNetWorthCalculator();
});

/// 投资组合历史净值Provider
final portfolioHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String portfolioId, String timeRange})>((ref, params) async {
  final calculator = ref.watch(historicalNetWorthCalculatorProvider);
  return calculator.calculatePortfolioNetWorth(params.portfolioId, params.timeRange);
});

/// 账户历史净值Provider  
final accountHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String accountId, String timeRange})>((ref, params) async {
  final calculator = ref.watch(historicalNetWorthCalculatorProvider);
  return calculator.calculateAccountNetWorth(params.accountId, params.timeRange);
});

/// 个股历史净值Provider
final stockHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, ({String symbol, String timeRange})>((ref, params) async {
  final calculator = ref.watch(historicalNetWorthCalculatorProvider);
  return calculator.calculateStockNetWorth(params.symbol, params.timeRange);
});

/// 总净值历史Provider（汇总所有账户和投资组合）
final totalHistoricalNetWorthProvider = FutureProvider.family<List<NetWorthDataPoint>, String>((ref, timeRange) async {
  final calculator = ref.watch(historicalNetWorthCalculatorProvider);
  // 这里需要获取所有账户和投资组合，然后汇总计算
  // 暂时返回一个示例计算
  
  final endDate = DateTime.now();
  final startDate = calculator._getStartDate(timeRange);
  final dataPoints = <NetWorthDataPoint>[];
  final days = endDate.difference(startDate).inDays;
  
  for (int i = 0; i <= days; i++) {
    final date = startDate.add(Duration(days: i));
    if (date.weekday > 5) continue; // 跳过周末
    
    // 模拟总净值计算
    final baseValue = 150000.0;
    final daysSinceStart = date.difference(DateTime(2024, 1, 1)).inDays;
    final volatility = 0.018;
    final trend = 0.00025;
    
    final randomFactor = math.sin(daysSinceStart * 0.12) * volatility;
    final trendFactor = daysSinceStart * trend;
    final netWorth = baseValue * (1 + trendFactor + randomFactor);
    
    dataPoints.add(NetWorthDataPoint(
      date: date,
      value: netWorth,
    ));
  }
  
  return dataPoints;
});