import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../../providers/repository_providers.dart';
import '../../../providers/historical_net_worth_providers.dart';
import '../../../widgets/net_worth_chart.dart';
import '../../../widgets/simple_pie_chart.dart';
import '../../dashboard/models/holding_position.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../dashboard/providers/holding_positions_provider.dart';
import '../providers/portfolio_detail_providers.dart';
import 'holding_form_page.dart';
import 'trade_form_page.dart';

class PortfolioDetailPage extends ConsumerStatefulWidget {
  const PortfolioDetailPage({
    super.key,
    required this.portfolio,
  });

  final Portfolio portfolio;

  @override
  ConsumerState<PortfolioDetailPage> createState() => _PortfolioDetailPageState();
}

class _PortfolioDetailPageState extends ConsumerState<PortfolioDetailPage> {
  @override
  Widget build(BuildContext context) {
    final holdingsAsync = ref.watch(portfolioHoldingsProvider(widget.portfolio.id));
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.portfolio.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showAddHoldingPage(),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: holdingsAsync.when(
        data: (holdings) => _buildPortfolioContent(dashboardAsync, holdings),
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, stack) => _ErrorView(message: error.toString()),
      ),
    );
  }

  Widget _buildPortfolioContent(AsyncValue<DashboardData> dashboardAsync, List<Holding> holdings) {
    final positionsByHoldingId = {
      for (final position in dashboardAsync.valueOrNull
              ?.portfolioSnapshots[widget.portfolio.id]
              ?.positions ?? const <HoldingPosition>[])
        position.holding.id: position,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPortfolioSummaryCard(dashboardAsync),
        const SizedBox(height: 16),
        _buildAnalyticsSection(dashboardAsync),
        const SizedBox(height: 16),
        Text(
          '持仓列表',
          style: QHTypography.title3.copyWith(
            color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (holdings.isEmpty)
          const _EmptyHoldingsView()
        else
          ...holdings.map(
            (holding) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HoldingCard(
                holding: holding,
                position: positionsByHoldingId[holding.id],
                onTrade: () => _showTradeForm(holding),
                onEdit: () => _showEditHolding(holding),
                onDelete: () => _showDeleteHolding(holding),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPortfolioSummaryCard(AsyncValue<DashboardData> dashboardAsync) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    // 获取投资组合快照数据
    final snapshot = dashboardAsync.valueOrNull?.portfolioSnapshots[widget.portfolio.id];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '投资组合概览',
            style: QHTypography.title3.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          
          if (snapshot != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    '总市值',
                    _formatCurrency(snapshot.marketValue),
                    labelColor,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    '持仓数',
                    '${snapshot.holdingsCount} 项',
                    labelColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    '总成本',
                    _formatCurrency(snapshot.costBasis),
                    labelColor,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    '累计盈亏',
                    _formatSignedCurrency(snapshot.unrealizedProfit),
                    _resolveChangeColor(snapshot.unrealizedProfit),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    '今日盈亏',
                    _formatSignedCurrency(snapshot.todayProfit),
                    _resolveChangeColor(snapshot.todayProfit),
                  ),
                ),
                if (snapshot.costBasis > 0)
                  Expanded(
                    child: _buildMetricItem(
                      '盈亏率',
                      '${(snapshot.unrealizedProfit / snapshot.costBasis * 100).toStringAsFixed(2)}%',
                      _resolveChangeColor(snapshot.unrealizedProfit),
                    ),
                  ),
              ],
            ),
          ] else ...[
            Text(
              '暂无数据',
              style: QHTypography.body.copyWith(color: secondaryColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(AsyncValue<DashboardData> dashboardAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 图表和分析预览区域
          _buildChartPreviewSection(dashboardAsync),
          const SizedBox(height: 12),
          
          // 持仓分布和风险指标
          _buildDistributionSection(dashboardAsync),
        ],
      ),
    );
  }

  Widget _buildChartPreviewSection(AsyncValue<DashboardData> dashboardAsync) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 持仓饼图
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.chart_pie_fill,
                    size: 20,
                    color: CupertinoColors.activeBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '持仓饼图',
                    style: QHTypography.subheadline.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 使用真实持仓数据的饼图
              Consumer(
                builder: (context, ref, child) {
                  final holdingPositionsAsync = ref.watch(filteredHoldingPositionsProvider(widget.portfolio.id));
                  
                  return holdingPositionsAsync.when(
                    data: (positions) {
                      if (positions.isEmpty) {
                        return Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey6, context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '暂无持仓数据',
                              style: QHTypography.subheadline.copyWith(
                                color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                              ),
                            ),
                          ),
                        );
                      }
                      
                      final totalMarketValue = positions.fold<double>(
                        0, 
                        (sum, position) => sum + position.marketValue,
                      );
                      
                      return Row(
                        children: [
                          // 饼图
                          SimplePieChart(
                            size: 140,
                            data: _buildPieChartData(positions, totalMarketValue, context),
                          ),
                          const SizedBox(width: 16),
                          // 图例
                          Expanded(
                            child: PieChartLegend(
                              data: _buildPieChartData(positions, totalMarketValue, context),
                              showPercentages: true,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CupertinoActivityIndicator()),
                    error: (error, stackTrace) => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey6, context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '加载失败',
                          style: QHTypography.subheadline.copyWith(
                            color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // 净值曲线
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            height: 240,
            child: Consumer(
              builder: (context, ref, child) {
                final dataAsync = ref.watch(
                  portfolioHistoricalNetWorthProvider((
                    portfolioId: widget.portfolio.id,
                    timeRange: '1Y',
                  )),
                );
                final snapshot = dashboardAsync.valueOrNull?.portfolioSnapshots[widget.portfolio.id];
                final baseline = snapshot?.costBasis;
                return dataAsync.when(
                  data: (data) => NetWorthChart(
                    netWorthHistory: data,
                    showTimeSelector: true,
                    baselineValue: baseline != null && baseline > 0 ? baseline : null,
                  ),
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  error: (error, stackTrace) => Center(
                    child: Text(
                      '加载失败',
                      style: QHTypography.footnote.copyWith(
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.secondaryLabel,
                          context,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionSection(AsyncValue<DashboardData> dashboardAsync) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    final snapshot = dashboardAsync.valueOrNull?.portfolioSnapshots[widget.portfolio.id];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.square_grid_3x2,
                size: 20,
                color: CupertinoColors.systemOrange,
              ),
              const SizedBox(width: 8),
              Text(
                '持仓分布',
                style: QHTypography.subheadline.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (snapshot != null) ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    '最大单仓',
                    _getMaxHoldingPercent(snapshot),
                    CupertinoColors.systemRed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    '平均仓位',
                    _getAverageHoldingPercent(snapshot),
                    CupertinoColors.systemBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    '集中度',
                    _getConcentrationLevel(snapshot),
                    CupertinoColors.systemPurple,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              '加载中...',
              style: QHTypography.body.copyWith(color: secondaryColor),
            ),
          ],
        ],
      ),
    );
  }



  Widget _buildMetricCard(String label, String value, Color color) {
    final resolvedColor = CupertinoDynamicColor.resolve(color, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: secondaryColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: QHTypography.footnote.copyWith(
            color: resolvedColor,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 辅助方法计算统计数据
  String _getMaxHoldingPercent(PortfolioSnapshot snapshot) {
    if (snapshot.positions.isEmpty || snapshot.marketValue == 0) return '--';
    
    double maxPercent = 0;
    for (final position in snapshot.positions) {
      final percent = position.marketValue / snapshot.marketValue;
      if (percent > maxPercent) maxPercent = percent;
    }
    return '${(maxPercent * 100).toStringAsFixed(1)}%';
  }

  String _getAverageHoldingPercent(PortfolioSnapshot snapshot) {
    if (snapshot.positions.isEmpty) return '--';
    return '${(100 / snapshot.positions.length).toStringAsFixed(1)}%';
  }

  String _getConcentrationLevel(PortfolioSnapshot snapshot) {
    if (snapshot.positions.isEmpty) return '--';
    
    if (snapshot.positions.length == 1) return '极高';
    if (snapshot.positions.length <= 3) return '高';
    if (snapshot.positions.length <= 8) return '中等';
    return '分散';
  }

  Widget _buildMetricItem(String label, String value, Color valueColor) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondaryColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: QHTypography.subheadline.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showAddHoldingPage() async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => HoldingFormPage(
          portfolioId: widget.portfolio.id,
        ),
      ),
    );
    
    if (result == true) {
      ref.invalidate(portfolioHoldingsProvider(widget.portfolio.id));
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showEditHolding(Holding holding) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => HoldingFormPage(
          portfolioId: widget.portfolio.id,
          holding: holding,
        ),
      ),
    );
    
    if (result == true) {
      ref.invalidate(portfolioHoldingsProvider(widget.portfolio.id));
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showTradeForm(Holding holding) async {
    final result = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (context) => TradeFormPage(holding: holding),
      ),
    );
    
    if (result == true) {
      ref.invalidate(portfolioHoldingsProvider(widget.portfolio.id));
      ref.invalidate(dashboardDataProvider);
    }
  }

  void _showDeleteHolding(Holding holding) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定要删除「${holding.symbol}」吗？\n此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(holdingRepositoryProvider).deleteHolding(holding.id);
                ref.invalidate(portfolioHoldingsProvider(widget.portfolio.id));
                ref.invalidate(dashboardDataProvider);
              } catch (e) {
                if (context.mounted) {
                  showCupertinoDialog<void>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('删除失败'),
                      content: Text(e.toString()),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('好的'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.holding,
    required this.onTrade,
    required this.onEdit,
    required this.onDelete,
    this.position,
  });

  final Holding holding;
  final HoldingPosition? position;
  final VoidCallback onTrade;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    final latestPrice = position?.latestPrice;
    final currentPrice = latestPrice ?? holding.averageCost;
    final costBasis = position?.costBasis ?? holding.quantity * holding.averageCost;
    final marketValue = position?.marketValue ?? holding.quantity * currentPrice;
    final unrealizedProfit = position?.unrealizedProfit ?? (marketValue - costBasis);
    final profitRate = costBasis > 0 ? (unrealizedProfit / costBasis) * 100 : null;
    final profitRateText = profitRate != null ? '${profitRate.toStringAsFixed(2)}%' : '--';
    final priceText = currentPrice > 0 ? '¥${currentPrice.toStringAsFixed(2)}' : '--';
    final titleText = position?.displayName ?? holding.symbol;

    return GestureDetector(
      onTap: () => _showHoldingOptions(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：股票代码和市值
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: QHTypography.subheadline.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (titleText.toUpperCase() != holding.symbol.toUpperCase())
                        Text(
                          holding.symbol.toUpperCase(),
                          style: QHTypography.footnote.copyWith(
                            color: secondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(marketValue),
                      style: QHTypography.subheadline.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _formatSignedCurrency(unrealizedProfit),
                      style: QHTypography.footnote.copyWith(
                        color: _resolveChangeColor(unrealizedProfit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 第二行：持仓信息
            Row(
              children: [
                Expanded(
                  child: _buildHoldingMetric(
                    '持仓',
                    '${holding.quantity.toStringAsFixed(0)} 股',
                    secondaryColor,
                  ),
                ),
                Expanded(
                  child: _buildHoldingMetric(
                    '成本价',
                    '¥${holding.averageCost.toStringAsFixed(2)}',
                    secondaryColor,
                  ),
                ),
                Expanded(
                  child: _buildHoldingMetric(
                    '现价',
                    priceText,
                    secondaryColor,
                  ),
                ),
                Expanded(
                  child: _buildHoldingMetric(
                    '盈亏率',
                    profitRateText,
                    _resolveChangeColor(unrealizedProfit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.footnote.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showHoldingOptions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(holding.symbol),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onTrade();
            },
            child: const Text('买入/卖出'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            child: const Text('编辑持仓'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            isDestructiveAction: true,
            child: const Text('删除持仓'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _EmptyHoldingsView extends StatelessWidget {
  const _EmptyHoldingsView();

  @override
  Widget build(BuildContext context) {
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chart_bar_square,
              size: 64,
              color: secondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无持仓',
              style: QHTypography.title3.copyWith(
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 号添加股票/ETF',
              textAlign: TextAlign.center,
              style: QHTypography.subheadline.copyWith(
                color: secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 64,
              color: CupertinoColors.systemRed,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: QHTypography.title3.copyWith(
                color: CupertinoColors.systemRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QHTypography.subheadline.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 辅助函数
Color _resolveChangeColor(double? value) {
  if (value == null || value == 0) {
    return CupertinoColors.secondaryLabel;
  }
  return value > 0 ? QHColors.profit : QHColors.loss;
}

String _formatCurrency(double value) {
  final isNegative = value < 0;
  final absValue = value.abs();
  final formatted = absValue.toStringAsFixed(2);
  return isNegative ? '-¥$formatted' : '¥$formatted';
}

String _formatSignedCurrency(double? value) {
  if (value == null) {
    return '--';
  }
  final absValue = value.abs().toStringAsFixed(2);
  if (value == 0) {
    return '¥$absValue';
  }
  final sign = value > 0 ? '+' : '-';
  return '$sign¥$absValue';
}

List<PieChartData> _buildPieChartData(
  List<HoldingPosition> positions,
  double totalMarketValue,
  BuildContext context,
) {
  if (positions.isEmpty || totalMarketValue <= 0) {
    return [];
  }

  // 取前8个持仓，其余合并为"其他"
  const maxItems = 8;
  final displayPositions = positions.take(maxItems).toList();
  final remainingPositions = positions.skip(maxItems).toList();

  final data = <PieChartData>[];

  // 添加主要持仓
  for (int i = 0; i < displayPositions.length; i++) {
    final position = displayPositions[i];
    data.add(PieChartData(
      label: position.displayName,
      value: position.marketValue,
      color: _getColorForIndex(i),
    ));
  }

  // 如果有剩余持仓，合并为"其他"
  if (remainingPositions.isNotEmpty) {
    final otherValue = remainingPositions
        .fold<double>(0, (sum, position) => sum + position.marketValue);
    data.add(PieChartData(
      label: '其他 (${remainingPositions.length}项)',
      value: otherValue,
      color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
    ));
  }

  return data;
}

Color _getColorForIndex(int index) {
  const colors = [
    CupertinoColors.systemBlue,
    CupertinoColors.systemGreen,
    CupertinoColors.systemOrange,
    CupertinoColors.systemRed,
    CupertinoColors.systemPurple,
    CupertinoColors.systemTeal,
    CupertinoColors.systemIndigo,
    CupertinoColors.systemPink,
  ];
  return colors[index % colors.length];
}