import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../design/design_system.dart';
import '../../../widgets/simple_pie_chart.dart';
import '../models/analytics_models.dart';
import '../widgets/analytics_line_chart.dart';

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
    final subtitle = switch (coverageDays) {
      0 => '暂无可视化数据，先记一笔消费吧。',
      1 => '仅包含最近 1 天消费，已自动拉伸展示。',
      _ => '覆盖最近 $coverageDays 天消费走势，可在 30 天内自适应展示。',
    };

    final lineSeries = [
      AnalyticsLineSeries(
        label: '每日支出',
        color: primary,
        points: trimmedTrend,
      ),
    ];

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('近 30 天累计支出', style: QHTypography.footnote.copyWith(color: label)),
        const SizedBox(height: 8),
        Text(
          _formatCurrency(overview.totalExpense),
          style: QHTypography.largeTitle.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '上一周期（前 30 天）',
                    style: QHTypography.footnote.copyWith(color: label),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(overview.previousExpense),
                    style: QHTypography.subheadline.copyWith(color: valueColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '环比变化',
                  style: QHTypography.footnote.copyWith(color: label),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatSignedPercent(change),
                  style: QHTypography.title3.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
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
          '展示近 30 天支出占比最高的前 ${overview.topCategories.length} 个类别。',
          style: QHTypography.footnote.copyWith(color: label),
        ),
        const SizedBox(height: 16),
        ...overview.topCategories.map((item) {
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

    // 准备饼图数据，只取前8个类别，其余归为"其他"
    final pieData = <PieChartData>[];
    final categories = overview.topCategories;
    
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = overview.totalExpense;
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    // 取前7个类别
    final topCategories = categories.take(7).toList();
    double otherTotal = 0;
    
    // 计算其他类别的总和
    if (categories.length > 7) {
      otherTotal = categories.skip(7).fold<double>(0, (sum, cat) => sum + cat.amount);
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
