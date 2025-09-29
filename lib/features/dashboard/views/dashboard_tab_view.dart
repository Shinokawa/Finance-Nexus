import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../data/local/app_database.dart';
import '../../../design/design_system.dart';
import '../../accounts/providers/account_summary_providers.dart';
import '../models/holding_position.dart';
import '../providers/dashboard_providers.dart';
import '../providers/holding_positions_provider.dart';
import 'asset_detail_pages.dart';

enum DashboardSegment { portfolios, accounts }

class DashboardTabView extends ConsumerStatefulWidget {
  const DashboardTabView({super.key});

  @override
  ConsumerState<DashboardTabView> createState() => _DashboardTabViewState();
}

class _DashboardTabViewState extends ConsumerState<DashboardTabView> {
  DashboardSegment _segment = DashboardSegment.portfolios;
  String? _selectedPortfolioId;

  @override
  void initState() {
    super.initState();
    // Ensure initial holdings snapshot is loaded along with dashboard data.
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(ref.read(holdingPositionsProvider.future));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _navigateTo(Widget page) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => page),
    );
  }

  void _handleAssetTap(DashboardAssetRow row) {
    if (_segment == DashboardSegment.portfolios) {
      _navigateTo(PortfolioInsightPage(portfolioId: row.id));
    } else {
      _navigateTo(AccountInsightPage(accountId: row.id));
    }
  }

  void _handleHoldingTap(HoldingPosition position) {
    _navigateTo(HoldingInsightPage(holdingId: position.holding.id));
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(holdingPositionsProvider);
    try {
      await ref.read(holdingPositionsProvider.future);
    } catch (_) {
      // Ignore errors during manual refresh; UI will show appropriate state.
    }
  }

  Future<void> _presentPortfolioPicker(List<Portfolio> portfolios) async {
    const allKey = '__ALL__';
    final result = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择组合'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(allKey),
            isDefaultAction: _selectedPortfolioId == null,
            child: const Text('全部组合'),
          ),
          for (final portfolio in portfolios)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(portfolio.id),
              isDefaultAction: _selectedPortfolioId == portfolio.id,
              child: Text(portfolio.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedPortfolioId = result == allKey ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(dashboardDataProvider);
    final portfoliosAsync = ref.watch(portfoliosStreamProvider);
    final holdingsAsync = ref.watch(filteredHoldingPositionsProvider(_selectedPortfolioId));
    final resolvedBackground =
        CupertinoDynamicColor.resolve(QHColors.background, context);

    return CupertinoPageScaffold(
      backgroundColor: resolvedBackground,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('总览'),
          ),
          CupertinoSliverRefreshControl(onRefresh: _handleRefresh),
          ...dataAsync.when(
            data: (data) => _buildContentSlivers(
              context,
              data,
              portfoliosAsync,
              holdingsAsync,
            ),
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ],
            error: (error, stackTrace) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _DashboardError(message: error.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    DashboardData data,
    AsyncValue<List<Portfolio>> portfoliosAsync,
    AsyncValue<List<HoldingPosition>> holdingsAsync,
  ) {
    final segmentedChildren = <DashboardSegment, Widget>{
      DashboardSegment.portfolios: const Text('按组合'),
      DashboardSegment.accounts: const Text('按账户'),
    };

    final rows =
        _segment == DashboardSegment.portfolios ? data.portfolioRows : data.accountRows;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: QHSpacing.pageHorizontal,
            vertical: QHSpacing.pageVertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TotalNetWorthCard(data: data),
              const SizedBox(height: QHSpacing.cardSpacing),
              CupertinoSlidingSegmentedControl<DashboardSegment>(
                groupValue: _segment,
                children: segmentedChildren,
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _segment = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      if (rows.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(message: '暂无数据，稍后再试。'),
        )
      else ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: QHSpacing.pageHorizontal,
            ),
            child: _AssetCompositionSection(
              rows: rows,
              segment: _segment,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              left: QHSpacing.pageHorizontal,
              right: QHSpacing.pageHorizontal,
              top: QHSpacing.cardSpacing,
              bottom: QHSpacing.pageVertical,
            ),
            child: Column(
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _DashboardAssetCard(
                      row: row,
                      segment: _segment,
                      onTap: () => _handleAssetTap(row),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(
            left: QHSpacing.pageHorizontal,
            right: QHSpacing.pageHorizontal,
            bottom: QHSpacing.pageVertical,
          ),
          child: _HoldingsSection(
            portfoliosAsync: portfoliosAsync,
            holdingsAsync: holdingsAsync,
            onFilterTap: (portfolios) => _presentPortfolioPicker(portfolios),
            selectedPortfolioId: _selectedPortfolioId,
            onHoldingTap: _handleHoldingTap,
          ),
        ),
      ),
    ];
  }
}

class _TotalNetWorthCard extends ConsumerWidget {
  const _TotalNetWorthCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background =
        CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final secondaryLabelColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    
  final totalNetProfit = data.totalNetProfit;
  final totalReturnPercent = data.totalCostBasis == 0
    ? null
    : (totalNetProfit / data.totalCostBasis) * 100;
  final cumulativeColor = _resolveChangeColor(totalNetProfit);
  final realizedColor = _resolveChangeColor(data.totalRealizedProfit);
  final unrealizedColor = _resolveChangeColor(data.totalUnrealizedProfit);
  final tradingCostColor = _resolveChangeColor(-data.totalTradingCost);
    final todayColor = _resolveChangeColor(data.todayChange);
    
    // 计算资产分布
    final investmentValue = data.portfolioSnapshots.values
        .fold<double>(0, (sum, snapshot) => sum + snapshot.marketValue);
    // 现金资产 = 所有账户的现金余额（包括证券账户和现金账户）
    final cashValue = data.accountSnapshots.values
        .fold<double>(0, (sum, snapshot) => sum + snapshot.cashBalance);
    final liabilityValue = data.accountSnapshots.values
        .where((snapshot) => snapshot.account.type == AccountType.liability)
        .fold<double>(0, (sum, snapshot) => sum + snapshot.totalValue);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '总净资产',
                      style: QHTypography.footnote.copyWith(color: secondaryLabelColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(data.totalNetWorth),
                      style: QHTypography.title1.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '今日变化',
                    style: QHTypography.footnote.copyWith(color: secondaryLabelColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatSignedCurrency(data.todayChange),
                    style: QHTypography.subheadline.copyWith(
                      color: todayColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatSignedPercent(data.todayChangePercent),
                    style: QHTypography.footnote.copyWith(
                      color: todayColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _NetWorthMetric(
                label: '投资市值',
                value: _formatCurrency(investmentValue),
                subtitle: '${((investmentValue / data.totalNetWorth) * 100).toStringAsFixed(1)}%',
              ),
              _NetWorthMetric(
                label: '现金资产',
                value: _formatCurrency(cashValue),
                subtitle: '${((cashValue / data.totalNetWorth) * 100).toStringAsFixed(1)}%',
              ),
              _NetWorthMetric(
                label: '负债金额',
                value: _formatCurrency(liabilityValue),
                subtitle: '${((liabilityValue / data.totalNetWorth) * 100).toStringAsFixed(1)}%',
              ),
              _NetWorthMetric(
                label: '投入本金',
                value: _formatCurrency(data.totalCostBasis),
                subtitle: null,
              ),
              _NetWorthMetric(
                label: '总盈亏',
                value: _formatSignedCurrency(totalNetProfit),
                color: cumulativeColor,
                subtitle: totalReturnPercent != null
                    ? _formatSignedPercent(totalReturnPercent)
                    : null,
              ),
              _NetWorthMetric(
                label: '已实现盈亏',
                value: _formatSignedCurrency(data.totalRealizedProfit),
                color: realizedColor,
                subtitle: data.totalCostBasis == 0
                    ? null
                    : _formatSignedPercent((data.totalRealizedProfit / data.totalCostBasis) * 100),
              ),
              _NetWorthMetric(
                label: '未实现盈亏',
                value: _formatSignedCurrency(data.totalUnrealizedProfit),
                color: unrealizedColor,
                subtitle: data.totalCostBasis == 0
                    ? null
                    : _formatSignedPercent((data.totalUnrealizedProfit / data.totalCostBasis) * 100),
              ),
              _NetWorthMetric(
                label: '交易成本',
                value: _formatSignedCurrency(-data.totalTradingCost),
                color: tradingCostColor,
                subtitle: data.totalCostBasis == 0
                    ? null
                    : _formatSignedPercent((-data.totalTradingCost / data.totalCostBasis) * 100),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardAssetCard extends StatelessWidget {
  const _DashboardAssetCard({
    required this.row,
    required this.segment,
    this.onTap,
  });

  final DashboardAssetRow row;
  final DashboardSegment segment;
  final VoidCallback? onTap;

  bool get _isPortfolio => segment == DashboardSegment.portfolios;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final tertiary = CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context);
    final accent = _resolveAccentColor(context);
  final netPercent = row.costBasis == 0 ? null : (row.netProfit / row.costBasis) * 100;
  final netText = _formatChange(row.netProfit, netPercent);
  final cumulativeText = _formatChange(row.unrealizedProfit, row.unrealizedPercent);
    final todayText = _formatChange(row.todayProfit, row.todayProfitPercent);
    final costText = _formatCurrency(row.costBasis);
    final shareText = _formatShare(row.share);
    final cashText = row.cashBalance == null ? null : _formatCurrency(row.cashBalance!);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.title,
                          style: QHTypography.title3.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row.subtitle,
                          style: QHTypography.subheadline.copyWith(
                            color: tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isPortfolio && row.category != null)
                    _AssetBadge(
                      label: row.category!.displayName,
                      color: accent,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _formatCurrency(row.marketValue),
                style: QHTypography.title1.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: row.marketValue < 0 ? QHColors.loss : labelColor,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricPill(
                    label: '总盈亏',
                    value: netText,
                    color: _resolveChangeColor(row.netProfit),
                  ),
                  _MetricPill(
                    label: '未实现盈亏',
                    value: cumulativeText,
                    color: _resolveChangeColor(row.unrealizedProfit),
                  ),
                  _MetricPill(
                    label: '已实现盈亏',
                    value: _formatSignedCurrency(row.realizedProfit),
                    color: _resolveChangeColor(row.realizedProfit),
                  ),
                  _MetricPill(
                    label: '交易成本',
                    value: _formatSignedCurrency(-row.tradingCost),
                    color: _resolveChangeColor(-row.tradingCost),
                  ),
                  _MetricPill(
                    label: '今日盈亏',
                    value: todayText,
                    color: _resolveChangeColor(row.todayProfit),
                  ),
                  _MetricPill(
                    label: _isPortfolio ? '组合成本' : '资产成本',
                    value: costText,
                  ),
                  if (cashText != null && cashText != '--')
                    _MetricPill(
                      label: '账户现金',
                      value: cashText,
                    ),
                  if (row.holdingsCount > 0)
                    _MetricPill(
                      label: '持仓数量',
                      value: '${row.holdingsCount} 项',
                    ),
                  _MetricPill(
                    label: '资产占比',
                    value: shareText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveAccentColor(BuildContext context) {
    final category = row.category;
    if (category == null) {
      return CupertinoDynamicColor.resolve(QHColors.primary, context);
    }
    switch (category) {
      case AccountType.investment:
        return CupertinoDynamicColor.resolve(QHColors.primary, context);
      case AccountType.cash:
        return CupertinoDynamicColor.resolve(CupertinoColors.systemGreen, context);
      case AccountType.liability:
        return CupertinoDynamicColor.resolve(QHColors.loss, context);
    }
  }
}

class _AssetCompositionSection extends StatelessWidget {
  const _AssetCompositionSection({
    required this.rows,
    required this.segment,
  });

  final List<DashboardAssetRow> rows;
  final DashboardSegment segment;

  @override
  Widget build(BuildContext context) {
    final slices = _buildSlices(context);
    final hasData = slices.isNotEmpty;
    final resolvedBackground =
        CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '资产构成',
              style: QHTypography.title3.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              segment == DashboardSegment.portfolios ? '按组合' : '按账户',
              style: QHTypography.subheadline.copyWith(color: secondary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: resolvedBackground,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: hasData
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            painter: _CompositionDonutPainter(slices),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final slice in slices)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: slice.color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            slice.label,
                                            style: QHTypography.subheadline.copyWith(
                                              color: labelColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (slice.subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              slice.subtitle!,
                                              style: QHTypography.footnote.copyWith(
                                                color: secondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatShare(slice.share),
                                      style: QHTypography.subheadline.copyWith(
                                        color: labelColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    height: 140,
                    child: Center(
                      child: Text(
                        '暂无可视化数据',
                        style: QHTypography.subheadline.copyWith(color: secondary),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  List<_CompositionSlice> _buildSlices(BuildContext context) {
    const palette = [
      CupertinoColors.activeBlue,
      CupertinoColors.systemGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPurple,
      CupertinoColors.systemPink,
      CupertinoColors.systemTeal,
      CupertinoColors.systemIndigo,
    ];

    final slices = <_CompositionSlice>[];
    var colorIndex = 0;
    for (final row in rows) {
      final share = row.share.abs();
      if (share <= 0) {
        continue;
      }
      final color = CupertinoDynamicColor.resolve(
        palette[colorIndex % palette.length],
        context,
      );
      colorIndex++;
      slices.add(
        _CompositionSlice(
          label: row.title,
          subtitle: segment == DashboardSegment.portfolios
              ? null
              : row.category?.displayName ?? row.subtitle,
          share: share,
          color: color,
        ),
      );
    }
    return slices;
  }
}

class _CompositionSlice {
  const _CompositionSlice({
    required this.label,
    required this.share,
    required this.color,
    this.subtitle,
  });

  final String label;
  final double share;
  final String? subtitle;
  final Color color;
}

class _CompositionDonutPainter extends CustomPainter {
  _CompositionDonutPainter(this.slices);

  final List<_CompositionSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.share);
    if (total <= 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18
        ..color = CupertinoColors.systemGrey3;
      final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2.4);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);
      return;
    }

    final center = size.center(Offset.zero);
    final radius = size.width / 2.4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final strokeWidth = size.width * 0.18;
    var startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.share / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = slice.color;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = CupertinoColors.systemBackground;
    canvas.drawCircle(center, radius - strokeWidth, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _CompositionDonutPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

class _HoldingsSection extends StatelessWidget {
  const _HoldingsSection({
    required this.portfoliosAsync,
    required this.holdingsAsync,
    required this.onFilterTap,
    required this.selectedPortfolioId,
    this.onHoldingTap,
  });

  final AsyncValue<List<Portfolio>> portfoliosAsync;
  final AsyncValue<List<HoldingPosition>> holdingsAsync;
  final void Function(List<Portfolio> portfolios) onFilterTap;
  final String? selectedPortfolioId;
  final void Function(HoldingPosition position)? onHoldingTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final portfolios = portfoliosAsync.valueOrNull ?? const <Portfolio>[];

    var filterLabel = '全部组合';
    if (selectedPortfolioId != null) {
      for (final portfolio in portfolios) {
        if (portfolio.id == selectedPortfolioId) {
          filterLabel = portfolio.name;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '持仓列表',
              style: QHTypography.title3.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: portfolios.isEmpty ? null : () => onFilterTap(portfolios),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.activeBlue.withValues(alpha: 0.1),
                    context,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CupertinoDynamicColor.resolve(
                      CupertinoColors.activeBlue,
                      context,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filterLabel,
                      style: QHTypography.footnote.copyWith(
                        color: CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 14,
                      color: CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        holdingsAsync.when(
          data: (positions) {
            if (positions.isEmpty) {
              return SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    '暂无持仓数据，先去添加一笔吧。',
                    style: QHTypography.subheadline.copyWith(color: secondary),
                  ),
                ),
              );
            }

            final totalMarketValue =
                positions.fold<double>(0, (sum, position) => sum + position.marketValue);
            final totalCostBasis =
                positions.fold<double>(0, (sum, position) => sum + position.costBasis);
            final totalUnrealized = totalMarketValue - totalCostBasis;
            final totalUnrealizedPercent = totalCostBasis == 0
                ? null
                : (totalUnrealized / totalCostBasis) * 100;
            final totalTodayProfit =
                positions.fold<double>(0, (sum, position) => sum + (position.todayProfit ?? 0));
            final totalTodayPercent = _weightedChangePercentForPositions(positions);

            return Column(
              children: [
                _HoldingsSummary(
                  marketValue: totalMarketValue,
                  costBasis: totalCostBasis,
                  unrealizedProfit: totalUnrealized,
                  unrealizedPercent: totalUnrealizedPercent,
                  todayProfit: totalTodayProfit,
                  todayPercent: totalTodayPercent,
                  holdingsCount: positions.length,
                ),
                const SizedBox(height: 20),
                for (final position in positions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _HoldingCard(
                      position: position,
                      share: totalMarketValue == 0
                          ? 0
                          : position.marketValue / totalMarketValue,
                      onTap: onHoldingTap == null
                          ? null
                          : () => onHoldingTap!(position),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, stackTrace) => _SectionError(message: error.toString()),
        ),
      ],
    );
  }
}

class _HoldingsSummary extends StatelessWidget {
  const _HoldingsSummary({
    required this.marketValue,
    required this.costBasis,
    required this.unrealizedProfit,
    required this.unrealizedPercent,
    required this.todayProfit,
    required this.todayPercent,
    required this.holdingsCount,
  });

  final double marketValue;
  final double costBasis;
  final double unrealizedProfit;
  final double? unrealizedPercent;
  final double todayProfit;
  final double? todayPercent;
  final int holdingsCount;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondaryColor = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    
    final unrealizedColor = _resolveChangeColor(unrealizedProfit);
    final todayColor = _resolveChangeColor(todayProfit);

    String formatCurrency(double value) {
      return '¥${value.toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 市值行
          Row(
            children: [
              Text(
                '当前筛选市值',
                style: QHTypography.footnote.copyWith(color: secondaryColor),
              ),
              const Spacer(),
              Text(
                formatCurrency(marketValue),
                style: QHTypography.title1.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 第一行：成本、未实现盈亏、未实现收益率
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  label: '组合成本',
                  value: formatCurrency(costBasis),
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  label: '未实现盈亏',
                  value: '${unrealizedProfit >= 0 ? '+' : ''}${formatCurrency(unrealizedProfit)}',
                  valueColor: CupertinoDynamicColor.resolve(unrealizedColor, context),
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  label: '未实现收益率',
                  value: unrealizedPercent != null 
                    ? '${unrealizedPercent! >= 0 ? '+' : ''}${unrealizedPercent!.toStringAsFixed(2)}%'
                    : '--',
                  valueColor: CupertinoDynamicColor.resolve(unrealizedColor, context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 第二行：今日盈亏、今日涨跌幅、持仓数量
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  label: '今日盈亏',
                  value: '${todayProfit >= 0 ? '+' : ''}${formatCurrency(todayProfit)}',
                  valueColor: CupertinoDynamicColor.resolve(todayColor, context),
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  label: '今日涨跌幅',
                  value: todayPercent != null 
                    ? '${todayPercent! >= 0 ? '+' : ''}${todayPercent!.toStringAsFixed(2)}%'
                    : '--',
                  valueColor: CupertinoDynamicColor.resolve(todayColor, context),
                ),
              ),
              Expanded(
                child: _CompactMetric(
                  label: '持仓数量',
                  value: '$holdingsCount 项',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final resolvedValueColor =
        CupertinoDynamicColor.resolve(valueColor ?? CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
            color: resolvedValueColor,
          ),
        ),
      ],
    );
  }
}

class _HoldingCard extends StatelessWidget {
  const _HoldingCard({
    required this.position,
    required this.share,
    this.onTap,
  });

  final HoldingPosition position;
  final double share;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoDynamicColor.resolve(QHColors.cardBackground, context);
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final accent = CupertinoDynamicColor.resolve(QHColors.primary, context);

    final marketValue = position.marketValue;
    final shareText = _formatShare(share);
    final quantityText = _formatQuantity(position.quantity);
    final costText = _formatCurrency(position.costBasis);
    final averageCostText = '¥${position.averageCost.toStringAsFixed(2)}';
    final latestPriceText = position.latestPrice != null
        ? '¥${position.latestPrice!.toStringAsFixed(2)}'
        : '--';
    final cumulativeChange = _formatChange(position.unrealizedProfit, position.unrealizedPercent);
    final dailyChange = _formatChange(position.todayProfit, position.todayProfitPercent);
    final profitColor = _resolveChangeColor(position.unrealizedProfit);
    final todayColor = _resolveChangeColor(position.todayProfit);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position.displayName,
                          style: QHTypography.title3.copyWith(
                            color: labelColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${position.symbol.toUpperCase()} · ${position.portfolio.name}',
                          style: QHTypography.footnote.copyWith(
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _AssetBadge(
                    label: position.account.name,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: secondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatCurrency(marketValue),
                style: QHTypography.title1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HoldingMetric(label: '持仓数量', value: quantityText),
                  _HoldingMetric(label: '总成本', value: costText),
                  _HoldingMetric(label: '成本价', value: averageCostText),
                  _HoldingMetric(label: '现价', value: latestPriceText),
                  _HoldingMetric(label: '持仓占比', value: shareText),
                  _HoldingMetric(
                    label: '未实现盈亏',
                    value: cumulativeChange,
                    valueColor: profitColor,
                    emphasize: true,
                  ),
                  _HoldingMetric(
                    label: '今日盈亏',
                    value: dailyChange,
                    valueColor: todayColor,
                  ),
                ],
              ),
              if (position.hasQuoteError) ...[
                const SizedBox(height: 12),
                Text(
                  position.quoteError ?? '行情获取失败',
                  style: QHTypography.footnote.copyWith(color: CupertinoColors.systemRed),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldingMetric extends StatelessWidget {
  const _HoldingMetric({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final resolvedValueColor =
        CupertinoDynamicColor.resolve(valueColor ?? CupertinoColors.label, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(color: secondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: (emphasize ? QHTypography.subheadline : QHTypography.subheadline).copyWith(
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: resolvedValueColor,
          ),
        ),
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: QHTypography.subheadline.copyWith(color: secondary),
        ),
      ),
    );
  }
}

class _AssetBadge extends StatelessWidget {
  const _AssetBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: QHTypography.footnote.copyWith(
            fontWeight: FontWeight.w600,
            color: resolved,
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final baseColor =
        CupertinoDynamicColor.resolve(CupertinoColors.systemGrey5, context);
    final labelColor =
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final valueColor = CupertinoDynamicColor.resolve(color ?? CupertinoColors.label, context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: QHTypography.footnote.copyWith(color: labelColor),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: QHTypography.subheadline.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.exclamationmark_circle, size: 48),
            const SizedBox(height: 12),
            Text(
              '加载失败',
              style: QHTypography.title3,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: QHTypography.footnote.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.square_stack_3d_up_slash_fill, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: QHTypography.subheadline.copyWith(
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

Color _resolveChangeColor(double? value) {
  if (value == null) {
    return CupertinoColors.secondaryLabel;
  }
  if (value > 0) {
    return QHColors.profit;
  }
  if (value < 0) {
    return QHColors.loss;
  }
  return CupertinoColors.secondaryLabel;
}

String _formatShare(double share) {
  if (share == 0) {
    return '--';
  }
  final percent = (share.abs() * 100).toStringAsFixed(1);
  return share < 0 ? '-$percent%' : '$percent%';
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

String _formatSignedPercent(double? percent) {
  if (percent == null) {
    return '--';
  }
  final absPercent = percent.abs().toStringAsFixed(2);
  if (percent == 0) {
    return '$absPercent%';
  }
  final sign = percent > 0 ? '+' : '-';
  return '$sign$absPercent%';
}

String _formatChange(double? amount, double? percent) {
  final amountText = _formatSignedCurrency(amount);
  final percentText = _formatSignedPercent(percent);
  final hasAmount = amountText != '--';
  final hasPercent = percentText != '--';
  if (!hasAmount && !hasPercent) {
    return '--';
  }
  if (!hasAmount) {
    return percentText;
  }
  if (!hasPercent) {
    return amountText;
  }
  return '$amountText · $percentText';
}

String _formatQuantity(double value) {
  final fractional = value - value.truncateToDouble();
  if (fractional.abs() < 1e-4) {
    return value.toStringAsFixed(0);
  }
  if ((value * 10 - (value * 10).truncateToDouble()).abs() < 1e-4) {
    return value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}

double? _weightedChangePercentForPositions(List<HoldingPosition> positions) {
  double weightedSum = 0;
  double totalWeight = 0;
  for (final position in positions) {
    final percent = position.changePercent;
    if (percent == null) {
      continue;
    }
    final weight = position.marketValue;
    weightedSum += percent * weight;
    totalWeight += weight;
  }
  if (totalWeight == 0) {
    return null;
  }
  return weightedSum / totalWeight;
}

class _NetWorthMetric extends StatelessWidget {
  const _NetWorthMetric({
    required this.label,
    required this.value,
    this.subtitle,
    this.color,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final secondary = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);
    final tertiary = CupertinoDynamicColor.resolve(CupertinoColors.tertiaryLabel, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: QHTypography.footnote.copyWith(
            color: secondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: QHTypography.subheadline.copyWith(
            fontWeight: FontWeight.w600,
            color: color ?? labelColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle!,
            style: QHTypography.footnote.copyWith(
              color: tertiary.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}
