import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../../../widgets/simple_pie_chart.dart';
import '../models/analytics_models.dart';
import '../widgets/analytics_line_chart.dart';
import '../widgets/analytics_bar_chart.dart';

class SpendingDetailView extends StatelessWidget {
  const SpendingDetailView({super.key, required this.overview});

  final SpendingAnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.background,
      context,
    );
    final primary = CupertinoDynamicColor.resolve(QHColors.primary, context);

  final trend = _resolveTrend(overview.dailyTrend);
  final trimmedTrend = trend.points;
  final coverageDays = trend.coverageDays;
    
    // 计算每日平均支出
    final dailyAverage = coverageDays > 0 
        ? overview.totalExpense / coverageDays 
        : 0.0;
    
    // 构建副标题，包含每日平均支出
    final subtitle = switch (coverageDays) {
      0 => '暂无可视化数据，先记一笔消费吧。',
      1 => '仅包含最近 1 天消费，已自动拉伸展示。',
      _ => '覆盖最近 $coverageDays 天消费走势，每日平均支出 ${_formatCurrency(dailyAverage)}',
    };

    final lineSeries = [
      AnalyticsLineSeries(
        label: '每日支出',
        color: primary,
        points: trimmedTrend,
      ),
    ];
    
    // 准备柱状图数据
    final barData = overview.monthlySummary
        .map((m) => MonthlyBarData(
              month: m.month,
              income: m.income,
              expense: m.expense,
            ))
        .toList();

    return CupertinoPageScaffold(
      backgroundColor: background,
      navigationBar: const CupertinoNavigationBar(middle: Text('支出分析')),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SpendingDetailCard(
                    child: _SummarySection(overview: overview),
                  ),
                  const SizedBox(height: 20),
                  _WeeklySpendingCard(overview: overview),
                  const SizedBox(height: 20),
                  AnalyticsLineChart(
                    title: '每日支出轨迹',
                    subtitle: subtitle,
                    series: lineSeries,
                    height: 240,
                    valueFormatter: _formatCurrency,
                  ),
                  if (overview.topCategories.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SpendingDetailCard(
                      child: _CategoryBreakdown(overview: overview),
                    ),
                    const SizedBox(height: 20),
                    _SpendingDetailCard(
                      child: _CategoryPieChart(overview: overview),
                    ),
                  ],
                  if (barData.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    AnalyticsBarChart(
                      title: '近六个月收支对比',
                      subtitle: '展示最近 6 个月的收入与支出趋势，帮助把握财务状况。',
                      data: barData,
                      height: 280,
                      valueFormatter: _formatCurrency,
                    ),
                  ],
                  if (overview.insights.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SpendingDetailCard(
                      child: _InsightList(insights: overview.insights),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.overview});

  final SpendingAnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final valueColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final change = overview.momChange;
    final changeColor = change > 0
        ? CupertinoColors.systemRed
        : change < 0
        ? CupertinoColors.systemGreen
        : label;
    
    final savingsRate = overview.savingsRate;
    final savingsColor = savingsRate >= 0.3
        ? CupertinoColors.systemGreen
        : savingsRate >= 0.1
        ? CupertinoColors.systemOrange
        : CupertinoColors.systemRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('近 30 天财务概览', style: QHTypography.footnote.copyWith(color: label)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatCurrency(overview.totalExpense),
              style: QHTypography.largeTitle.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '支出',
              style: QHTypography.body.copyWith(color: label),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 收入和储蓄率
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收入',
                    style: QHTypography.footnote.copyWith(color: label),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(overview.totalIncome),
                    style: QHTypography.title3.copyWith(
                      color: CupertinoColors.systemGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '储蓄率',
                    style: QHTypography.footnote.copyWith(color: label),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overview.totalIncome == 0 ? '--' : '${(savingsRate * 100).toStringAsFixed(1)}%',
                    style: QHTypography.title3.copyWith(
                      color: savingsColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (overview.totalIncome > 0) ...[
          const SizedBox(height: 12),
          // 储蓄率进度条
          LayoutBuilder(
            builder: (context, constraints) {
              final progressWidth = (constraints.maxWidth * savingsRate).clamp(0.0, constraints.maxWidth);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Container(color: label.withValues(alpha: 0.2)),
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: progressWidth,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      CupertinoColors.systemGreen,
                                      CupertinoColors.systemGreen.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '结余 ${_formatCurrency(overview.totalIncome - overview.totalExpense)}',
                    style: QHTypography.footnote.copyWith(color: label),
                  ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        Container(
          height: 1,
          color: CupertinoDynamicColor.resolve(CupertinoColors.separator, context),
        ),
        const SizedBox(height: 16),
        // 环比变化和最大单笔
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '环比变化',
                    style: QHTypography.footnote.copyWith(color: label),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatSignedPercent(change),
                    style: QHTypography.subheadline.copyWith(
                      color: changeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (overview.largestExpense != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最大单笔',
                      style: QHTypography.footnote.copyWith(color: label),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(overview.largestExpense!.amount),
                      style: QHTypography.subheadline.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      overview.largestExpense!.category,
                      style: QHTypography.footnote.copyWith(color: label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeeklySpendingCard extends StatelessWidget {
  const _WeeklySpendingCard({required this.overview});

  final SpendingAnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final valueColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    
    final weeklyChange = overview.weeklyChange;
    final changeColor = weeklyChange > 0
        ? CupertinoColors.systemRed
        : weeklyChange < 0
        ? CupertinoColors.systemGreen
        : labelColor;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '本周支出',
                  style: QHTypography.footnote.copyWith(color: labelColor),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(overview.weeklyExpense),
                  style: QHTypography.title1.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '较上周',
                style: QHTypography.footnote.copyWith(color: labelColor),
              ),
              const SizedBox(height: 4),
              Text(
                _formatSignedPercent(weeklyChange),
                style: QHTypography.body.copyWith(
                  color: changeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.overview});

  final SpendingAnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final titleColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '类别明细',
          style: QHTypography.subheadline.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '展示近 30 天支出占比最高的前 ${math.min(5, overview.topCategories.length)} 个类别。',
          style: QHTypography.footnote.copyWith(color: label),
        ),
        const SizedBox(height: 16),
        ...overview.topCategories.take(5).map((item) {
          final share = overview.totalExpense <= 0
              ? 0.0
              : (item.amount / overview.totalExpense)
                    .clamp(0.0, 1.0)
                    .toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _CategoryRow(
              label: item.category,
              amount: item.amount,
              share: share,
            ),
          );
        }),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.share,
  });

  final String label;
  final double amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final valueColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final subtle = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final barColor = CupertinoDynamicColor.resolve(QHColors.primary, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: QHTypography.subheadline.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatCurrency(amount),
              style: QHTypography.subheadline.copyWith(color: valueColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final progressWidth = width * share;
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: subtle.withValues(alpha: 0.2)),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(width: progressWidth, color: barColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '占比 ${(share * 100).toStringAsFixed(1)}%',
          style: QHTypography.footnote.copyWith(color: subtle),
        ),
      ],
    );
  }
}

class _SpendingDetailCard extends StatelessWidget {
  const _SpendingDetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: child,
    );
  }
}

class _InsightList extends StatelessWidget {
  const _InsightList({required this.insights});

  final List<AnalyticsInsight> insights;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final titleColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '提示与建议',
          style: QHTypography.subheadline.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) {
          final color = switch (insight.severity) {
            InsightSeverity.positive => CupertinoColors.systemGreen,
            InsightSeverity.negative => CupertinoColors.systemRed,
            InsightSeverity.neutral => titleColor,
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: QHTypography.subheadline.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  insight.detail,
                  style: QHTypography.footnote.copyWith(
                    color: label,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

({List<TimeSeriesPoint> points, int coverageDays})
    _resolveTrend(List<TimeSeriesPoint> source) {
  if (source.isEmpty) {
    return (points: const [], coverageDays: 0);
  }
  final sorted = [...source]..sort((a, b) => a.date.compareTo(b.date));
  final limit = math.min(sorted.length, 30);
  final trimmed = sorted.sublist(sorted.length - limit);
  final coverage = trimmed.length;
  if (trimmed.length == 1) {
    final point = trimmed.first;
    return (
      points: [
      point,
      TimeSeriesPoint(
        date: point.date.add(const Duration(days: 1)),
        value: point.value,
      ),
      ],
      coverageDays: coverage,
    );
  }
  return (points: trimmed, coverageDays: coverage);
}

String _formatCurrency(double value) {
  final isNegative = value < 0;
  final absValue = value.abs();
  String formatted;
  if (absValue >= 100000000) {
    formatted = '${(absValue / 100000000).toStringAsFixed(2)}亿';
  } else if (absValue >= 10000) {
    formatted = '${(absValue / 10000).toStringAsFixed(2)}万';
  } else {
    formatted = absValue.toStringAsFixed(2);
  }
  return isNegative ? '-¥$formatted' : '¥$formatted';
}

String _formatSignedPercent(double? value) {
  if (value == null) {
    return '--';
  }
  final percent = (value * 100).abs().toStringAsFixed(1);
  if (value == 0) {
    return '$percent%';
  }
  final sign = value > 0 ? '+' : '-';
  return '$sign$percent%';
}

class _CategoryPieChart extends StatelessWidget {
  const _CategoryPieChart({required this.overview});

  final SpendingAnalyticsOverview overview;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    // 定义颜色调色板
    const colors = [
      CupertinoColors.systemBlue,
      CupertinoColors.systemGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemRed,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPink,
      CupertinoColors.systemYellow,
      CupertinoColors.systemGrey,
    ];

    // 准备饼图数据，显示前5个类别，其余归为"其他"
    final pieData = <PieChartData>[];
    final categories = overview.topCategories;
    
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = overview.totalExpense;
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    // 取前5个类别
    final topCategories = categories.take(5).toList();
    double otherTotal = 0;
    
    // 计算其他类别的总和
    if (categories.length > 5) {
      otherTotal = categories.skip(5).fold<double>(0, (sum, cat) => sum + cat.amount);
    }

    // 添加主要类别到饼图数据
    for (int i = 0; i < topCategories.length; i++) {
      final category = topCategories[i];
      pieData.add(PieChartData(
        label: category.category,
        value: category.amount,
        color: CupertinoDynamicColor.resolve(colors[i % colors.length], context),
      ));
    }

    // 如果有其他类别，添加到饼图
    if (otherTotal > 0) {
      pieData.add(PieChartData(
        label: '其他',
        value: otherTotal,
        color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '支出类别分布',
          style: QHTypography.subheadline.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '可视化展示各类别支出占比，帮助分析消费结构。',
          style: QHTypography.footnote.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 饼图
            SimplePieChart(
              data: pieData,
              size: 160,
            ),
            const SizedBox(width: 24),
            // 图例
            Expanded(
              child: PieChartLegend(
                data: pieData,
                showPercentages: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
