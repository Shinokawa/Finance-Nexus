import 'package:flutter/foundation.dart';

import '../../../providers/net_worth_range_state.dart';
import '../../../widgets/net_worth_chart.dart';

/// 指标展示格式
@immutable
class AnalyticsMetric {
  const AnalyticsMetric({
    required this.label,
    required this.value,
    required this.format,
    this.change,
    this.changeFormat,
    this.hint,
  });

  final String label;
  final double value;
  final MetricFormat format;
  final double? change;
  final MetricFormat? changeFormat;
  final String? hint;
}

enum MetricFormat {
  percent,
  currency,
  decimal,
  ratio,
}

/// 通用时间序列点
@immutable
class TimeSeriesPoint {
  const TimeSeriesPoint({
    required this.date,
    required this.value,
  });

  final DateTime date;
  final double value;
}

enum MatrixType {
  covariance,
  correlation,
  dccCorrelation,
}

/// 风险矩阵数据结构
@immutable
class MatrixStats {
  const MatrixStats({
    required this.labels,
    required this.values,
    required this.min,
    required this.max,
    required this.type,
  });

  final List<String> labels;
  final List<List<double>> values;
  final double min;
  final double max;
  final MatrixType type;
}

/// 动态相关性序列
@immutable
class PairCorrelationSeries {
  const PairCorrelationSeries({
    required this.assetA,
    required this.assetB,
    required this.points,
  });

  final String assetA;
  final String assetB;
  final List<TimeSeriesPoint> points;
}

enum InsightSeverity { positive, neutral, negative }

/// 风险洞察文案
@immutable
class AnalyticsInsight {
  const AnalyticsInsight({
    required this.title,
    required this.detail,
    this.severity = InsightSeverity.neutral,
  });

  final String title;
  final String detail;
  final InsightSeverity severity;
}

/// 分析快照
@immutable
class PortfolioAnalyticsSnapshot {
  const PortfolioAnalyticsSnapshot({
    required this.range,
    required this.generatedAt,
    required this.netWorthSeries,
    required this.returnSeries,
    required this.rollingVolatility,
    required this.metrics,
    required this.covarianceMatrix,
    required this.correlationMatrix,
    required this.dccMatrix,
    required this.dccPairSeries,
    required this.insights,
  });

  final NetWorthRange range;
  final DateTime generatedAt;
  final List<NetWorthDataPoint> netWorthSeries;
  final List<TimeSeriesPoint> returnSeries;
  final List<TimeSeriesPoint> rollingVolatility;
  final List<AnalyticsMetric> metrics;
  final MatrixStats? covarianceMatrix;
  final MatrixStats? correlationMatrix;
  final MatrixStats? dccMatrix;
  final List<PairCorrelationSeries> dccPairSeries;
  final List<AnalyticsInsight> insights;

  static final empty = PortfolioAnalyticsSnapshot(
    range: NetWorthRange.lastThreeMonths,
    generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    netWorthSeries: [],
    returnSeries: [],
    rollingVolatility: [],
    metrics: [],
    covarianceMatrix: null,
    correlationMatrix: null,
    dccMatrix: null,
    dccPairSeries: [],
    insights: [],
  );
}

@immutable
class PortfolioAnalyticsPreview {
  const PortfolioAnalyticsPreview({
    required this.target,
    required this.currentValue,
    required this.changePercent,
    required this.sparkline,
  });

  final PortfolioAnalyticsTarget target;
  final double currentValue;
  final double? changePercent;
  final List<NetWorthDataPoint> sparkline;
}

enum PortfolioAnalyticsTargetType { total, portfolio }

@immutable
class PortfolioAnalyticsTarget {
  const PortfolioAnalyticsTarget.total()
      : type = PortfolioAnalyticsTargetType.total,
        id = null,
        name = '全部资产';

  const PortfolioAnalyticsTarget.portfolio({
    required this.id,
    required this.name,
  }) : type = PortfolioAnalyticsTargetType.portfolio;

  final PortfolioAnalyticsTargetType type;
  final String? id;
  final String name;

  bool get isTotal => type == PortfolioAnalyticsTargetType.total;

  @override
  bool operator ==(Object other) {
    return other is PortfolioAnalyticsTarget && other.type == type && other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, id);
}

@immutable
class SpendingCategoryBreakdown {
  const SpendingCategoryBreakdown({
    required this.category,
    required this.amount,
  });

  final String category;
  final double amount;
}

@immutable
class SpendingAnalyticsOverview {
  const SpendingAnalyticsOverview({
    required this.generatedAt,
    required this.totalExpense,
    required this.previousExpense,
    required this.dailyTrend,
    required this.topCategories,
    required this.insights,
  });

  final DateTime generatedAt;
  final double totalExpense;
  final double previousExpense;
  final List<TimeSeriesPoint> dailyTrend;
  final List<SpendingCategoryBreakdown> topCategories;
  final List<AnalyticsInsight> insights;

  double get momChange {
    if (previousExpense == 0) return totalExpense == 0 ? 0 : 1;
    return (totalExpense - previousExpense) / previousExpense;
  }
}

@immutable
class AnalyticsHomeSnapshot {
  const AnalyticsHomeSnapshot({
    required this.generatedAt,
    required this.previews,
    required this.spendingOverview,
  });

  final DateTime generatedAt;
  final List<PortfolioAnalyticsPreview> previews;
  final SpendingAnalyticsOverview? spendingOverview;

  bool get hasContent => previews.isNotEmpty || spendingOverview != null;
}
