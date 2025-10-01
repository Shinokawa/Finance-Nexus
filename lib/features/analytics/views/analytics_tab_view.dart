import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design_system.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../providers/net_worth_range_state.dart';
import '../../../providers/repository_providers.dart';
import '../../../widgets/net_worth_chart.dart';
import '../../portfolios/views/portfolio_detail_page.dart';
import '../models/analytics_models.dart';
import '../providers/portfolio_analytics_provider.dart';
import '../widgets/analytics_heatmap.dart';
import '../widgets/analytics_line_chart.dart';
import '../widgets/analytics_metric_grid.dart';
import '../widgets/analytics_contribution_cards.dart';
import '../widgets/analytics_forecast_chart.dart';
import 'spending_detail_view.dart';

class AnalyticsTabView extends ConsumerWidget {
  const AnalyticsTabView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.background,
      context,
    );
    final range = ref.watch(netWorthRangeProvider);
    final settings = ref.watch(appSettingsProvider);
    final selectedTarget = ref.watch(selectedAnalyticsTargetProvider);
    final homeAsync = ref.watch(analyticsHomeSnapshotProvider(range));
    final snapshotAsync = ref.watch(
      portfolioAnalyticsSnapshotProvider((
        range: range,
        target: selectedTarget,
      )),
    );

    Future<void> handleRefresh() async {
      final currentTarget = ref.read(selectedAnalyticsTargetProvider);
      final futures = [
        ref.refresh(
          portfolioAnalyticsSnapshotProvider((
            range: range,
            target: currentTarget,
          )).future,
        ),
        ref.refresh(analyticsHomeSnapshotProvider(range).future),
      ];
      await Future.wait(futures);
    }

    return CupertinoPageScaffold(
      backgroundColor: background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('分析')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '分析区间',
                        style: QHTypography.footnote.copyWith(
                          color: CupertinoDynamicColor.resolve(
                            CupertinoColors.secondaryLabel,
                            context,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _RangeSelector(
                            range: range,
                            onChanged: (value) {
                              if (value != null) {
                                ref
                                        .read(netWorthRangeProvider.notifier)
                                        .state =
                                    value;
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!settings.analyticsAutoRefresh) ...[
                    _ManualRefreshBanner(onRefresh: handleRefresh),
                    const SizedBox(height: 16),
                  ],
                  // 支出洞察部分独立显示，不依赖后端
                  homeAsync.when(
                    data: (home) => _AnalyticsHomeSection(
                      snapshot: home,
                      selected: selectedTarget,
                      range: range,
                      onSelect: (target) {
                        ref
                                .read(
                                  selectedAnalyticsTargetProvider.notifier,
                                )
                                .state =
                            target;
                      },
                    ),
                    loading: () => const _HomeLoadingPlaceholder(),
                    error: (error, stack) =>
                        _SectionCard(child: _HomeErrorState(error: error)),
                  ),
                  const SizedBox(height: 24),
                  // 组合分析部分，依赖后端行情数据
                  snapshotAsync.when(
                    data: (snapshot) => _AnalyticsBody(snapshot: snapshot, target: selectedTarget),
                    loading: () => const _LoadingPlaceholder(),
                    error: (error, stack) => _ErrorState(error: error),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<AnalyticsLineSeries> _buildPairSeries(
  BuildContext context,
  List<PairCorrelationSeries> pairs,
) {
  const palette = [
    CupertinoColors.activeBlue,
    CupertinoColors.systemGreen,
    CupertinoColors.systemOrange,
    CupertinoColors.systemPurple,
    CupertinoColors.systemRed,
  ];
  return [
    for (var i = 0; i < pairs.length; i++)
      AnalyticsLineSeries(
        label: '${pairs[i].assetA} ↔ ${pairs[i].assetB}',
        color: CupertinoDynamicColor.resolve(
          palette[i % palette.length],
          context,
        ),
        points: pairs[i].points,
      ),
  ];
}

String _rangeLabel(NetWorthRange range) {
  return switch (range) {
    NetWorthRange.lastThreeMonths => '近 3 个月',
    NetWorthRange.lastSixMonths => '近 6 个月',
    NetWorthRange.lastYear => '近 12 个月',
  };
}

String _formatTimestamp(DateTime time) {
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.snapshot, required this.target});

  final PortfolioAnalyticsSnapshot snapshot;
  final PortfolioAnalyticsTarget target;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final title = target.isTotal ? '组合深度分析' : '${target.name} 深度分析';
    final sections = <Widget>[
      Text(
        title,
        style: QHTypography.title3.copyWith(
          color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '观察区间：${_rangeLabel(snapshot.range)} · 生成于 ${_formatTimestamp(snapshot.generatedAt)}',
        style: QHTypography.footnote.copyWith(color: label),
      ),
      const SizedBox(height: 16),
      AnalyticsMetricGrid(metrics: snapshot.metrics),
      const SizedBox(height: 20),
      _SectionCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: NetWorthChart(
          netWorthHistory: snapshot.netWorthSeries,
          showTimeSelector: false,
          title: '组合净值曲线',
        ),
      ),
    ];

    final forecast = snapshot.forecast;
    if (forecast != null && forecast.hasData) {
      sections.addAll([
        const SizedBox(height: 20),
        AnalyticsForecastChart(forecast: forecast),
      ]);
    }

    if (snapshot.rollingVolatility.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 20),
        AnalyticsLineChart(
          title: '30 日滚动波动率',
          subtitle: '已年化，越高代表风险越大',
          series: [
            AnalyticsLineSeries(
              label: '年化波动率',
              color: CupertinoDynamicColor.resolve(QHColors.primary, context),
              points: snapshot.rollingVolatility,
            ),
          ],
          valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
        ),
      ]);
    }

    final attribution = snapshot.attribution;
    if (attribution != null && attribution.entries.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 20),
        _SectionCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: ReturnAttributionCard(attribution: attribution),
        ),
      ]);
    }

    final riskContributions = snapshot.riskContributions;
    if (riskContributions.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 20),
        _SectionCard(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: RiskContributionCard(contributions: riskContributions),
        ),
      ]);
    }

    if (snapshot.covarianceMatrix != null) {
      sections.addAll([
        const SizedBox(height: 20),
        AnalyticsHeatmap(
          matrix: snapshot.covarianceMatrix!,
          title: '协方差矩阵',
          subtitle: '数值单位已自动缩放，观察收益率之间的波动共振程度',
        ),
      ]);
    }

    if (snapshot.correlationMatrix != null) {
      sections.addAll([
        const SizedBox(height: 20),
        AnalyticsHeatmap(
          matrix: snapshot.correlationMatrix!,
          title: '静态相关性矩阵',
          subtitle: '反映主要持仓之间的历史联动程度',
        ),
      ]);
    }

    if (snapshot.dccMatrix != null) {
      sections.addAll([
        const SizedBox(height: 20),
        AnalyticsHeatmap(
          matrix: snapshot.dccMatrix!,
          title: 'DCC-GARCH 即时相关性',
          subtitle: '动态相关性捕捉市场结构性变化，颜色越深联动越强',
        ),
      ]);
    }

    if (snapshot.dccPairSeries.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 20),
        AnalyticsLineChart(
          height: 240,
          title: '核心资产动态相关性轨迹',
          subtitle: 'DCC-GARCH 输出的时间序列，监测联动趋势',
          series: _buildPairSeries(context, snapshot.dccPairSeries),
          valueFormatter: (value) => '${(value * 100).toStringAsFixed(0)}%',
        ),
      ]);
    }

    if (snapshot.insights.isNotEmpty) {
      sections.addAll([
        const SizedBox(height: 20),
        _SectionCard(child: _InsightList(insights: snapshot.insights)),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }
}

class _AnalyticsHomeSection extends ConsumerWidget {
  const _AnalyticsHomeSection({
    required this.snapshot,
    required this.selected,
    required this.range,
    required this.onSelect,
  });

  final AnalyticsHomeSnapshot snapshot;
  final PortfolioAnalyticsTarget selected;
  final NetWorthRange range;
  final ValueChanged<PortfolioAnalyticsTarget> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    Future<void> handleOpenDetail(PortfolioAnalyticsTarget target) async {
      if (target.isTotal) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('全部资产概览'),
            content: const Text('总资产详情请前往仪表盘查看资产分布与净值走势。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('好的'),
              ),
            ],
          ),
        );
        return;
      }

      final repository = ref.read(portfolioRepositoryProvider);
      final portfolioId = target.id;
      if (portfolioId == null) {
        return;
      }
      final portfolio = await repository.getPortfolioById(portfolioId);
      if (!context.mounted) {
        return;
      }
      if (portfolio == null) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('未找到组合'),
            content: const Text('该组合似乎已被删除，刷新后再试一次。'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => PortfolioDetailPage(portfolio: portfolio),
        ),
      );
    }

    if (snapshot.previews.isNotEmpty) {
      children.addAll([
        Text(
          '资产概览',
          style: QHTypography.title3.copyWith(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '快速浏览各组合表现，点击切换深入分析对象。',
          style: QHTypography.footnote.copyWith(color: label),
        ),
        const SizedBox(height: 12),
        ScrollConfiguration(
          behavior: const _NoScrollbarBehavior(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final preview in snapshot.previews)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _PortfolioPreviewCard(
                      preview: preview,
                      selected: preview.target == selected,
                      onTap: () => onSelect(preview.target),
                      onOpenDetail: () => handleOpenDetail(preview.target),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]);
    }

    if (snapshot.spendingOverview != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 24));
      }
      children.addAll([
        Text(
          '支出洞察',
          style: QHTypography.title3.copyWith(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          snapshot.spendingOverview == null
              ? '暂未获取到支出趋势，记账后即可查看。'
              : _spendingSubtitle(snapshot.spendingOverview!),
          style: QHTypography.footnote.copyWith(color: label),
        ),
        const SizedBox(height: 12),
        _SpendingOverviewCard(overview: snapshot.spendingOverview!),
      ]);
    } else {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 24));
      }
      children.add(const _SpendingEmptyCard());
    }

    if (children.isEmpty) {
      return _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '暂无可用数据',
              style: QHTypography.subheadline.copyWith(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加持仓或记账后即可查看资产与支出分析。',
              style: QHTypography.footnote.copyWith(color: label),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

String _spendingSubtitle(SpendingAnalyticsOverview overview) {
  final coverage = overview.dailyTrend.isEmpty
      ? 0
      : math.min(overview.dailyTrend.length, 30);
  if (coverage == 0) {
    return '暂无最近支出数据，点击查看详情。';
  }
  if (coverage == 1) {
    return '仅收集到最近 1 天支出，点击查看原始流水。';
  }
  return '追踪最近 $coverage 天支出趋势与类别占比，及时发现预算风险。';
}

class _PortfolioPreviewCard extends StatelessWidget {
  const _PortfolioPreviewCard({
    required this.preview,
    required this.selected,
    required this.onTap,
    this.onOpenDetail,
  });

  final PortfolioAnalyticsPreview preview;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final base = CupertinoDynamicColor.resolve(
      QHColors.cardBackground,
      context,
    );
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final change = preview.changePercent;
    final changeColor = change == null
        ? label
        : change >= 0
        ? CupertinoColors.systemGreen
        : CupertinoColors.systemRed;
    final borderColor = selected
        ? CupertinoDynamicColor.resolve(
            QHColors.primary,
            context,
          ).withValues(alpha: 0.45)
        : CupertinoColors.separator.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
          border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: CupertinoDynamicColor.resolve(
                      QHColors.primary,
                      context,
                    ).withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              preview.target.name,
              style: QHTypography.subheadline.copyWith(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatCurrency(preview.currentValue),
              style: QHTypography.title3.copyWith(
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              change == null ? '暂无对比数据' : _formatSignedPercent(change),
              style: QHTypography.footnote.copyWith(color: changeColor),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenDetail,
              child: Row(
                children: [
                  Text(
                    '查看组合详情',
                    style: QHTypography.footnote.copyWith(
                      color: label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: label,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingOverviewCard extends StatelessWidget {
  const _SpendingOverviewCard({required this.overview});

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
    final topCategories = overview.topCategories
        .take(2)
        .toList(growable: false);

    void handleTap() {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => SpendingDetailView(overview: overview),
        ),
      );
    }

    return _SectionCard(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: handleTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '近 30 天累计支出',
                        style: QHTypography.footnote.copyWith(color: label),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatCurrency(overview.totalExpense),
                        style: QHTypography.title3.copyWith(
                          color: valueColor,
                          fontWeight: FontWeight.w700,
                        ),
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
                    const SizedBox(height: 6),
                    Text(
                      _formatSignedPercent(change),
                      style: QHTypography.subheadline.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (topCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '主要支出类别',
                style: QHTypography.subheadline.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final category in topCategories)
                    _SpendingCategoryChip(
                      label: category.category,
                      amount: category.amount,
                      share: overview.totalExpense <= 0
                          ? 0
                          : (category.amount / overview.totalExpense).clamp(
                              0.0,
                              1.0,
                            ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '查看完整支出分析',
                  style: QHTypography.footnote.copyWith(
                    color: label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(CupertinoIcons.chevron_forward, size: 18, color: label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingCategoryChip extends StatelessWidget {
  const _SpendingCategoryChip({
    required this.label,
    required this.amount,
    required this.share,
  });

  final String label;
  final double amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.groupedBackground,
      context,
    );
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final subtle = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final normalizedShare = share.isNaN
        ? 0.0
        : share.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      constraints: const BoxConstraints(minWidth: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: QHTypography.footnote.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(amount),
            style: QHTypography.footnote.copyWith(color: labelColor),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final progressWidth = width * normalizedShare;
              final barColor = CupertinoDynamicColor.resolve(
                QHColors.primary,
                context,
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: subtle.withValues(alpha: 0.18)),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: progressWidth,
                            color: barColor,
                          ),
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
            '占比 ${(normalizedShare * 100).toStringAsFixed(0)}%',
            style: QHTypography.footnote.copyWith(
              color: subtle,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpendingEmptyCard extends StatelessWidget {
  const _SpendingEmptyCard();

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '支出洞察',
            style: QHTypography.subheadline.copyWith(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.label,
                context,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '暂未检测到最近 30 天的支出记录，去流水页添加一笔消费即可看到趋势分析。',
            style: QHTypography.footnote.copyWith(color: label),
          ),
        ],
      ),
    );
  }
}

class _HomeLoadingPlaceholder extends StatelessWidget {
  const _HomeLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final shimmer = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGrey5,
      context,
    );
    return SizedBox(
      height: 140,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: shimmer,
                borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          CupertinoIcons.chart_pie,
          color: CupertinoColors.systemRed,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          '概览加载失败',
          style: QHTypography.subheadline.copyWith(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          error.toString(),
          style: QHTypography.footnote.copyWith(color: label),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
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

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final NetWorthRange range;
  final ValueChanged<NetWorthRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<NetWorthRange>(
      groupValue: range,
      backgroundColor: CupertinoDynamicColor.resolve(
        QHColors.groupedBackground,
        context,
      ),
      thumbColor: CupertinoDynamicColor.resolve(
        QHColors.primary,
        context,
      ).withValues(alpha: 0.2),
      children: {
        NetWorthRange.lastThreeMonths: Text(
          '3M',
          style: _labelStyle(context, range == NetWorthRange.lastThreeMonths),
        ),
        NetWorthRange.lastSixMonths: Text(
          '6M',
          style: _labelStyle(context, range == NetWorthRange.lastSixMonths),
        ),
        NetWorthRange.lastYear: Text(
          '1Y',
          style: _labelStyle(context, range == NetWorthRange.lastYear),
        ),
      },
      onValueChanged: onChanged,
    );
  }

  TextStyle _labelStyle(BuildContext context, bool selected) {
    final base = QHTypography.footnote.copyWith(fontWeight: FontWeight.w600);
    final color = selected
        ? CupertinoDynamicColor.resolve(QHColors.primary, context)
        : CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel,
            context,
          );
    return base.copyWith(color: color);
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
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...insights.map((insight) {
          final color = switch (insight.severity) {
            InsightSeverity.positive => CupertinoColors.systemGreen,
            InsightSeverity.negative => CupertinoColors.systemRed,
            InsightSeverity.neutral => CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight.title,
                        style: QHTypography.subheadline.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(QHColors.cardBackground, context),
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _ManualRefreshBanner extends StatelessWidget {
  const _ManualRefreshBanner({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      QHColors.cardBackground,
      context,
    );
    final secondaryLabel = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自动刷新已关闭',
            style: QHTypography.subheadline.copyWith(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.label,
                context,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '点击下方“刷新分析”以手动更新统计数据。',
            style: QHTypography.footnote.copyWith(color: secondaryLabel),
          ),
          const SizedBox(height: 12),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            onPressed: onRefresh,
            child: const Text('刷新分析'),
          ),
        ],
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final shimmerColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemGrey5,
      context,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 20),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(QHSpacing.cornerRadius),
            ),
            child: const Center(child: CupertinoActivityIndicator(radius: 14)),
          ),
        );
      }),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final label = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    return _SectionCard(
      child: Column(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemRed,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            '分析数据加载失败',
            style: QHTypography.subheadline.copyWith(
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.label,
                context,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: QHTypography.footnote.copyWith(color: label),
          ),
        ],
      ),
    );
  }
}
